import Foundation

enum PageCaptureStatus: String, Codable {
    case capturing, processing, completed, failed
}

struct PageCapture: Identifiable, Codable {
    let id: UUID
    let pageNumber: Int
    var status: PageCaptureStatus
    var thumbnailData: Data?

    enum CodingKeys: String, CodingKey {
        case id, pageNumber, status
    }

    init(pageNumber: Int, status: PageCaptureStatus = .capturing) {
        self.id = UUID()
        self.pageNumber = pageNumber
        self.status = status
    }
}

struct Book: Identifiable, Codable {
    let id: UUID
    var pages: [PageCapture]

    init(id: UUID = UUID(), pages: [PageCapture] = []) {
        self.id = id
        self.pages = pages
    }
}

class Storage {
    var storedBooksData: Data?

    func saveBook(_ book: Book) {
        var books = loadBooks()
        books.insert(book, at: 0)
        storedBooksData = try? JSONEncoder().encode(books)
        print("Storage saved. Pages count = \(books.first?.pages.count ?? 0)")
    }

    func loadBooks() -> [Book] {
        guard let data = storedBooksData,
              let books = try? JSONDecoder().decode([Book].self, from: data) else { return [] }
        return books
    }

    func updateBook(_ book: Book) {
        var books = loadBooks()
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
            storedBooksData = try? JSONEncoder().encode(books)
            print("Storage updated. Pages count = \(books[index].pages.count)")
        }
    }

    func loadThumbnails(for book: inout Book) {
        var validPages: [PageCapture] = []
        for var page in book.pages {
            // SIMULATE: only page 1 has a thumbnail
            if page.pageNumber == 1 {
                page.thumbnailData = Data("Valid".utf8)
                validPages.append(page)
            } else {
                print("⚠️ Dropped ghost page \(page.id)")
            }
        }
        book.pages = validPages
        print("loadThumbnails finished. Validation kept \(validPages.count) pages.")
    }
}

let storage = Storage()

// 1. Initial State
print("--- 1. Initial App State ---")
var currentBook = Book()
print("Book ID = \(currentBook.id)")

// 2. Take first snapshot (completes successfully)
print("--- 2. Taking Snapshot 1 ---")
var page1 = PageCapture(pageNumber: 1, status: .capturing)
currentBook.pages.append(page1)

// (saveProgress is called)
storage.saveBook(currentBook)

// (image transfer completes, page processing complete)
page1.status = .processing
currentBook.pages[0] = page1
// Simulate thumbnail creation...
storage.updateBook(currentBook)

print("--- 3. Taking Snapshot 2 (Unfinished) ---")
// 3. Take second snapshot (fails/interrupts)
var page2 = PageCapture(pageNumber: 2, status: .capturing)
currentBook.pages.append(page2)

// (saveProgress is called immediately)
storage.updateBook(currentBook)

// App is killed here...

print("--- 4. Reload App ---")
// 4. App reloads
var books = storage.loadBooks()
var loadedBook = books[0]
print("Loaded book pages count: \(loadedBook.pages.count)")

// 5. Open Memorize Capture View
print("--- 5. Open Memorize Capture View ---")
storage.loadThumbnails(for: &loadedBook)

print("Final loaded book pages count: \(loadedBook.pages.count)")

// NOW WHAT DOES CAPTURE VIEW DO?
// It calls: `viewModel.loadBook(book)`
func loadBook(_ book: Book?) -> Book {
    if var book = book {
        // Assume loadThumbnails is already called or called again here
        return book
    } else {
        return Book()
    }
}

var vmBook = loadBook(loadedBook)
print("VM Book pages count: \(vmBook.pages.count)")
