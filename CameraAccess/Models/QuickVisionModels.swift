/*
 * Quick Vision Models
 * Quick vision data model - recognition modes and history records
 */

import Foundation
import UIKit

// MARK: - Quick Vision Mode

enum QuickVisionMode: String, CaseIterable, Codable, Identifiable {
    case standard = "standard"      // Default mode
    case health = "health"          // Health recognition
    case blind = "blind"            // Blind assistance mode
    case reading = "reading"        // Reading mode
    case translate = "translate"    // Translation mode
    case encyclopedia = "encyclopedia" // Encyclopedia (museum) mode
    case custom = "custom"          // Custom prompt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:
            return "quickvision.mode.standard".localized
        case .health:
            return "quickvision.mode.health".localized
        case .blind:
            return "quickvision.mode.blind".localized
        case .reading:
            return "quickvision.mode.reading".localized
        case .translate:
            return "quickvision.mode.translate".localized
        case .encyclopedia:
            return "quickvision.mode.encyclopedia".localized
        case .custom:
            return "quickvision.mode.custom".localized
        }
    }

    var icon: String {
        switch self {
        case .standard:
            return "eye.circle"
        case .health:
            return "heart.circle"
        case .blind:
            return "figure.walk.circle"
        case .reading:
            return "text.viewfinder"
        case .translate:
            return "character.bubble"
        case .encyclopedia:
            return "books.vertical.circle"
        case .custom:
            return "pencil.circle"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "quickvision.mode.standard.desc".localized
        case .health:
            return "quickvision.mode.health.desc".localized
        case .blind:
            return "quickvision.mode.blind.desc".localized
        case .reading:
            return "quickvision.mode.reading.desc".localized
        case .translate:
            return "quickvision.mode.translate.desc".localized
        case .encyclopedia:
            return "quickvision.mode.encyclopedia.desc".localized
        case .custom:
            return "quickvision.mode.custom.desc".localized
        }
    }

    /// Get the prompt for this mode
    var prompt: String {
        switch self {
        case .standard:
            return "prompt.quickvision".localized
        case .health:
            return "prompt.quickvision.health".localized
        case .blind:
            return "prompt.quickvision.blind".localized
        case .reading:
            return "prompt.quickvision.reading".localized
        case .translate:
            // Translation mode needs to get the target language from Manager
            return "prompt.quickvision.translate".localized
        case .encyclopedia:
            return "prompt.quickvision.encyclopedia".localized
        case .custom:
            // Custom mode needs to get the prompt from Manager
            return ""
        }
    }
}

// MARK: - Quick Vision Record

struct QuickVisionRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let mode: QuickVisionMode
    let prompt: String
    let result: String
    let thumbnailData: Data?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        mode: QuickVisionMode,
        prompt: String,
        result: String,
        thumbnail: UIImage? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.mode = mode
        self.prompt = prompt
        self.result = result
        // Compress thumbnail to 100x100, quality 0.5
        if let image = thumbnail {
            let size = CGSize(width: 100, height: 100)
            let renderer = UIGraphicsImageRenderer(size: size)
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            self.thumbnailData = resized.jpegData(compressionQuality: 0.5)
        } else {
            self.thumbnailData = nil
        }
    }

    // Computed properties
    var thumbnail: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    var title: String {
        let content = result
        return content.count > 30 ? String(content.prefix(30)) + "..." : content
    }

    var summary: String {
        let content = result
        return content.count > 80 ? String(content.prefix(80)) + "..." : content
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(timestamp) {
            formatter.dateFormat = "HH:mm"
            return "quickvision.today".localized + " " + formatter.string(from: timestamp)
        } else if calendar.isDateInYesterday(timestamp) {
            formatter.dateFormat = "HH:mm"
            return "quickvision.yesterday".localized + " " + formatter.string(from: timestamp)
        } else if calendar.isDate(timestamp, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE HH:mm"
            return formatter.string(from: timestamp)
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: timestamp)
        }
    }
}
