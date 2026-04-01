/*
 * Project Detail ViewModel
 * Manages a single Book's sources and study actions
 */

import Foundation

@MainActor
class ProjectDetailViewModel: ObservableObject {
    @Published var book: Book
    @Published var isImportingPDF = false
    @Published var pdfImportProgress: PDFImportService.PDFImportProgress?
    @Published var pdfImportError: String?
    @Published var showFilePicker = false
    @Published var filePickerMode: FilePickerMode = .pdf

    enum FilePickerMode {
        case pdf, textFile
    }

    // Study action state
    @Published var quizQuestions: [QuizQuestion] = []
    @Published var isGeneratingQuiz = false
    @Published var showQuiz = false
    @Published var showPodcastPlayer = false
    @Published var podcastMode: PodcastMode = .interactive
    @Published var showPodcastModePicker = false
    @Published var podcastErrorMessage: String?
    @Published var isGeneratingExplanation = false
    @Published var showExplain = false
    @Published var explanationPersona: MemorizeExplainPersona = .likeIAm5
    @Published var explanationText: String = ""

    private let storage = MemorizeStorage.shared
    private let memorizeService = MemorizeService()
    private let pdfImportService = PDFImportService()

    var allCompletedPages: [PageCapture] {
        book.allPages.filter { $0.status == .completed }
    }

    var hasContent: Bool {
        !allCompletedPages.isEmpty
    }

    init(book: Book) {
        self.book = book
    }

    // MARK: - Source Management

    func addSource(_ source: Source) {
        book.sources.append(source)
        book.updatedAt = Date()
        storage.updateBook(book)
        print("📚 [ProjectDetail] Added source: \(source.name) (\(source.sourceType.rawValue))")

        // Auto-detect title if project is untitled
        if book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            autoDetectTitle()
        }
    }

    func renameProject(to newTitle: String) {
        book.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        book.updatedAt = Date()
        storage.updateBook(book)
    }

    private func autoDetectTitle() {
        let pages = book.allPages.filter { $0.status == .completed }
        guard !pages.isEmpty else { return }
        let sampleText = String(pages.first!.extractedText.prefix(500))
        guard !sampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        Task {
            do {
                let info = try await memorizeService.detectBookInfo(from: sampleText)
                if !info.title.isEmpty && info.title != "Unknown Book" {
                    book.title = info.title
                    if book.author.isEmpty && info.author != "Unknown Author" {
                        book.author = info.author
                    }
                    book.updatedAt = Date()
                    storage.updateBook(book)
                    print("📖 [ProjectDetail] Auto-detected title: \(info.title)")
                }
            } catch {
                print("⚠️ [ProjectDetail] Title detection failed: \(error)")
            }
        }
    }

    func deleteSource(_ sourceId: UUID) {
        guard let index = book.sources.firstIndex(where: { $0.id == sourceId }) else { return }
        let source = book.sources[index]
        for page in source.pages {
            storage.deleteThumbnail(for: page.id)
        }
        book.sources.remove(at: index)
        book.updatedAt = Date()
        storage.updateBook(book)
        print("🗑️ [ProjectDetail] Deleted source: \(source.name)")
    }

    func addTextNote(title: String, text: String) {
        let page = PageCapture(pageNumber: 1, extractedText: text, status: .completed)
        let source = Source(name: title, sourceType: .textNote, pages: [page])
        addSource(source)
    }

    func addCameraPages(_ pages: [PageCapture]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let name = "Camera · \(formatter.string(from: Date()))"
        let source = Source(name: name, sourceType: .camera, pages: pages)
        addSource(source)
    }

    func importPDF(from url: URL) async {
        isImportingPDF = true
        pdfImportError = nil
        pdfImportProgress = nil

        do {
            let result = try await pdfImportService.importPDF(from: url) { [weak self] progress in
                Task { @MainActor in
                    self?.pdfImportProgress = progress
                }
            }

            // Save thumbnails
            for (pageId, data) in result.thumbnails {
                storage.saveThumbnail(data, for: pageId)
            }

            let source = Source(name: result.title, sourceType: .pdf, pages: result.pages)
            addSource(source)

            isImportingPDF = false
            pdfImportProgress = nil
            print("📄 [ProjectDetail] PDF imported: \(result.title) (\(result.pages.count) pages)")
        } catch {
            pdfImportError = error.localizedDescription
            isImportingPDF = false
            pdfImportProgress = nil
            print("❌ [ProjectDetail] PDF import failed: \(error)")
        }
    }

    // MARK: - Study Actions

    func generateQuiz() {
        let pages = allCompletedPages
        print("🧪 [ProjectDetail] generateQuiz — allPages: \(book.allPages.count), completed: \(pages.count), legacy pages: \(book.pages.count), sources: \(book.sources.count)")
        guard !pages.isEmpty else {
            print("🧪 [ProjectDetail] No completed pages — skipping quiz")
            return
        }
        isGeneratingQuiz = true
        quizQuestions = []

        Task {
            do {
                let questions = try await memorizeService.generateQuiz(from: pages)
                quizQuestions = questions
                showQuiz = true
            } catch {
                print("❌ [ProjectDetail] Quiz generation failed: \(error)")
            }
            isGeneratingQuiz = false
        }
    }

    func startPodcast() {
        showPodcastModePicker = true
    }

    func startPodcastWithMode(_ mode: PodcastMode) {
        podcastMode = mode
        showPodcastModePicker = false
        showPodcastPlayer = true
    }

    func generateExplanation(as persona: MemorizeExplainPersona) {
        let pages = allCompletedPages
        guard !pages.isEmpty else { return }
        explanationPersona = persona
        isGeneratingExplanation = true
        explanationText = ""

        Task {
            do {
                let text = try await memorizeService.explainSection(from: pages, as: persona)
                explanationText = text
                showExplain = true
            } catch {
                print("❌ [ProjectDetail] Explanation generation failed: \(error)")
            }
            isGeneratingExplanation = false
        }
    }

    func reload() {
        let books = storage.loadBooks()
        if let updated = books.first(where: { $0.id == book.id }) {
            book = updated
            // Load thumbnails but don't drop pages that lack them (text-only sources are valid)
            for i in book.pages.indices {
                if let data = storage.loadThumbnail(for: book.pages[i].id) {
                    book.pages[i].thumbnailData = data
                }
            }
            for i in book.sources.indices {
                for j in book.sources[i].pages.indices {
                    if let data = storage.loadThumbnail(for: book.sources[i].pages[j].id) {
                        book.sources[i].pages[j].thumbnailData = data
                    }
                }
            }
        }
        print("📚 [ProjectDetail] Reloaded — pages: \(book.pages.count), sources: \(book.sources.count), allPages: \(book.allPages.count)")
    }
}
