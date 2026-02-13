/*
 * API Key Manager
 * Centralized API key storage and retrieval.
 */

import Foundation

final class APIKeyManager {
    static let shared = APIKeyManager()

    private let defaults = UserDefaults.standard
    private let googleKey = "api_key_google"
    private let openRouterKey = "api_key_openrouter"
    private let legacyGoogleKey = "api_key"

    private init() {}

    // MARK: - Provider-based API Keys

    func saveAPIKey(_ apiKey: String, for provider: APIProvider) -> Bool {
        let key = storageKey(for: provider)
        defaults.set(apiKey, forKey: key)
        return true
    }

    func getAPIKey(for provider: APIProvider) -> String? {
        let key = storageKey(for: provider)
        guard let value = defaults.string(forKey: key), !value.isEmpty else {
            // Backward compatibility: historical single-key storage maps to Google
            if provider == .google {
                return defaults.string(forKey: legacyGoogleKey)
            }
            return nil
        }
        return value
    }

    func hasAPIKey(for provider: APIProvider) -> Bool {
        guard let key = getAPIKey(for: provider) else { return false }
        return !key.isEmpty
    }

    func deleteAPIKey(for provider: APIProvider) -> Bool {
        let key = storageKey(for: provider)
        defaults.removeObject(forKey: key)
        if provider == .google {
            defaults.removeObject(forKey: legacyGoogleKey)
        }
        return true
    }

    // MARK: - Convenience (Current Provider)

    func getAPIKey() -> String? {
        if let key = getAPIKey(for: APIProviderManager.staticCurrentProvider), !key.isEmpty {
            return key
        }
        return getGoogleAPIKey()
    }

    // MARK: - Google-specific API Key

    func saveGoogleAPIKey(_ apiKey: String) -> Bool {
        defaults.set(apiKey, forKey: googleKey)
        // Maintain legacy key for compatibility with older code paths
        defaults.set(apiKey, forKey: legacyGoogleKey)
        return true
    }

    func getGoogleAPIKey() -> String? {
        if let value = defaults.string(forKey: googleKey), !value.isEmpty {
            return value
        }
        return defaults.string(forKey: legacyGoogleKey)
    }

    func hasGoogleAPIKey() -> Bool {
        guard let key = getGoogleAPIKey() else { return false }
        return !key.isEmpty
    }

    func deleteGoogleAPIKey() -> Bool {
        defaults.removeObject(forKey: googleKey)
        defaults.removeObject(forKey: legacyGoogleKey)
        return true
    }

    // MARK: - Private

    private func storageKey(for provider: APIProvider) -> String {
        switch provider {
        case .google:
            return googleKey
        case .openrouter:
            return openRouterKey
        }
    }
}
