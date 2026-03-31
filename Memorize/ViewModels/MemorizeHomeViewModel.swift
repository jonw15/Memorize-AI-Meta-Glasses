/*
 * Memorize Home ViewModel
 * Manages book library state for the Memorize home screen
 */

import Foundation

@MainActor
class MemorizeHomeViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var currentBook: Book?

    private let storage = MemorizeStorage.shared
    private let memorizeService = MemorizeService()

    func loadBooks() {
        books = storage.loadBooks()
        // Set current book to the most recently updated one
        currentBook = books.first

        // Assign icons to books that don't have one yet
        for book in books where book.icon.isEmpty && !book.title.isEmpty {
            assignIcon(for: book.id, title: book.title)
        }
    }

    func deleteBook(_ id: UUID) {
        storage.deleteBook(id)
        books.removeAll { $0.id == id }
        if currentBook?.id == id {
            currentBook = books.first
        }
    }

    func setCurrentBook(_ book: Book) {
        currentBook = book
    }

    func assignIcon(for bookId: UUID, title: String) {
        Task {
            do {
                let emoji = try await memorizeService.generateIconEmoji(for: title)
                // Update in storage
                var allBooks = storage.loadBooks()
                if let index = allBooks.firstIndex(where: { $0.id == bookId }) {
                    allBooks[index].icon = emoji
                    storage.updateBook(allBooks[index])
                }
                // Update local state
                if let index = books.firstIndex(where: { $0.id == bookId }) {
                    books[index].icon = emoji
                }
                print("🎨 [Home] Assigned icon \(emoji) to \(title)")
            } catch {
                print("⚠️ [Home] Failed to generate icon for \(title): \(error)")
            }
        }
    }
}
