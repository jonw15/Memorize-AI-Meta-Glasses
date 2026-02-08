/*
 * LeanEat Service
 * Food nutrition analysis AI service
 */

import Foundation
import UIKit

class LeanEatService {
    private let apiKey: String
    private let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    private let model = "qwen3-vl-plus"

    init(apiKey: String) {
        self.apiKey = apiKey
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
        let choices: [Choice]

        struct Choice: Codable {
            let message: Message

            struct Message: Codable {
                let content: String
            }
        }
    }

    // MARK: - Nutrition Analysis

    func analyzeFood(_ image: UIImage) async throws -> FoodNutritionResponse {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw LeanEatError.invalidImage
        }

        let base64String = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64String)"

        // Create specialized nutrition analysis prompt
        let nutritionPrompt = """
You are a professional nutritionist AI. Please analyze the food in the image and return nutrition information in pure JSON format.

**Strict requirement: Must return pure JSON format, no extra text!**
**Important: All text content (including the name field) must be in English!**

JSON format:
{
  "foods": [
    {
      "name": "Food name (English)",
      "portion": "Portion size (e.g., 1 bowl, 100g, etc.)",
      "calories": Calorie count (integer, unit: kcal),
      "protein": Protein (float, unit: grams),
      "fat": Fat (float, unit: grams),
      "carbs": Carbohydrates (float, unit: grams),
      "fiber": Dietary fiber (float, unit: grams, optional),
      "sugar": Sugar (float, unit: grams, optional),
      "health_rating": "Health rating (Excellent/Good/Fair/Poor)"
    }
  ],
  "total_calories": Total calories (integer),
  "total_protein": Total protein (float),
  "total_fat": Total fat (float),
  "total_carbs": Total carbohydrates (float),
  "health_score": Health score (0-100 integer),
  "suggestions": [
    "Nutrition suggestion 1",
    "Nutrition suggestion 2",
    "Nutrition suggestion 3"
  ]
}

Please strictly follow the JSON format above, do not add any other text.
"""

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
                            text: nutritionPrompt,
                            imageUrl: nil
                        )
                    ]
                )
            ]
        )

        // Make API call
        let responseText = try await makeRequest(request)

        // Parse JSON response
        return try parseNutritionResponse(responseText)
    }

    // MARK: - Private Methods

    private func makeRequest(_ request: ChatCompletionRequest) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeanEatError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LeanEatError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ChatCompletionResponse.self, from: data)

        guard let firstChoice = apiResponse.choices.first else {
            throw LeanEatError.emptyResponse
        }

        return firstChoice.message.content
    }

    private func parseNutritionResponse(_ text: String) throws -> FoodNutritionResponse {
        // Extract JSON from response (in case AI added extra text)
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to find JSON object in the response
        if let jsonStart = jsonText.range(of: "{"),
           let jsonEnd = jsonText.range(of: "}", options: .backwards) {
            jsonText = String(jsonText[jsonStart.lowerBound...jsonEnd.upperBound])
        }

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LeanEatError.invalidJSON
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(FoodNutritionResponse.self, from: jsonData)
        } catch {
            print("❌ [LeanEat] JSON parsing failed: \(error)")
            print("📝 [LeanEat] Raw response: \(text)")
            throw LeanEatError.invalidJSON
        }
    }
}

// MARK: - Error Types

enum LeanEatError: LocalizedError {
    case invalidImage
    case emptyResponse
    case invalidResponse
    case invalidJSON
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Cannot process image"
        case .emptyResponse:
            return "API returned empty response"
        case .invalidResponse:
            return "Invalid response format"
        case .invalidJSON:
            return "Cannot parse nutrition data, please retry"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}
