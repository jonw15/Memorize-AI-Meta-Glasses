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

    func loadBooks() {
        books = storage.loadBooks()
        // Set current book to the most recently updated one
        currentBook = books.first
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
}
