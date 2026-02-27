/*
 * Memorize Service
 * AI-powered OCR and book info extraction using Gemini Vision API
 */

import Foundation
import UIKit

struct MemorizeService {
    private let visionService: VisionAPIService

    init() {
        self.visionService = VisionAPIService()
    }

    // MARK: - Extract Text (OCR)

    func extractText(from image: UIImage) async throws -> String {
        let prompt = """
        You are an OCR assistant. Extract ALL text from this book page image accurately.

        Requirements:
        1. Preserve the original text layout and paragraph structure
        2. Include headings, body text, and any captions
        3. Do NOT add any commentary or description - only output the extracted text
        4. If text is unclear, make your best attempt and mark unclear parts with [unclear]
        5. Preserve the original language of the text
        """

        return try await visionService.analyzeImage(image, prompt: prompt)
    }

    // MARK: - Detect Book Info

    func detectBookInfo(from text: String) async throws -> (title: String, author: String) {
        let prompt = """
        Based on this text extracted from a book page, detect the book title and author.

        Text:
        \(text)

        Respond in EXACTLY this format (nothing else):
        TITLE: <book title>
        AUTHOR: <author name>

        If you cannot detect the title, use "Unknown Book".
        If you cannot detect the author, use "Unknown Author".
        """

        // Use a text-only request by creating a small placeholder
        let result = try await visionService.analyzeImage(createPlaceholderImage(), prompt: prompt)

        return parseBookInfo(from: result)
    }

    // MARK: - Private Helpers

    private func parseBookInfo(from response: String) -> (title: String, author: String) {
        var title = "memorize.unknown_book".localized
        var author = "memorize.unknown_author".localized

        let lines = response.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("TITLE:") {
                title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.uppercased().hasPrefix("AUTHOR:") {
                author = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            }
        }

        return (title, author)
    }

    private func createPlaceholderImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }
}
