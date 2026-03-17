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
