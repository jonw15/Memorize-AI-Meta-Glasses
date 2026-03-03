/*
 * Vision API Service
 * Provides image recognition using configurable providers
 * Supports Google AI Studio and OpenRouter
 */

import Foundation
import UIKit

struct VisionAPIService {
    // API Configuration
    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let provider: APIProvider

    /// Initialize with explicit configuration
    init(apiKey: String, baseURL: String? = nil, model: String? = nil) {
        self.apiKey = apiKey
        self.provider = VisionAPIConfig.provider
        self.baseURL = baseURL ?? VisionAPIConfig.baseURL
        self.model = model ?? VisionAPIConfig.model
    }

    /// Initialize with current provider configuration
    init() {
        self.init(
            apiKey: VisionAPIConfig.apiKey,
            baseURL: VisionAPIConfig.baseURL,
            model: VisionAPIConfig.model
        )
    }

    // MARK: - API Request/Response Models

    struct ChatCompletionRequest: Codable {
        let model: String
        let messages: [Message]

        struct Message: Codable {
            let role: String
            let content: [Content]

            struct Content: Codable {
                let type: String
                let text: String?
                let imageUrl: ImageURL?

                enum CodingKeys: String, CodingKey {
                    case type
                    case text
                    case imageUrl = "image_url"
                }

                struct ImageURL: Codable {
                    let url: String
                }
            }
        }
    }

    struct ChatCompletionResponse: Codable {
        let choices: [Choice]?
        let error: APIError?

        struct Choice: Codable {
            let message: Message?
            let delta: Delta?

            struct Message: Codable {
                let content: String?
            }

            struct Delta: Codable {
                let content: String?
            }
        }

        struct APIError: Codable {
            let message: String?
            let code: Int?
        }
    }

    // MARK: - Public Methods

    /// Analyze image and get description
    func analyzeImage(_ image: UIImage, prompt: String = "What is depicted in this image?") async throws -> String {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw VisionAPIError.invalidImage
        }

        let base64String = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64String)"

        // Create request
        let request = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(
                    role: "user",
                    content: [
                        ChatCompletionRequest.Message.Content(
                            type: "image_url",
                            text: nil,
                            imageUrl: ChatCompletionRequest.Message.Content.ImageURL(url: dataURL)
                        ),
                        ChatCompletionRequest.Message.Content(
                            type: "text",
                            text: prompt,
                            imageUrl: nil
                        )
                    ]
                )
            ]
        )

        // Make API call
        return try await makeRequest(request)
    }

    // MARK: - Private Methods

    private func makeRequest(_ request: ChatCompletionRequest) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        // Set headers based on provider
        let headers = VisionAPIConfig.headers(with: apiKey)
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VisionAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VisionAPIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Try robust JSON extraction first (provider responses may vary)
        if let content = extractContentText(from: data), !content.isEmpty {
            return content
        }

        // Fallback to strict decoding for legacy response shape
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ChatCompletionResponse.self, from: data)

        if let apiError = decoded.error?.message {
            throw VisionAPIError.apiError(statusCode: decoded.error?.code ?? -1, message: apiError)
        }

        guard let firstChoice = decoded.choices?.first else {
            throw VisionAPIError.emptyResponse
        }

        let content = firstChoice.message?.content ?? firstChoice.delta?.content ?? ""
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VisionAPIError.emptyResponse
        }
        return content
    }

    private func extractContentText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first else {
            return nil
        }

        if let message = firstChoice["message"] as? [String: Any] {
            if let content = message["content"] as? String {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }

            if let contentParts = message["content"] as? [[String: Any]] {
                let texts = contentParts.compactMap { part -> String? in
                    if let text = part["text"] as? String {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : trimmed
                    }
                    if let text = part["content"] as? String {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : trimmed
                    }
                    return nil
                }
                if !texts.isEmpty { return texts.joined(separator: "\n") }
            }
        }

        if let delta = firstChoice["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }

        return nil
    }
}

// MARK: - Error Types

enum VisionAPIError: LocalizedError {
    case invalidImage
    case emptyResponse
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Cannot process image"
        case .emptyResponse:
            return "API returned empty response"
        case .invalidResponse:
            return "Invalid response format"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}
