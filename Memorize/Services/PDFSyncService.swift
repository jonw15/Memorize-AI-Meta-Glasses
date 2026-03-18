/*
 * PDF Sync Service
 * Handles cloud PDF sync — generates pairing codes, polls for pending uploads,
 * downloads PDFs, and acknowledges downloads.
 */

import Foundation

class PDFSyncService {
    static let shared = PDFSyncService()

    private let syncCodeKey = "memorize_sync_code"
    private let baseURL = AIConfig.apiApp

    struct PendingPDF: Identifiable {
        let id: String // fileId
        let filename: String
        let uploadedAt: String
        let downloadUrl: String
    }

    // MARK: - Sync Code

    /// Returns the current sync code, generating one if needed
    func getOrCreateSyncCode() -> String {
        if let existing = UserDefaults.standard.string(forKey: syncCodeKey), existing.count == 6 {
            return existing
        }
        let code = generateCode()
        UserDefaults.standard.set(code, forKey: syncCodeKey)
        return code
    }

    /// Regenerates a new sync code
    func regenerateSyncCode() -> String {
        let code = generateCode()
        UserDefaults.standard.set(code, forKey: syncCodeKey)
        return code
    }

    private func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // No I/O/0/1 to avoid confusion
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // MARK: - Register Code

    /// Registers the sync code with the server
    func registerCode(_ code: String) async throws {
        let url = URL(string: "\(baseURL)sync/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["code": code])
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SyncError.registrationFailed
        }
        print("☁️ [Sync] Code registered: \(code)")
    }

    // MARK: - Check for Pending PDFs

    /// Polls the server for pending PDF uploads
    func checkPending(code: String) async throws -> [PendingPDF] {
        let url = URL(string: "\(baseURL)sync/pending?code=\(code)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SyncError.pollFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [[String: Any]] else {
            return []
        }

        return files.compactMap { file in
            guard let fileId = file["fileId"] as? String,
                  let downloadUrl = file["downloadUrl"] as? String else { return nil }
            return PendingPDF(
                id: fileId,
                filename: file["filename"] as? String ?? "document.pdf",
                uploadedAt: file["uploadedAt"] as? String ?? "",
                downloadUrl: downloadUrl
            )
        }
    }

    // MARK: - Download PDF

    /// Downloads a PDF to a temporary file and returns the local URL
    func downloadPDF(from urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw SyncError.invalidURL
        }

        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SyncError.downloadFailed
        }

        // Move to a more permanent temp location with .pdf extension
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }

    // MARK: - Acknowledge Download

    /// Marks a PDF as downloaded so it won't appear in future polls
    func acknowledge(code: String, fileId: String) async throws {
        let url = URL(string: "\(baseURL)sync/ack")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["code": code, "fileId": fileId])
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SyncError.ackFailed
        }
        print("☁️ [Sync] Acknowledged: \(fileId)")
    }
}

// MARK: - Errors

enum SyncError: LocalizedError {
    case registrationFailed
    case pollFailed
    case invalidURL
    case downloadFailed
    case ackFailed

    var errorDescription: String? {
        switch self {
        case .registrationFailed: return "Failed to register sync code"
        case .pollFailed: return "Failed to check for pending PDFs"
        case .invalidURL: return "Invalid download URL"
        case .downloadFailed: return "Failed to download PDF"
        case .ackFailed: return "Failed to acknowledge download"
        }
    }
}
