/*
 * AI Config Service
 * Fetches encrypted AI configuration from server and decrypts it
 * Protocol: POST {API_APP}/config/get → AES-256-CBC decrypt → { key, url, model }
 */

import Foundation
import CommonCrypto

struct AIConfigResult {
    let key: String
    let url: String
    let model: String
}

enum AIConfigError: Error, LocalizedError {
    case invalidURL
    case networkError(String)
    case invalidResponse
    case decryptionFailed
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid config server URL"
        case .networkError(let msg): return "Network error: \(msg)"
        case .invalidResponse: return "Invalid server response"
        case .decryptionFailed: return "Failed to decrypt config"
        case .parseError: return "Failed to parse decrypted config"
        }
    }
}

class AIConfigService {

    /// Fetches and decrypts AI config from the server, then stores it in APIProviderManager
    @discardableResult
    static func fetchConfig() async throws -> AIConfigResult {
        let urlString = "\(AIConfig.apiApp)/config/get"
        guard let url = URL(string: urlString) else {
            throw AIConfigError.invalidURL
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: String] = ["id": AIConfig.configIdAILive]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Fetch
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIConfigError.networkError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        // Parse response JSON to get "content" field
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? String else {
            throw AIConfigError.invalidResponse
        }

        // Split content: first 44 chars = AES key (Base64), rest = encrypted data (Base64)
        guard content.count > 44 else {
            throw AIConfigError.invalidResponse
        }
        let keyBase64 = String(content.prefix(44))
        let encryptedBase64 = String(content.dropFirst(44))

        // Decrypt
        guard let decrypted = decrypt(
            encryptedBase64: encryptedBase64,
            keyBase64: keyBase64,
            ivBase64: AIConfig.configIV
        ) else {
            throw AIConfigError.decryptionFailed
        }

        // Parse decrypted JSON
        guard let decryptedData = decrypted.data(using: .utf8),
              let configJson = try JSONSerialization.jsonObject(with: decryptedData) as? [String: Any],
              let key = configJson["key"] as? String,
              let configUrl = configJson["url"] as? String,
              let model = configJson["model"] as? String else {
            throw AIConfigError.parseError
        }

        let result = AIConfigResult(key: key, url: configUrl, model: model)

        // Store in APIProviderManager
        await APIProviderManager.shared.applyFetchedConfig(key: key, url: configUrl, model: model)

        print("✅ [AIConfig] Successfully fetched and applied config")
        return result
    }

    // MARK: - AES-256-CBC Decryption

    private static func decrypt(encryptedBase64: String, keyBase64: String, ivBase64: String) -> String? {
        guard let keyData = Data(base64Encoded: keyBase64),
              let ivData = Data(base64Encoded: ivBase64),
              let encryptedData = Data(base64Encoded: encryptedBase64) else {
            print("⚠️ [AIConfig] Failed to decode Base64 inputs")
            return nil
        }

        guard keyData.count == kCCKeySizeAES256 else {
            print("⚠️ [AIConfig] Invalid key size: \(keyData.count), expected \(kCCKeySizeAES256)")
            return nil
        }

        guard ivData.count == kCCBlockSizeAES128 else {
            print("⚠️ [AIConfig] Invalid IV size: \(ivData.count), expected \(kCCBlockSizeAES128)")
            return nil
        }

        let bufferSize = encryptedData.count + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesDecrypted: size_t = 0

        let status = keyData.withUnsafeBytes { keyBytes in
            ivData.withUnsafeBytes { ivBytes in
                encryptedData.withUnsafeBytes { encBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, kCCKeySizeAES256,
                        ivBytes.baseAddress,
                        encBytes.baseAddress, encryptedData.count,
                        &buffer, bufferSize,
                        &numBytesDecrypted
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            print("⚠️ [AIConfig] Decryption failed with status: \(status)")
            return nil
        }

        return String(data: Data(buffer.prefix(numBytesDecrypted)), encoding: .utf8)
    }
}
