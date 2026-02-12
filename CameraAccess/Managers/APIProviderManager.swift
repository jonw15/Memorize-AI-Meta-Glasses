/*
 * API Provider Manager
 * Manages different API providers (Google AI Studio / OpenRouter)
 */

import Foundation
import SwiftUI

// MARK: - API Provider Enum (Vision API)

enum APIProvider: String, CaseIterable, Codable {
    case google = "google"
    case openrouter = "openrouter"

    var displayName: String {
        switch self {
        case .google: return "Google AI Studio"
        case .openrouter: return "OpenRouter"
        }
    }

    var baseURL: String {
        switch self {
        case .google: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .openrouter: return "https://openrouter.ai/api/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .google: return "gemini-2.5-flash"
        case .openrouter: return "google/gemini-3-flash-preview"
        }
    }

    var apiKeyHelpURL: String {
        switch self {
        case .google: return "https://aistudio.google.com/apikey"
        case .openrouter: return "https://openrouter.ai/keys"
        }
    }

    var supportsVision: Bool {
        return true
    }
}

// MARK: - OpenRouter Model

struct OpenRouterModel: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let contextLength: Int?
    let pricing: Pricing?
    let architecture: Architecture?

    var displayName: String {
        return name.isEmpty ? id : name
    }

    var isVisionCapable: Bool {
        // Check if model supports vision based on architecture or ID
        if let arch = architecture {
            return arch.modality?.contains("image") == true ||
                   arch.modality?.contains("multimodal") == true
        }
        // Fallback: check common vision model patterns
        let visionPatterns = ["vision", "vl", "gpt-4o", "claude-3", "gemini"]
        return visionPatterns.contains { id.lowercased().contains($0) }
    }

    var priceDisplay: String {
        guard let pricing = pricing else { return "" }
        let promptPrice = (Double(pricing.prompt) ?? 0) * 1_000_000
        let completionPrice = (Double(pricing.completion) ?? 0) * 1_000_000
        return String(format: "$%.2f / $%.2f per 1M tokens", promptPrice, completionPrice)
    }

    struct Pricing: Codable, Hashable {
        let prompt: String
        let completion: String
    }

    struct Architecture: Codable, Hashable {
        let modality: String?
        let tokenizer: String?
        let instructType: String?

        enum CodingKeys: String, CodingKey {
            case modality
            case tokenizer
            case instructType = "instruct_type"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case contextLength = "context_length"
        case pricing
        case architecture
    }
}

struct OpenRouterModelsResponse: Codable {
    let data: [OpenRouterModel]
}

// MARK: - API Provider Manager

@MainActor
class APIProviderManager: ObservableObject {
    static let shared = APIProviderManager()

    // Vision API Provider
    private let providerKey = "api_provider"
    private let selectedModelKey = "selected_vision_model"

    @Published var currentProvider: APIProvider {
        didSet {
            UserDefaults.standard.set(currentProvider.rawValue, forKey: providerKey)
            // Reset to default model when provider changes
            if oldValue != currentProvider {
                selectedModel = currentProvider.defaultModel
            }
        }
    }

    @Published var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: selectedModelKey)
        }
    }

    @Published var openRouterModels: [OpenRouterModel] = []
    @Published var isLoadingModels = false
    @Published var modelsError: String?

    private init() {
        // Vision API Provider
        let savedProvider = UserDefaults.standard.string(forKey: providerKey) ?? "google"
        // Migrate old "alibaba" provider to "google"
        let provider: APIProvider
        if savedProvider == "alibaba" {
            provider = .google
            UserDefaults.standard.set("google", forKey: providerKey)
        } else {
            provider = APIProvider(rawValue: savedProvider) ?? .google
        }
        self.currentProvider = provider

        let savedModel = UserDefaults.standard.string(forKey: selectedModelKey)
        self.selectedModel = savedModel ?? provider.defaultModel
    }

    // MARK: - AI Configuration (fetched from server)

    private static let defaultLiveAIWebSocketURL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
    private static let defaultLiveAIModel = "gemini-2.5-flash-native-audio-preview-12-2025"

    // Fetched config from server (set by AIConfigService)
    private(set) var fetchedAPIKey: String?
    private(set) var liveAIFetchedURL: String?
    private(set) var liveAIFetchedModel: String?

    static var liveAIWebSocketURL: String {
        return shared.liveAIFetchedURL ?? defaultLiveAIWebSocketURL
    }

    static var liveAIDefaultModel: String {
        return shared.liveAIFetchedModel ?? defaultLiveAIModel
    }

    var liveAIAPIKey: String {
        return fetchedAPIKey ?? APIKeyManager.shared.getGoogleAPIKey() ?? ""
    }

    var hasLiveAIAPIKey: Bool {
        return !liveAIAPIKey.isEmpty
    }

    func applyFetchedConfig(key: String, url: String, model: String) {
        fetchedAPIKey = key
        liveAIFetchedURL = url
        liveAIFetchedModel = model
        updateStaticCache()
    }

    // MARK: - Get Current Configuration

    var currentBaseURL: String {
        return currentProvider.baseURL
    }

    var currentAPIKey: String {
        // Use fetched key first, fall back to Keychain
        return fetchedAPIKey ?? APIKeyManager.shared.getAPIKey(for: currentProvider) ?? ""
    }

    var currentModel: String {
        return selectedModel
    }

    var hasAPIKey: Bool {
        return APIKeyManager.shared.hasAPIKey(for: currentProvider)
    }

    // MARK: - OpenRouter Models

    func fetchOpenRouterModels() async {
        guard currentProvider == .openrouter else { return }
        guard let apiKey = APIKeyManager.shared.getAPIKey(for: .openrouter), !apiKey.isEmpty else {
            modelsError = "Please configure OpenRouter API Key first"
            return
        }

        isLoadingModels = true
        modelsError = nil

        do {
            let url = URL(string: "https://openrouter.ai/api/v1/models")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("Aria", forHTTPHeaderField: "X-Title")
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "OpenRouter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch model list"])
            }

            let decoder = JSONDecoder()
            let modelsResponse = try decoder.decode(OpenRouterModelsResponse.self, from: data)

            // Sort models: vision-capable first, then by name
            openRouterModels = modelsResponse.data.sorted { m1, m2 in
                if m1.isVisionCapable != m2.isVisionCapable {
                    return m1.isVisionCapable
                }
                return m1.displayName < m2.displayName
            }

            print("✅ Loaded \(openRouterModels.count) OpenRouter models")

        } catch {
            modelsError = error.localizedDescription
            print("❌ Failed to fetch OpenRouter models: \(error)")
        }

        isLoadingModels = false
    }

    func searchModels(_ query: String) -> [OpenRouterModel] {
        guard !query.isEmpty else { return openRouterModels }
        let lowercaseQuery = query.lowercased()
        return openRouterModels.filter { model in
            model.id.lowercased().contains(lowercaseQuery) ||
            model.displayName.lowercased().contains(lowercaseQuery) ||
            (model.description?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }

    func visionCapableModels() -> [OpenRouterModel] {
        return openRouterModels.filter { $0.isVisionCapable }
    }
}

// MARK: - Static Helpers for Non-MainActor Access

extension APIProviderManager {
    nonisolated static var staticCurrentProvider: APIProvider {
        let savedProvider = UserDefaults.standard.string(forKey: "api_provider") ?? "google"
        if savedProvider == "alibaba" { return .google }
        return APIProvider(rawValue: savedProvider) ?? .google
    }

    nonisolated static var staticCurrentModel: String {
        let savedModel = UserDefaults.standard.string(forKey: "selected_vision_model")
        return savedModel ?? staticCurrentProvider.defaultModel
    }

    nonisolated static var staticBaseURL: String {
        return staticCurrentProvider.baseURL
    }

    nonisolated static var staticAPIKey: String {
        // Use fetched key first, fall back to Keychain
        return _fetchedAPIKeyCache ?? APIKeyManager.shared.getAPIKey(for: staticCurrentProvider) ?? ""
    }

    nonisolated static var staticLiveAIAPIKey: String {
        return _fetchedAPIKeyCache ?? APIKeyManager.shared.getGoogleAPIKey() ?? ""
    }

    nonisolated static var staticLiveAIWebsocketURL: String {
        return _liveAIFetchedURLCache ?? defaultLiveAIWebSocketURL
    }

    nonisolated static var staticLiveAIDefaultModel: String {
        return _liveAIFetchedModelCache ?? defaultLiveAIModel
    }

    // Thread-safe cache for nonisolated static access
    private nonisolated(unsafe) static var _fetchedAPIKeyCache: String?
    private nonisolated(unsafe) static var _liveAIFetchedURLCache: String?
    private nonisolated(unsafe) static var _liveAIFetchedModelCache: String?

    func updateStaticCache() {
        APIProviderManager._fetchedAPIKeyCache = fetchedAPIKey
        APIProviderManager._liveAIFetchedURLCache = liveAIFetchedURL
        APIProviderManager._liveAIFetchedModelCache = liveAIFetchedModel
    }
}
