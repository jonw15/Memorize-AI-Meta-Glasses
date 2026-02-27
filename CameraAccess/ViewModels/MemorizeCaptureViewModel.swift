/*
 * Memorize Capture ViewModel
 * Manages page capture flow: countdown, photo capture, OCR processing
 */

import Foundation
import UIKit
import AVFoundation
import Combine

@MainActor
class MemorizeCaptureViewModel: ObservableObject {
    @Published var pages: [PageCapture] = []
    @Published var isCountingDown: Bool = false
    @Published var countdownValue: Int = 3
    @Published var currentBook: Book?
    @Published var isProcessing: Bool = false

    private let storage = MemorizeStorage.shared
    private let memorizeService = MemorizeService()
    private let synthesizer = AVSpeechSynthesizer()
    private var countdownTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // Reference to stream view model for photo capture
    weak var streamViewModel: StreamSessionViewModel?

    // MARK: - Initialize with existing book

    func loadBook(_ book: Book?) {
        if let book = book {
            currentBook = book
            pages = book.pages
        } else {
            // New book
            currentBook = Book()
        }
    }

    // MARK: - Countdown & Capture

    func startCountdown() {
        guard !isCountingDown, !isProcessing else { return }

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
        let pageNumber = pages.count + 1
        var page = PageCapture(pageNumber: pageNumber, status: .capturing)
        pages.append(page)

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

        // Save thumbnail
        let thumbnailData = image.jpegData(compressionQuality: 0.3)
        pages[pageIndex].thumbnailData = thumbnailData
        pages[pageIndex].status = .processing

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
            pages[pageIndex].status = .failed
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
            storage.saveBook(book)
        }
    }

    // MARK: - Done Reading

    func finishSession() {
        saveProgress()
        cancelCountdown()
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
