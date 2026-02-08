/*
 * Quick Vision Service
 * Quick image recognition service - supports multiple providers (Alibaba Cloud/OpenRouter)
 * Returns concise descriptions, suitable for TTS playback
 */

import Foundation
import UIKit

class QuickVisionService {
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
    convenience init() {
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

    // MARK: - Quick Vision Analysis

    /// Quick image recognition - returns concise voice description
    /// - Parameters:
    ///   - image: The image to recognize
    ///   - customPrompt: Custom prompt (optional, if nil uses current mode's prompt)
    /// - Returns: Concise description text, suitable for TTS playback
    func analyzeImage(_ image: UIImage, customPrompt: String? = nil) async throws -> String {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw QuickVisionError.invalidImage
        }

        let base64String = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64String)"

        // Use custom prompt, mode manager's prompt, or default prompt
        let prompt = customPrompt ?? QuickVisionModeManager.staticPrompt

        // Create API request
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

        urlRequest.timeoutInterval = 60 // 60 second timeout (OpenRouter may need more time)

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        print("📡 [QuickVision] Sending request to \(model) via \(provider.displayName)...")
        print("📡 [QuickVision] URL: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuickVisionError.invalidResponse
        }

        // Log raw response for debugging
        let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode"
        print("📡 [QuickVision] HTTP Status: \(httpResponse.statusCode)")
        print("📡 [QuickVision] Raw response: \(rawResponse.prefix(500))")

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [QuickVision] API error: \(httpResponse.statusCode) - \(errorMessage)")
            throw QuickVisionError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        let apiResponse: ChatCompletionResponse

        do {
            apiResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
        } catch {
            print("❌ [QuickVision] JSON decode error: \(error)")
            throw QuickVisionError.invalidResponse
        }

        // Check for API error in response body
        if let apiError = apiResponse.error {
            let errorMsg = apiError.message ?? "Unknown API error"
            print("❌ [QuickVision] API returned error: \(errorMsg)")
            throw QuickVisionError.apiError(statusCode: apiError.code ?? -1, message: errorMsg)
        }

        // Get content from choices
        guard let choices = apiResponse.choices, let firstChoice = choices.first else {
            print("❌ [QuickVision] No choices in response")
            throw QuickVisionError.emptyResponse
        }

        // Try message.content first, then delta.content
        let content = firstChoice.message?.content ?? firstChoice.delta?.content

        guard let result = content, !result.isEmpty else {
            print("❌ [QuickVision] Empty content in response")
            throw QuickVisionError.emptyResponse
        }

        let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        print("✅ [QuickVision] Result: \(trimmedResult)")

        return trimmedResult
    }
}

// MARK: - Error Types

enum QuickVisionError: LocalizedError {
    case noDevice
    case streamNotReady
    case frameTimeout
    case invalidImage
    case emptyResponse
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noDevice:
            return "Glasses not connected, please pair glasses in Meta View first"
        case .streamNotReady:
            return "Failed to start video stream, please check glasses connection"
        case .frameTimeout:
            return "Video frame timeout, please retry"
        case .invalidImage:
            return "Cannot process image"
        case .emptyResponse:
            return "AI returned empty response, please retry"
        case .invalidResponse:
            return "Invalid response format"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}
