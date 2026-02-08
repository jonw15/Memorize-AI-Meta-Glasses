/*
 * Quick Vision Mode Manager
 * Quick Vision Mode Manager - Manages current mode, custom prompts, translation target language
 */

import Foundation
import SwiftUI

class QuickVisionModeManager: ObservableObject {
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
    static let supportedLanguages: [(code: String, name: String)] = [
        ("zh-CN", "Chinese"),
        ("en-US", "English"),
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
            self.translateTargetLanguage = LanguageManager.staticApiLanguageCode
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
        let targetLanguageName = Self.supportedLanguages.first { $0.code == translateTargetLanguage }?.name ?? "Chinese"
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

    static var staticCurrentMode: QuickVisionMode {
        return shared.currentMode
    }

    static var staticPrompt: String {
        return shared.getPrompt()
    }
}
