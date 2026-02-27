import Foundation

struct PageCapture: Identifiable, Codable {
    let id: UUID
    let pageNumber: Int
    var thumbnailData: Data?

    init(pageNumber: Int, thumbnailData: Data? = nil) {
        self.id = UUID()
        self.pageNumber = pageNumber
        self.thumbnailData = thumbnailData
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

class MemorizeStorage {
    static let shared = MemorizeStorage()

    private let fileManager = FileManager.default
    private lazy var thumbnailsDir: URL = {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("memorize_thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func saveThumbnail(_ data: Data, for pageId: UUID) {
        let url = thumbnailsDir.appendingPathComponent("\(pageId.uuidString).jpg")
        try? data.write(to: url)
    }

    func loadThumbnail(for pageId: UUID) -> Data? {
        let url = thumbnailsDir.appendingPathComponent("\(pageId.uuidString).jpg")
        return try? Data(contentsOf: url)
    }

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

// 1. Create a book with 1 valid page
let storage = MemorizeStorage.shared
var book = Book()

var page1 = PageCapture(pageNumber: 1)
let thumbData = Data("fake image".utf8)
storage.saveThumbnail(thumbData, for: page1.id)
book.pages.append(page1)

// 2. Simulate JSON save and load
let data = try! JSONEncoder().encode(book)
var loadedBook = try! JSONDecoder().decode(Book.self, from: data)

print("Before loadThumbnails: pages = \(loadedBook.pages.count)")
storage.loadThumbnails(for: &loadedBook)
print("After loadThumbnails: pages = \(loadedBook.pages.count)")
