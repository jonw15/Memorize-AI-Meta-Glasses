/*
 * Memorize Storage Service
 * Book persistence service using UserDefaults + Codable
 */

import Foundation

class MemorizeStorage {
    static let shared = MemorizeStorage()

    private let userDefaults = UserDefaults.standard
    private let booksKey = "memorize_books"
    private let maxBooks = 50

    private let fileManager = FileManager.default
    private lazy var thumbnailsDir: URL = {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("memorize_thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    // MARK: - Save Book

    func saveBook(_ book: Book) {
        var books = loadBooks()

        // Add new book at the beginning
        books.insert(book, at: 0)

        // Keep only the most recent maxBooks
        if books.count > maxBooks {
            books = Array(books.prefix(maxBooks))
        }

        if let encoded = try? JSONEncoder().encode(books) {
            userDefaults.set(encoded, forKey: booksKey)
            print("📚 [MemorizeStorage] Book saved: \(book.title), total: \(books.count)")
        } else {
            print("❌ [MemorizeStorage] Failed to save book")
        }
    }

    // MARK: - Load Books

    func loadBooks() -> [Book] {
        guard let data = userDefaults.data(forKey: booksKey),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return []
        }
        return books
    }

    // MARK: - Update Book

    func updateBook(_ book: Book) {
        var books = loadBooks()
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
            if let encoded = try? JSONEncoder().encode(books) {
                userDefaults.set(encoded, forKey: booksKey)
                print("📚 [MemorizeStorage] Book updated: \(book.title)")
            }
        }
    }

    // MARK: - Delete Book

    func deleteBook(_ id: UUID) {
        // Delete thumbnail files for this book's pages
        let books = loadBooks()
        if let book = books.first(where: { $0.id == id }) {
            for page in book.pages {
                deleteThumbnail(for: page.id)
            }
        }

        let updatedBooks = books.filter { $0.id != id }

        if let encoded = try? JSONEncoder().encode(updatedBooks) {
            userDefaults.set(encoded, forKey: booksKey)
            print("🗑️ [MemorizeStorage] Book deleted: \(id)")
        }
    }

    // MARK: - Thumbnail File Storage

    func saveThumbnail(_ data: Data, for pageId: UUID) {
        let url = thumbnailsDir.appendingPathComponent("\(pageId.uuidString).jpg")
        try? data.write(to: url)
    }

    func loadThumbnail(for pageId: UUID) -> Data? {
        let url = thumbnailsDir.appendingPathComponent("\(pageId.uuidString).jpg")
        return try? Data(contentsOf: url)
    }

    func deleteThumbnail(for pageId: UUID) {
        let url = thumbnailsDir.appendingPathComponent("\(pageId.uuidString).jpg")
        try? fileManager.removeItem(at: url)
    }

    /// Load thumbnails from disk into a book's pages
    func loadThumbnails(for book: inout Book) {
        var validPages: [PageCapture] = []
        for var page in book.pages {
            if let data = loadThumbnail(for: page.id) {
                page.thumbnailData = data
                validPages.append(page)
            } else {
                print("⚠️ [MemorizeStorage] Dropped ghost page \(page.id) (No thumbnail found)")
            }
        }
        book.pages = validPages
    }
}
