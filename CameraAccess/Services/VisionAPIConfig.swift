/*
 * Vision API Configuration
 * Centralized configuration for Vision API
 * Supports multiple providers: Google AI Studio, OpenRouter
 */

import Foundation

struct VisionAPIConfig {
    // MARK: - Dynamic Configuration (based on current provider)

    /// Current API Key based on selected provider
    static var apiKey: String {
        return APIProviderManager.staticAPIKey
    }

    /// Current Base URL based on selected provider
    static var baseURL: String {
        return APIProviderManager.staticBaseURL
    }

    /// Current Model based on selected provider
    static var model: String {
        return APIProviderManager.staticCurrentModel
    }

    /// Current Provider
    static var provider: APIProvider {
        return APIProviderManager.staticCurrentProvider
    }

    // MARK: - Provider-specific URLs

    /// Google AI Studio API URL (OpenAI-compatible)
    static let googleAIStudioURL = "https://generativelanguage.googleapis.com/v1beta/openai"

    /// OpenRouter API URL
    static let openRouterURL = "https://openrouter.ai/api/v1"

    // MARK: - Default Models

    static let defaultGoogleModel = "gemini-3.0-flash"
    static let defaultOpenRouterModel = "google/gemini-3-flash-preview"

    // MARK: - Request Headers

    /// Get headers for the current provider
    static func headers(with apiKey: String) -> [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]

        // Add OpenRouter-specific headers
        if provider == .openrouter {
            headers["HTTP-Referer"] = "https://ariaspark.com"
            headers["X-Title"] = "Aria"
        }

        return headers
    }
}
