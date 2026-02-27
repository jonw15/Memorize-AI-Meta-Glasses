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

    // Exclude thumbnailData from Codable — stored as files instead
    enum CodingKeys: String, CodingKey {
        case id, pageNumber, timestamp, extractedText, status
    }

    init(pageNumber: Int, extractedText: String = "", status: PageCaptureStatus = .capturing, thumbnailData: Data? = nil) {
        self.id = UUID()
        self.pageNumber = pageNumber
        self.timestamp = Date()
        self.extractedText = extractedText
        self.status = status
        self.thumbnailData = thumbnailData
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
    var pages: [PageCapture]
    let createdAt: Date
    var updatedAt: Date

    init(title: String = "", author: String = "", pages: [PageCapture] = []) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.pages = pages
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var currentPage: Int {
        return pages.count
    }

    var completedPages: Int {
        return pages.filter { $0.status == .completed }.count
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
