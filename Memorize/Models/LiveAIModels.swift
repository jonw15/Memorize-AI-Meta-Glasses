/*
 * Live AI Models
 * Real-time conversation data model - conversation mode definitions
 */

import Foundation

// MARK: - Live AI Mode

enum LiveAIMode: String, CaseIterable, Codable, Identifiable {
    case standard = "standard"          // Default mode - free conversation
    case museum = "museum"              // Museum mode
    case blind = "blind"                // Blind assistance mode
    case reading = "reading"            // Reading mode
    case translate = "translate"        // Translation mode
    case custom = "custom"              // Custom prompt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:
            return "liveai.mode.standard".localized
        case .museum:
            return "liveai.mode.museum".localized
        case .blind:
            return "liveai.mode.blind".localized
        case .reading:
            return "liveai.mode.reading".localized
        case .translate:
            return "liveai.mode.translate".localized
        case .custom:
            return "liveai.mode.custom".localized
        }
    }

    var icon: String {
        switch self {
        case .standard:
            return "brain.head.profile"
        case .museum:
            return "building.columns.circle"
        case .blind:
            return "figure.walk.circle"
        case .reading:
            return "text.viewfinder"
        case .translate:
            return "character.bubble"
        case .custom:
            return "pencil.circle"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "liveai.mode.standard.desc".localized
        case .museum:
            return "liveai.mode.museum.desc".localized
        case .blind:
            return "liveai.mode.blind.desc".localized
        case .reading:
            return "liveai.mode.reading.desc".localized
        case .translate:
            return "liveai.mode.translate.desc".localized
        case .custom:
            return "liveai.mode.custom.desc".localized
        }
    }

    /// Get the system prompt for this mode
    var systemPrompt: String {
        switch self {
        case .standard:
            return "prompt.liveai.standard".localized
        case .museum:
            return "prompt.liveai.museum".localized
        case .blind:
            return "prompt.liveai.blind".localized
        case .reading:
            return "prompt.liveai.reading".localized
        case .translate:
            // Translation mode needs to get the target language from Manager
            return "prompt.liveai.translate".localized
        case .custom:
            // Custom mode needs to get the prompt from Manager
            return ""
        }
    }

    /// Whether to automatically send an image when the user speaks
    var autoSendImageOnSpeech: Bool {
        switch self {
        case .standard:
            return true  // Default mode: send image on voice trigger
        case .museum, .blind, .reading, .translate:
            return true  // These modes all require image viewing
        case .custom:
            return true  // Custom mode also supports images
        }
    }
}
