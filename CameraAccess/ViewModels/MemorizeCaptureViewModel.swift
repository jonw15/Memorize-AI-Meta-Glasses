/*
 * Memorize Capture ViewModel
 * Manages page capture flow: countdown, photo capture, OCR processing
 */

import Foundation
import UIKit
import AVFoundation
import AudioToolbox
import Combine
import Photos

@MainActor
class MemorizeCaptureViewModel: ObservableObject {
    @Published var pages: [PageCapture] = []
    @Published var isCountingDown: Bool = false
    @Published var countdownValue: Int = 3
    @Published var currentBook: Book?
    @Published var isProcessing: Bool = false
    @Published var lastCapturedImage: UIImage?
    @Published var quizQuestions: [QuizQuestion] = []
    @Published var isGeneratingQuiz: Bool = false
    @Published var showQuiz: Bool = false

    private let storage = MemorizeStorage.shared
    private let memorizeService = MemorizeService()
    private let synthesizer = AVSpeechSynthesizer()
    private var countdownTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // Reference to stream view model for photo capture
    weak var streamViewModel: StreamSessionViewModel?

    // MARK: - Initialize with existing book

    func loadBook(_ book: Book?) {
        if var book = book {
            // Load thumbnail files into pages
            storage.loadThumbnails(for: &book)
            currentBook = book
            pages = book.pages
        } else {
            // New book
            currentBook = Book()
        }
    }

    // MARK: - Countdown & Capture

    func startCountdown() {
        guard !isCountingDown, !isProcessing, !isGeneratingQuiz else { return }

        isCountingDown = true
        countdownValue = 3

        countdownTask = Task { @MainActor in
            for i in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled else { break }
                countdownValue = i
                speakNumber(i)
                try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
            }

            guard !Task.isCancelled else {
                isCountingDown = false
                return
            }

            isCountingDown = false
            AudioServicesPlaySystemSound(1108)
            captureAndProcess()
        }
    }

    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        isCountingDown = false
        countdownValue = 3
    }

    // MARK: - Photo Capture & OCR

    private func captureAndProcess() {
        guard let streamVM = streamViewModel else {
            print("❌ [Memorize] No stream view model")
            return
        }

        isProcessing = true

        // Create a new page entry
        let pageNumber = (pages.map(\.pageNumber).max() ?? 0) + 1
        var page = PageCapture(pageNumber: pageNumber, status: .capturing)
        pages.append(page)
        saveProgress()

        // Capture photo from glasses
        streamVM.capturePhoto()

        // Listen for the captured photo
        streamVM.$capturedPhoto
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                guard let self else { return }
                Task { @MainActor in
                    await self.processCapture(image: image, pageIndex: self.pages.count - 1)
                    // Clear the photo preview so it doesn't show the default preview
                    streamVM.showPhotoPreview = false
                    streamVM.capturedPhoto = nil
                }
            }
            .store(in: &cancellables)
    }

    private func processCapture(image: UIImage, pageIndex: Int) async {
        guard pageIndex < pages.count else { return }

        // Show capture flash overlay
        lastCapturedImage = image
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(1.5 * Double(NSEC_PER_SEC)))
            lastCapturedImage = nil
        }

        // Save full image to photo library
        saveImageToPhotoLibrary(image)

        // Save thumbnail to file and keep in memory
        let thumbnailData = image.jpegData(compressionQuality: 0.3)
        pages[pageIndex].thumbnailData = thumbnailData
        if let thumbnailData {
            storage.saveThumbnail(thumbnailData, for: pages[pageIndex].id)
        }
        pages[pageIndex].status = .processing
        saveProgress()

        do {
            // OCR - extract text
            let text = try await memorizeService.extractText(from: image)
            pages[pageIndex].extractedText = text
            pages[pageIndex].status = .completed

            // On first page, detect book info
            if pageIndex == 0 && (currentBook?.title.isEmpty ?? true) {
                let bookInfo = try await memorizeService.detectBookInfo(from: text)
                currentBook?.title = bookInfo.title
                currentBook?.author = bookInfo.author
            }

            saveProgress()
            print("✅ [Memorize] Page \(pageIndex + 1) processed successfully")
        } catch {
            let failedPageId = pages[pageIndex].id
            pages.remove(at: pageIndex)
            storage.deleteThumbnail(for: failedPageId)
            saveProgress()
            print("❌ [Memorize] OCR failed: \(error.localizedDescription)")
        }

        isProcessing = false
    }

    // MARK: - Save Progress

    private func saveProgress() {
        guard var book = currentBook else { return }
        book.pages = pages
        book.updatedAt = Date()
        currentBook = book

        // Check if book already exists in storage
        let existingBooks = storage.loadBooks()
        if existingBooks.contains(where: { $0.id == book.id }) {
            storage.updateBook(book)
        } else {
            let hasTitle = !book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasAuthor = !book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasPages = !book.pages.isEmpty
            guard hasTitle || hasAuthor || hasPages else {
                return
            }
            storage.saveBook(book)
        }
    }

    // MARK: - Quiz Generation

    func generateQuiz() {
        guard !isGeneratingQuiz else { return }
        let completedPages = pages.filter { $0.status == .completed }
        guard !completedPages.isEmpty else { return }

        isGeneratingQuiz = true
        Task {
            do {
                let questions = try await memorizeService.generateQuiz(from: pages)
                self.quizQuestions = questions
                if !questions.isEmpty {
                    self.showQuiz = true
                }
            } catch {
                print("❌ [Memorize] Quiz generation failed: \(error.localizedDescription)")
            }
            self.isGeneratingQuiz = false
        }
    }

    // MARK: - Done Reading

    func finishSession() {
        saveProgress()
        cancelCountdown()
    }

    // MARK: - Delete Page

    func deletePage(_ page: PageCapture) {
        guard !isProcessing else { return }
        guard page.status != .processing && page.status != .capturing else { return }

        pages.removeAll { $0.id == page.id }
        storage.deleteThumbnail(for: page.id)
        saveProgress()
    }

    // MARK: - Save to Photo Library

    private func saveImageToPhotoLibrary(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            if success {
                print("📸 [Memorize] Image saved to photo library")
            } else if let error {
                print("❌ [Memorize] Failed to save image: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Audio Feedback

    private func speakNumber(_ number: Int) {
        let utterance = AVSpeechUtterance(string: "\(number)")
        utterance.rate = AVSpeechUtteranceMaximumSpeechRate
        utterance.volume = 0.5
        synthesizer.speak(utterance)
    }

    deinit {
        countdownTask?.cancel()
    }
}
