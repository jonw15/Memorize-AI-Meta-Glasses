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
        var books = loadBooks()
        books.removeAll { $0.id == id }

        if let encoded = try? JSONEncoder().encode(books) {
            userDefaults.set(encoded, forKey: booksKey)
            print("🗑️ [MemorizeStorage] Book deleted: \(id)")
        }
    }
}
