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

// MARK: - Book

struct Book: Identifiable, Codable {
    let id: UUID
    var title: String
    var author: String
    var chapter: String
    var pages: [PageCapture]
    var sections: [Book]
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, author, chapter, pages, sections, createdAt, updatedAt
    }

    init(title: String = "", author: String = "", chapter: String = "", pages: [PageCapture] = [], sections: [Book] = []) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.chapter = chapter
        self.pages = pages
        self.sections = sections
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        chapter = try container.decodeIfPresent(String.self, forKey: .chapter) ?? ""
        pages = try container.decodeIfPresent([PageCapture].self, forKey: .pages) ?? []
        sections = try container.decodeIfPresent([Book].self, forKey: .sections) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(chapter, forKey: .chapter)
        try container.encode(pages, forKey: .pages)
        try container.encode(sections, forKey: .sections)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
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
    let question: String
    let options: [String]       // 4 choices
    let correctIndex: Int       // index of correct answer
    var selectedIndex: Int?     // user's pick (nil = unanswered)

    init(id: UUID = UUID(), question: String, options: [String], correctIndex: Int, selectedIndex: Int? = nil) {
        self.id = id
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.selectedIndex = selectedIndex
    }
}
