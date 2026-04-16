/*
 * Live AI Mode Manager
 * Real-time conversation mode manager - Manages current mode, custom prompts, translation target language
 */

import Foundation
import SwiftUI

@MainActor
final class LiveAIModeManager: ObservableObject {
    static let shared = LiveAIModeManager()

    private let userDefaults = UserDefaults.standard
    private let modeKey = "liveAIMode"
    private let customPromptKey = "liveAICustomPrompt"
    private let translateTargetLanguageKey = "liveAITranslateTargetLanguage"

    @Published var currentMode: LiveAIMode {
        didSet {
            userDefaults.set(currentMode.rawValue, forKey: modeKey)
            print("📋 [LiveAIModeManager] Mode switched: \(currentMode.displayName)")
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
           let mode = LiveAIMode(rawValue: savedMode) {
            self.currentMode = mode
        } else {
            self.currentMode = .standard
        }

        // Load custom prompt
        self.customPrompt = userDefaults.string(forKey: customPromptKey) ?? "liveai.custom.default".localized

        // Load translation target language (defaults to system language)
        if let savedLanguage = userDefaults.string(forKey: translateTargetLanguageKey) {
            self.translateTargetLanguage = savedLanguage
        } else {
            self.translateTargetLanguage = "en-US"
        }
    }

    // MARK: - Get Current System Prompt

    /// Get the full system prompt for the current mode
    func getSystemPrompt() -> String {
        switch currentMode {
        case .custom:
            return customPrompt
        case .translate:
            return getTranslatePrompt()
        default:
            return currentMode.systemPrompt
        }
    }

    /// Get the system prompt for a specified mode
    func getSystemPrompt(for mode: LiveAIMode) -> String {
        switch mode {
        case .custom:
            return customPrompt
        case .translate:
            return getTranslatePrompt()
        default:
            return mode.systemPrompt
        }
    }

    /// Get the translation mode prompt (includes target language)
    private func getTranslatePrompt() -> String {
        let targetLanguageName = Self.supportedLanguages.first { $0.code == translateTargetLanguage }?.name ?? "English"
        let basePrompt = "prompt.liveai.translate".localized
        return basePrompt.replacingOccurrences(of: "{LANGUAGE}", with: targetLanguageName)
    }

    // MARK: - Mode Management

    func setMode(_ mode: LiveAIMode) {
        currentMode = mode
    }

    func setCustomPrompt(_ prompt: String) {
        customPrompt = prompt
    }

    func setTranslateTargetLanguage(_ languageCode: String) {
        translateTargetLanguage = languageCode
    }

    // MARK: - Static Access (for non-SwiftUI contexts)

    nonisolated static var staticCurrentMode: LiveAIMode {
        let savedMode = UserDefaults.standard.string(forKey: "liveAIMode") ?? LiveAIMode.standard.rawValue
        return LiveAIMode(rawValue: savedMode) ?? .standard
    }

    nonisolated static var staticSystemPrompt: String {
        switch staticCurrentMode {
        case .custom:
            return UserDefaults.standard.string(forKey: "liveAICustomPrompt") ?? "liveai.custom.default".localized
        case .translate:
            let languageCode = UserDefaults.standard.string(forKey: "liveAITranslateTargetLanguage") ?? "en-US"
            let languageName = supportedLanguages.first { $0.code == languageCode }?.name ?? "English"
            let basePrompt = "prompt.liveai.translate".localized
            return basePrompt.replacingOccurrences(of: "{LANGUAGE}", with: languageName)
        default:
            return staticCurrentMode.systemPrompt
        }
    }

    /// Whether to automatically send an image when speech is triggered
    nonisolated static var staticAutoSendImageOnSpeech: Bool {
        return staticCurrentMode.autoSendImageOnSpeech
    }
}
