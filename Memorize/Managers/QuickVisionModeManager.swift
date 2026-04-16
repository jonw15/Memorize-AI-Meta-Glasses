/*
 * Quick Vision Mode Manager
 * Quick Vision Mode Manager - Manages current mode, custom prompts, translation target language
 */

import Foundation
import SwiftUI

@MainActor
final class QuickVisionModeManager: ObservableObject {
    static let shared = QuickVisionModeManager()

    private let userDefaults = UserDefaults.standard
    private let modeKey = "quickVisionMode"
    private let customPromptKey = "quickVisionCustomPrompt"
    private let translateTargetLanguageKey = "quickVisionTranslateTargetLanguage"

    @Published var currentMode: QuickVisionMode {
        didSet {
            userDefaults.set(currentMode.rawValue, forKey: modeKey)
            print("📋 [QuickVisionModeManager] Mode switched: \(currentMode.displayName)")
        }
    }

    @Published var customPrompt: String {
        didSet {
            userDefaults.set(customPrompt, forKey: customPromptKey)
        }
    }

    @Published var translateTargetLanguage: String {
        didSet {
            userDefaults.set(translateTargetLanguage, forKey: translateTargetLanguageKey)
        }
    }

    // Supported translation target languages
    nonisolated static let supportedLanguages: [(code: String, name: String)] = [
        ("en-US", "English"),
        ("zh-CN", "Chinese"),
        ("ja-JP", "日本語"),
        ("ko-KR", "한국어"),
        ("fr-FR", "Français"),
        ("de-DE", "Deutsch"),
        ("es-ES", "Español"),
        ("it-IT", "Italiano"),
        ("pt-BR", "Português"),
        ("ru-RU", "Русский")
    ]

    private init() {
        // Load saved mode
        if let savedMode = userDefaults.string(forKey: modeKey),
           let mode = QuickVisionMode(rawValue: savedMode) {
            self.currentMode = mode
        } else {
            self.currentMode = .standard
        }

        // Load custom prompt
        self.customPrompt = userDefaults.string(forKey: customPromptKey) ?? "quickvision.custom.default".localized

        // Load translation target language (defaults to system language)
        if let savedLanguage = userDefaults.string(forKey: translateTargetLanguageKey) {
            self.translateTargetLanguage = savedLanguage
        } else {
            self.translateTargetLanguage = "en-US"
        }
    }

    // MARK: - Get Current Prompt

    /// Get the full prompt for the current mode
    func getPrompt() -> String {
        switch currentMode {
        case .custom:
            return customPrompt
        case .translate:
            return getTranslatePrompt()
        default:
            return currentMode.prompt
        }
    }

    /// Get the prompt for a specified mode
    func getPrompt(for mode: QuickVisionMode) -> String {
        switch mode {
        case .custom:
            return customPrompt
        case .translate:
            return getTranslatePrompt()
        default:
            return mode.prompt
        }
    }

    /// Get the translation mode prompt (includes target language)
    private func getTranslatePrompt() -> String {
        let targetLanguageName = Self.supportedLanguages.first { $0.code == translateTargetLanguage }?.name ?? "English"
        let basePrompt = "prompt.quickvision.translate".localized
        return basePrompt.replacingOccurrences(of: "{LANGUAGE}", with: targetLanguageName)
    }

    // MARK: - Mode Management

    func setMode(_ mode: QuickVisionMode) {
        currentMode = mode
    }

    func setCustomPrompt(_ prompt: String) {
        customPrompt = prompt
    }

    func setTranslateTargetLanguage(_ languageCode: String) {
        translateTargetLanguage = languageCode
    }

    // MARK: - Static Access (for non-SwiftUI contexts)

    nonisolated static var staticCurrentMode: QuickVisionMode {
        let savedMode = UserDefaults.standard.string(forKey: "quickVisionMode") ?? QuickVisionMode.standard.rawValue
        return QuickVisionMode(rawValue: savedMode) ?? .standard
    }

    nonisolated static var staticPrompt: String {
        switch staticCurrentMode {
        case .custom:
            return UserDefaults.standard.string(forKey: "quickVisionCustomPrompt") ?? "quickvision.custom.default".localized
        case .translate:
            let languageCode = UserDefaults.standard.string(forKey: "quickVisionTranslateTargetLanguage") ?? "en-US"
            let languageName = supportedLanguages.first { $0.code == languageCode }?.name ?? "English"
            let basePrompt = "prompt.quickvision.translate".localized
            return basePrompt.replacingOccurrences(of: "{LANGUAGE}", with: languageName)
        default:
            return staticCurrentMode.prompt
        }
    }
}
