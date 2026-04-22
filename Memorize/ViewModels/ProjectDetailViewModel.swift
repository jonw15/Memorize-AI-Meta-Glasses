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
    @Published var isImportingYouTube = false
    @Published var youtubeImportError: String?
    @Published var showFilePicker = false
    @Published private(set) var sourceAddedToken: UUID?
    @Published var generatedNoteDraft: GeneratedNote?
    @Published var isGeneratingNoteDraft = false
    @Published var noteGenerationError: String?

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
    @Published private(set) var isDeleted = false

    private let storage = MemorizeStorage.shared
    private let memorizeService = MemorizeService()
    private let pdfImportService = PDFImportService()
    private let youtubeTranscriptImportService = YouTubeTranscriptImportService()
    private let wordsPerQuizQuestion = 85.0
    private let youtubeTranscriptChunkTargetChars = 2600
    private var pendingSessionTranscripts: [GeneratedNoteKind: String] = [:]
    private var hasPersistedBook: Bool

    var allCompletedPages: [PageCapture] {
        book.allPages.filter { $0.status == .completed }
    }

    var hasContent: Bool {
        !allCompletedPages.isEmpty
    }

    private var usesPDFQuizLengthHeuristic: Bool {
        book.sources.contains(where: { $0.sourceType == .pdf })
    }

    private var sourceWordCount: Int {
        allCompletedPages.reduce(0) { total, page in
            total + page.extractedText
                .split { $0.isWhitespace || $0.isNewline }
                .count
        }
    }

    private var targetQuizQuestionCount: Int {
        if usesPDFQuizLengthHeuristic {
            return max(4, allCompletedPages.count * 2)
        }

        let estimatedQuestions = Int(ceil(Double(max(sourceWordCount, 1)) / wordsPerQuizQuestion))
        return max(4, estimatedQuestions)
    }

    init(book: Book) {
        self.book = book
        self.hasPersistedBook = storage.bookExists(book.id)
    }

    // MARK: - Source Management

    func addSource(_ source: Source) {
        book.sources.append(source)

        if book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let preferredTitle = preferredProjectTitle(from: source) {
            book.title = preferredTitle
        }

        book.updatedAt = Date()

        // Save or update — if this is the first source, the book may not be in storage yet
        if storage.bookExists(book.id) {
            storage.updateBook(book)
        } else {
            storage.saveBook(book)
        }
        hasPersistedBook = true
        print("📚 [ProjectDetail] Added source: \(source.name) (\(source.sourceType.rawValue))")
        sourceAddedToken = UUID()

        // Auto-detect title if project is untitled
        if book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            autoDetectTitle()
        }
    }

    private func preferredProjectTitle(from source: Source) -> String? {
        let trimmedName = source.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        switch source.sourceType {
        case .youtube:
            guard !trimmedName.hasPrefix("YouTube ·") else { return nil }
            return trimmedName
        default:
            return nil
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

    private func makeTranscriptPages(from transcript: String) -> [PageCapture] {
        let pageTexts = splitTranscriptIntoChunks(transcript, targetChars: youtubeTranscriptChunkTargetChars)
        let texts = pageTexts.isEmpty ? [transcript.trimmingCharacters(in: .whitespacesAndNewlines)] : pageTexts

        return texts.enumerated().compactMap { index, text in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return PageCapture(pageNumber: index + 1, extractedText: trimmed, status: .completed)
        }
    }

    private func splitTranscriptIntoChunks(_ transcript: String, targetChars: Int) -> [String] {
        let normalized = transcript
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return [] }
        guard normalized.count > targetChars else { return [normalized] }

        var chunks: [String] = []
        var remaining = normalized[...]

        while remaining.count > targetChars {
            let maxEnd = remaining.index(remaining.startIndex, offsetBy: targetChars)
            let prefix = remaining[..<maxEnd]

            let paragraphBreak = prefix.range(of: "\n\n", options: .backwards)?.lowerBound
            let sentenceBreak = prefix.lastIndex(where: { ".!?".contains($0) }).map { remaining.index(after: $0) }
            let wordBreak = prefix.lastIndex(of: " ")

            let splitIndex = [paragraphBreak, sentenceBreak, wordBreak]
                .compactMap { $0 }
                .first(where: { remaining.distance(from: remaining.startIndex, to: $0) > targetChars / 2 })
                ?? maxEnd

            let chunk = String(remaining[..<splitIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                chunks.append(chunk)
            }

            remaining = remaining[splitIndex...]
            while let first = remaining.first, first.isWhitespace || first.isNewline {
                remaining = remaining.dropFirst()
            }
        }

        let finalChunk = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalChunk.isEmpty {
            chunks.append(finalChunk)
        }

        return chunks
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

    func importYouTubeTranscript(from urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            youtubeImportError = "Paste a YouTube link to continue."
            return
        }

        isImportingYouTube = true
        youtubeImportError = nil

        do {
            let result = try await youtubeTranscriptImportService.importTranscript(from: trimmed)
            let pages = makeTranscriptPages(from: result.transcript)
            let source = Source(name: result.videoTitle, sourceType: .youtube, pages: pages)
            addSource(source)
            print("📺 [ProjectDetail] YouTube transcript imported: \(result.videoTitle) (\(result.videoID)) — \(pages.count) pages")
        } catch {
            youtubeImportError = error.localizedDescription
            print("❌ [ProjectDetail] YouTube transcript import failed: \(error)")
        }

        isImportingYouTube = false
    }

    // MARK: - Study Actions

    func generateQuiz() {
        let pages = allCompletedPages
        let strategy = usesPDFQuizLengthHeuristic ? "page_based" : "word_based"
        let questionCount = targetQuizQuestionCount
        print("🧪 [ProjectDetail] generateQuiz — allPages: \(book.allPages.count), completed: \(pages.count), legacy pages: \(book.pages.count), sources: \(book.sources.count), strategy: \(strategy), words: \(sourceWordCount), questions: \(questionCount)")
        guard !pages.isEmpty else {
            print("🧪 [ProjectDetail] No completed pages — skipping quiz")
            return
        }
        isGeneratingQuiz = true
        quizQuestions = []

        Task {
            do {
                let questions = try await memorizeService.generateQuiz(from: pages, questionCount: questionCount)
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
        let pageCount = allCompletedPages.count
        let targetMinutes = max(4, pageCount * 2)
        let modeLabel = mode == .interactive ? "interactive" : "play"
        print("🎙️ [MemorizePodcast] Opening podcast mode=\(modeLabel) target length=\(targetMinutes) min from \(pageCount) completed pages")
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

    // MARK: - Notes

    func generateNoteDraft(after mode: GeneratedNoteKind) {
        guard hasContent else { return }
        guard !isGeneratingNoteDraft else { return }
        guard generatedNoteDraft == nil else { return }

        let pages = allCompletedPages
        let title = book.title
        let sessionTranscript = noteSessionTranscript(for: mode)
        isGeneratingNoteDraft = true
        noteGenerationError = nil

        Task {
            do {
                let note = try await memorizeService.generateStudyNote(
                    from: pages,
                    bookTitle: title,
                    mode: mode,
                    sessionTranscript: sessionTranscript
                )
                generatedNoteDraft = note
            } catch {
                noteGenerationError = error.localizedDescription
                print("❌ [ProjectDetail] Note generation failed: \(error)")
            }
            isGeneratingNoteDraft = false
        }
    }

    func saveGeneratedNote(_ note: GeneratedNote) {
        book.notes.insert(note, at: 0)
        book.updatedAt = Date()

        if storage.bookExists(book.id) {
            storage.updateBook(book)
        } else {
            storage.saveBook(book)
        }
        hasPersistedBook = true

        generatedNoteDraft = nil
        noteGenerationError = nil
    }

    func deleteNote(id: UUID) {
        book.notes.removeAll { $0.id == id }
        book.updatedAt = Date()
        storage.updateBook(book)
    }

    func captureSessionMessages(_ messages: [MemorizeInteractMessage], for mode: GeneratedNoteKind) {
        let transcript = formattedTranscript(from: messages)
        guard !transcript.isEmpty else { return }
        pendingSessionTranscripts[mode] = transcript
    }

    func clearSessionCapture(for mode: GeneratedNoteKind) {
        pendingSessionTranscripts[mode] = nil
    }

    func discardGeneratedNote() {
        generatedNoteDraft = nil
        noteGenerationError = nil
    }

    private func noteSessionTranscript(for mode: GeneratedNoteKind) -> String? {
        var transcript = pendingSessionTranscripts[mode]

        if mode == .quiz {
            let quizContext = formattedQuizSession()
            if !quizContext.isEmpty {
                transcript = [transcript, quizContext]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n\n")
            }
        }

        return transcript?.isEmpty == false ? transcript : nil
    }

    private func formattedTranscript(from messages: [MemorizeInteractMessage]) -> String {
        let lines = messages
            .map { message -> String in
                let text = message.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                guard !text.isEmpty else { return "" }
                return "\(message.isUser ? "User said" : "AI feedback"): \(text)"
            }
            .filter { !$0.isEmpty }

        let clipped = lines.suffix(16).joined(separator: "\n")
        guard clipped.count > 5000 else { return clipped }
        return String(clipped.suffix(5000))
    }

    private func formattedQuizSession() -> String {
        let lines = quizQuestions.enumerated().compactMap { index, question -> String? in
            guard let selectedIndex = question.selectedIndex,
                  selectedIndex >= 0,
                  selectedIndex < question.options.count else { return nil }

            let userAnswer = question.options[selectedIndex]
            let correctAnswer = question.options[question.correctIndex]
            let result = selectedIndex == question.correctIndex ? "correct" : "incorrect"
            let feedback = question.explanation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return """
            Quiz item \(index + 1):
            User said/selected: \(userAnswer)
            AI feedback: The answer was \(result). Correct answer: \(correctAnswer). \(feedback)
            """
        }

        return lines.joined(separator: "\n\n")
    }

    func reload() {
        let books = storage.loadBooks()
        guard let updated = books.first(where: { $0.id == book.id }) else {
            guard hasPersistedBook else {
                isDeleted = false
                print("📚 [ProjectDetail] Reload skipped — new unsaved project: \(book.id)")
                return
            }
            isDeleted = true
            print("📚 [ProjectDetail] Reload skipped — book no longer exists: \(book.id)")
            return
        }

        isDeleted = false
        hasPersistedBook = true
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
        print("📚 [ProjectDetail] Reloaded — pages: \(book.pages.count), sources: \(book.sources.count), allPages: \(book.allPages.count)")
    }
}
