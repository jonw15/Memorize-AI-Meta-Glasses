/*
 * Memorize Models
 * Data models for the Memorize book learning feature
 */

import Foundation

// MARK: - Page Capture Status

enum PageCaptureStatus: String, Codable {
    case capturing
    case processing
    case completed
    case failed
}

// MARK: - Page Capture

struct PageCapture: Identifiable, Codable {
    let id: UUID
    let pageNumber: Int
    let timestamp: Date
    var extractedText: String
    var status: PageCaptureStatus
    var thumbnailData: Data?  // runtime only, not persisted in JSON
    var processingProgress: Double? // runtime only, not persisted in JSON

    // Exclude thumbnailData from Codable — stored as files instead
    enum CodingKeys: String, CodingKey {
        case id, pageNumber, timestamp, extractedText, status
    }

    init(
        pageNumber: Int,
        extractedText: String = "",
        status: PageCaptureStatus = .capturing,
        thumbnailData: Data? = nil,
        processingProgress: Double? = nil
    ) {
        self.id = UUID()
        self.pageNumber = pageNumber
        self.timestamp = Date()
        self.extractedText = extractedText
        self.status = status
        self.thumbnailData = thumbnailData
        self.processingProgress = processingProgress
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Source Type

enum SourceType: String, Codable {
    case camera
    case pdf
    case textNote
    case file
    case youtube
}

// MARK: - Source

struct Source: Identifiable, Codable {
    let id: UUID
    var name: String
    var sourceType: SourceType
    var pages: [PageCapture]
    let createdAt: Date
    var updatedAt: Date

    init(name: String, sourceType: SourceType, pages: [PageCapture] = []) {
        self.id = UUID()
        self.name = name
        self.sourceType = sourceType
        self.pages = pages
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var completedPages: Int {
        pages.filter { $0.status == .completed }.count
    }

    var iconName: String {
        switch sourceType {
        case .camera: return "camera.fill"
        case .pdf: return "doc.fill"
        case .textNote: return "note.text"
        case .file: return "doc.text.fill"
        case .youtube: return "play.rectangle.fill"
        }
    }
}

// MARK: - Generated Notes

enum GeneratedNoteKind: String, Codable {
    case tutor
    case interact
    case explain
    case podcast
    case infographics
    case quiz
    case voiceSummary
    case studyGuide
    case userNote

    var displayTitle: String {
        switch self {
        case .tutor:
            return "memorize.tutor.title".localized
        case .interact:
            return "memorize.interact".localized
        case .explain:
            return "memorize.explain".localized
        case .podcast:
            return "memorize.podcast".localized
        case .infographics:
            return "memorize.infographics".localized
        case .quiz:
            return "memorize.pop_quiz".localized
        case .voiceSummary:
            return "memorize.voice_summary".localized
        case .studyGuide:
            return "Study guide"
        case .userNote:
            return "My note"
        }
    }

    var promptName: String {
        switch self {
        case .tutor:
            return "AI tutoring session"
        case .interact:
            return "conversation study mode"
        case .explain:
            return "summary study mode"
        case .podcast:
            return "podcast study mode"
        case .infographics:
            return "infographics study mode"
        case .quiz:
            return "pop quiz study mode"
        case .voiceSummary:
            return "voice summary study mode"
        case .studyGuide:
            return "study guide"
        case .userNote:
            return "user-written note"
        }
    }
}

struct GeneratedNote: Identifiable, Codable {
    let id: UUID
    var title: String
    var body: String
    var mode: GeneratedNoteKind
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        mode: GeneratedNoteKind,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.mode = mode
        self.createdAt = createdAt
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var previewText: String {
        let cleaned = body
            .components(separatedBy: .newlines)
            .map {
                $0.replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-*•# \t"))
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard cleaned.count > 220 else { return cleaned }
        let endIndex = cleaned.index(cleaned.startIndex, offsetBy: 220)
        return String(cleaned[..<endIndex]) + "..."
    }
}

struct GeneratedSlideDeck: Identifiable, Codable {
    let id: UUID
    var title: String
    var slides: [GeneratedSlide]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        slides: [GeneratedSlide],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.slides = slides
        self.createdAt = createdAt
    }
}

struct GeneratedSlide: Identifiable, Codable {
    let id: UUID
    var title: String
    var bullets: [String]
    var speakerNotes: String

    init(
        id: UUID = UUID(),
        title: String,
        bullets: [String],
        speakerNotes: String
    ) {
        self.id = id
        self.title = title
        self.bullets = bullets
        self.speakerNotes = speakerNotes
    }
}

struct GeneratedPaper: Identifiable, Codable {
    let id: UUID
    var title: String
    var body: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}

// MARK: - AI Study Topic

struct StudyTopic: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var summary: String
    var pageIDs: [UUID]

    init(id: UUID = UUID(), title: String, summary: String = "", pageIDs: [UUID] = []) {
        self.id = id
        self.title = title
        self.summary = summary
        self.pageIDs = pageIDs
    }
}

// MARK: - Weak Topic

struct WeakTopicRecord: Identifiable, Codable, Equatable {
    let topicID: UUID
    var topicTitle: String
    var attemptCount: Int
    var missCount: Int
    var lastSeenAt: Date

    var id: UUID { topicID }

    var missRate: Double {
        guard attemptCount > 0 else { return 0 }
        return Double(missCount) / Double(attemptCount)
    }
}

// MARK: - Book

struct Book: Identifiable, Codable {
    let id: UUID
    var title: String
    var author: String
    var chapter: String
    var icon: String  // AI-assigned emoji
    var pages: [PageCapture]
    var sections: [Book]
    var sources: [Source]
    var notes: [GeneratedNote]
    var aiTopics: [StudyTopic]
    var aiTopicsSignature: String
    var weakTopics: [WeakTopicRecord]
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, author, chapter, icon, pages, sections, sources, notes, aiTopics, aiTopicsSignature, weakTopics, createdAt, updatedAt
    }

    init(title: String = "", author: String = "", chapter: String = "", icon: String = "", pages: [PageCapture] = [], sections: [Book] = [], sources: [Source] = [], notes: [GeneratedNote] = [], aiTopics: [StudyTopic] = [], aiTopicsSignature: String = "", weakTopics: [WeakTopicRecord] = []) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.chapter = chapter
        self.icon = icon
        self.pages = pages
        self.sections = sections
        self.sources = sources
        self.notes = notes
        self.aiTopics = aiTopics
        self.aiTopicsSignature = aiTopicsSignature
        self.weakTopics = weakTopics
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        chapter = try container.decodeIfPresent(String.self, forKey: .chapter) ?? ""
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? ""
        pages = try container.decodeIfPresent([PageCapture].self, forKey: .pages) ?? []
        sections = try container.decodeIfPresent([Book].self, forKey: .sections) ?? []
        sources = try container.decodeIfPresent([Source].self, forKey: .sources) ?? []
        notes = try container.decodeIfPresent([GeneratedNote].self, forKey: .notes) ?? []
        aiTopics = try container.decodeIfPresent([StudyTopic].self, forKey: .aiTopics) ?? []
        aiTopicsSignature = try container.decodeIfPresent(String.self, forKey: .aiTopicsSignature) ?? ""
        weakTopics = try container.decodeIfPresent([WeakTopicRecord].self, forKey: .weakTopics) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(chapter, forKey: .chapter)
        try container.encode(icon, forKey: .icon)
        try container.encode(pages, forKey: .pages)
        try container.encode(sections, forKey: .sections)
        try container.encode(sources, forKey: .sources)
        try container.encode(notes, forKey: .notes)
        try container.encode(aiTopics, forKey: .aiTopics)
        try container.encode(aiTopicsSignature, forKey: .aiTopicsSignature)
        try container.encode(weakTopics, forKey: .weakTopics)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    /// All content pages from legacy pages + all sources, for study actions
    var allPages: [PageCapture] {
        pages + sources.flatMap(\.pages) + sections.flatMap(\.allPages)
    }

    var sourceCount: Int {
        var count = sources.count
        if !pages.isEmpty { count += 1 } // Legacy camera pages count as one source
        return max(count, 0)
    }

    var currentPage: Int {
        return pages.count
    }

    var completedPages: Int {
        return pages.filter { $0.status == .completed }.count
    }

    var hasSections: Bool {
        return !sections.isEmpty
    }

    var totalSectionPages: Int {
        return sections.reduce(0) { $0 + $1.completedPages }
    }
}

// MARK: - Quiz Question

struct QuizQuestion: Identifiable, Codable {
    let id: UUID
    let type: String?
    let concept: String?
    let question: String
    let options: [String]       // 4 choices
    let correctIndex: Int       // index of correct answer
    let explanation: String?
    var selectedIndex: Int?     // user's pick (nil = unanswered)

    init(
        id: UUID = UUID(),
        type: String? = nil,
        concept: String? = nil,
        question: String,
        options: [String],
        correctIndex: Int,
        explanation: String? = nil,
        selectedIndex: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.concept = concept
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
        self.selectedIndex = selectedIndex
    }
}
