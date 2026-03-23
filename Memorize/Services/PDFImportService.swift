/*
 * PDF Import Service
 * Extracts text and thumbnails from PDF files for the Memorize book library
 */

import Foundation
import PDFKit
import UIKit

class PDFImportService {

    struct PDFImportResult {
        let title: String
        let author: String
        let pages: [PageCapture]
        let thumbnails: [(pageId: UUID, data: Data)]
    }

    struct PDFImportProgress {
        let currentPage: Int
        let totalPages: Int
    }

    // MARK: - Import PDF

    func importPDF(
        from url: URL,
        progressHandler: @escaping (PDFImportProgress) -> Void
    ) async throws -> PDFImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            throw PDFImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: url) else {
            throw PDFImportError.invalidPDF
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            throw PDFImportError.emptyPDF
        }

        // Extract metadata
        let metadata = extractMetadata(from: document, url: url)

        var pages: [PageCapture] = []
        var thumbnails: [(pageId: UUID, data: Data)] = []

        for i in 0..<pageCount {
            guard let pdfPage = document.page(at: i) else { continue }

            await MainActor.run {
                progressHandler(PDFImportProgress(currentPage: i + 1, totalPages: pageCount))
            }

            // Extract text
            let text = pdfPage.string ?? ""

            // Render thumbnail
            let thumbnailData = renderThumbnail(for: pdfPage)

            let page = PageCapture(
                pageNumber: i + 1,
                extractedText: text.trimmingCharacters(in: .whitespacesAndNewlines),
                status: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .failed : .completed,
                thumbnailData: thumbnailData
            )

            pages.append(page)

            if let thumbnailData {
                thumbnails.append((pageId: page.id, data: thumbnailData))
            }
        }

        return PDFImportResult(
            title: metadata.title,
            author: metadata.author,
            pages: pages,
            thumbnails: thumbnails
        )
    }

    // MARK: - Extract Metadata

    private func extractMetadata(from document: PDFDocument, url: URL) -> (title: String, author: String) {
        let attributes = document.documentAttributes
        let rawTitle = attributes?[PDFDocumentAttribute.titleAttribute] as? String
        let rawAuthor = attributes?[PDFDocumentAttribute.authorAttribute] as? String

        let title = (rawTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let author = (rawAuthor ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // Fall back to filename if no title in metadata
        let finalTitle = title.isEmpty
            ? url.deletingPathExtension().lastPathComponent
            : title

        return (finalTitle, author)
    }

    // MARK: - Render Thumbnail

    private func renderThumbnail(for page: PDFPage) -> Data? {
        let pageRect = page.bounds(for: .mediaBox)
        let targetWidth: CGFloat = 300
        let scale = targetWidth / pageRect.width
        let targetSize = CGSize(
            width: targetWidth,
            height: pageRect.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))

            context.cgContext.translateBy(x: 0, y: targetSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }

        return image.jpegData(compressionQuality: 0.3)
    }

    // MARK: - Detect Sections

    struct PDFSection {
        let title: String
        let pageIndices: [Int]  // 0-based indices into the pages array
    }

    func detectSections(from pages: [PageCapture]) async throws -> [PDFSection] {
        // Build a summary of each page's opening text for the AI to analyze
        var pageSummaries: [String] = []
        for (i, page) in pages.enumerated() {
            let preview = String(page.extractedText.prefix(300))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            pageSummaries.append("Page \(i + 1): \(preview)")
        }

        let prompt = """
        Analyze these PDF page previews and identify chapter/section boundaries.

        \(pageSummaries.joined(separator: "\n"))

        Rules:
        1. Only include: Introduction/Preface, numbered or named chapters, and Conclusion/Epilogue
        2. EXCLUDE these page types: title pages, copyright pages, dedication, table of contents, acknowledgments, about the author, bibliography, index, appendix, blank pages
        3. Group consecutive pages that belong to the same chapter together

        Respond with ONLY a JSON array, no other text:
        [
          {"title": "Introduction", "startPage": 1, "endPage": 5},
          {"title": "Chapter 1: Name", "startPage": 6, "endPage": 20}
        ]

        Use the actual chapter titles from the text. Page numbers are 1-based.
        """

        let visionService = VisionAPIService()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let placeholder = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        let result = try await visionService.analyzeImage(placeholder, prompt: prompt)
        return parseSections(from: result, totalPages: pages.count)
    }

    private func parseSections(from response: String, totalPages: Int) -> [PDFSection] {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract JSON array from response
        guard let regex = try? NSRegularExpression(pattern: "\\[[\\s\\S]*\\]", options: []) else {
            return fallbackSingleSection(totalPages: totalPages)
        }
        let nsRange = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
        guard let match = regex.firstMatch(in: cleaned, options: [], range: nsRange),
              let range = Range(match.range, in: cleaned) else {
            return fallbackSingleSection(totalPages: totalPages)
        }

        let jsonString = String(cleaned[range])
        guard let data = jsonString.data(using: .utf8) else {
            return fallbackSingleSection(totalPages: totalPages)
        }

        struct RawSection: Decodable {
            let title: String
            let startPage: Int
            let endPage: Int
        }

        do {
            let raw = try JSONDecoder().decode([RawSection].self, from: data)
            return raw.compactMap { section in
                let start = max(section.startPage - 1, 0)  // convert to 0-based
                let end = min(section.endPage - 1, totalPages - 1)
                guard start <= end else { return nil }
                return PDFSection(
                    title: section.title,
                    pageIndices: Array(start...end)
                )
            }
        } catch {
            print("❌ [Memorize] Section detection JSON parse error: \(error)")
            return fallbackSingleSection(totalPages: totalPages)
        }
    }

    private func fallbackSingleSection(totalPages: Int) -> [PDFSection] {
        return [PDFSection(title: "", pageIndices: Array(0..<totalPages))]
    }
}

// MARK: - Errors

enum PDFImportError: LocalizedError {
    case accessDenied
    case invalidPDF
    case emptyPDF

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Cannot access the selected file."
        case .invalidPDF:
            return "The selected file is not a valid PDF."
        case .emptyPDF:
            return "The PDF has no pages."
        }
    }
}
