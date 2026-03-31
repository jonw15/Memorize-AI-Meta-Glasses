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
import AVKit

enum PodcastMode {
    case play        // Scrub bar, mic muted, no interaction
    case interactive // No scrub bar, mic active, user can interrupt
}

enum CaptureDevice: String, CaseIterable {
    case glasses = "Ray-Ban Meta"
    case phone = "iPhone Camera"

    var iconName: String {
        switch self {
        case .glasses: return "eyeglasses"
        case .phone: return "iphone"
        }
    }
}

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
    @Published var isGeneratingExplanation: Bool = false
    @Published var showExplain: Bool = false
    @Published var explanationPersona: MemorizeExplainPersona = .highSchoolStudent
    @Published var explanationText: String = ""
    @Published var explanationErrorMessage: String?
    @Published var podcastErrorMessage: String?
    @Published var showPodcastPlayer: Bool = false
    @Published var podcastMode: PodcastMode = .interactive
    @Published var showPodcastModePicker: Bool = false
    @Published var captureDevice: CaptureDevice = .glasses
    @Published var showDevicePicker: Bool = false
    @Published var showPhoneCamera: Bool = false

    private let storage = MemorizeStorage.shared
    private let memorizeService = MemorizeService()
    private let synthesizer = AVSpeechSynthesizer()
    private var countdownTask: Task<Void, Never>?
    private var processingProgressTasks: [UUID: Task<Void, Never>] = [:]
    private var pendingPhotoPageIDs: [UUID] = []
    private var queuedCaptures: [(pageId: UUID, image: UIImage)] = []
    private var isProcessingQueueActive: Bool = false
    private var currentProcessingTask: Task<Void, Never>?
    private var cropReprocessTasks: [UUID: Task<Void, Never>] = [:]
    private var hasPhotoObserver: Bool = false
    private var cancellables = Set<AnyCancellable>()

    // Reference to stream view model for glasses photo capture
    weak var streamViewModel: StreamSessionViewModel?

    // Phone camera capture session
    let phoneCaptureSession = AVCaptureSession()
    private let phonePhotoOutput = AVCapturePhotoOutput()
    private var phoneCaptureDelegate: PhoneCaptureDelegate?

    // MARK: - Initialize with existing book

    func loadBook(_ book: Book?) {
        if var book = book {
            // Load thumbnail files into pages
            storage.loadThumbnails(for: &book)
            let didRemoveStalePages = removeStaleInProgressPages(from: &book)
            currentBook = book
            pages = book.pages
            if didRemoveStalePages {
                storage.updateBook(book)
            }
        } else {
            // New book
            currentBook = Book()
        }
    }

    // MARK: - Countdown & Capture

    func startCountdown() {
        guard !isCountingDown, !isGeneratingQuiz else { return }

        isCountingDown = true
        countdownValue = 3

        countdownTask = Task { @MainActor in
            configureCountdownSpeechAudioSession()
            if synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
            }
            // Give the audio route a brief moment to settle so the first number is audible.
            try? await Task.sleep(nanoseconds: 150_000_000)

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
            captureAndQueue()
        }
    }

    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        isCountingDown = false
        countdownValue = 3
    }

    // MARK: - Photo Capture & OCR

    private func captureAndQueue() {
        if captureDevice == .phone {
            captureFromPhone()
            return
        }

        guard let streamVM = streamViewModel else {
            print("❌ [Memorize] No stream view model")
            return
        }

        ensurePhotoObserver()

        // Create a new page entry
        let pageNumber = (pages.map(\.pageNumber).max() ?? 0) + 1
        let page = PageCapture(pageNumber: pageNumber, status: .capturing)
        pages.append(page)
        pendingPhotoPageIDs.append(page.id)
        updateProgress(for: page.id, to: 0.08)
        saveProgress()

        // Capture photo from glasses
        streamVM.capturePhoto()
    }

    // MARK: - Phone Camera

    func setupPhoneCamera() {
        guard phoneCaptureSession.inputs.isEmpty else { return }
        phoneCaptureSession.beginConfiguration()
        phoneCaptureSession.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("❌ [Memorize] Failed to access phone camera")
            phoneCaptureSession.commitConfiguration()
            return
        }

        if phoneCaptureSession.canAddInput(input) {
            phoneCaptureSession.addInput(input)
        }
        if phoneCaptureSession.canAddOutput(phonePhotoOutput) {
            phoneCaptureSession.addOutput(phonePhotoOutput)
        }

        phoneCaptureSession.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.phoneCaptureSession.startRunning()
            print("📱 [Memorize] Phone camera session started")
        }
    }

    func stopPhoneCamera() {
        guard phoneCaptureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.phoneCaptureSession.stopRunning()
            print("📱 [Memorize] Phone camera session stopped")
        }
    }

    private func captureFromPhone() {
        let pageNumber = (pages.map(\.pageNumber).max() ?? 0) + 1
        let page = PageCapture(pageNumber: pageNumber, status: .capturing)
        pages.append(page)
        updateProgress(for: page.id, to: 0.08)
        saveProgress()

        let delegate = PhoneCaptureDelegate { [weak self] image in
            Task { @MainActor in
                guard let self, let image else {
                    print("❌ [Memorize] Phone capture failed")
                    return
                }
                self.queuedCaptures.append((pageId: page.id, image: image))
                self.processNextQueuedCapture()
            }
        }
        phoneCaptureDelegate = delegate

        let settings = AVCapturePhotoSettings()
        phonePhotoOutput.capturePhoto(with: settings, delegate: delegate)
        print("📱 [Memorize] Phone photo capture triggered")
    }

    /// Handle a photo captured from the phone's camera (used by fullscreen picker fallback)
    func handlePhoneCameraCapture(_ image: UIImage) {
        let pageNumber = (pages.map(\.pageNumber).max() ?? 0) + 1
        let page = PageCapture(pageNumber: pageNumber, status: .capturing)
        pages.append(page)
        updateProgress(for: page.id, to: 0.08)
        saveProgress()

        queuedCaptures.append((pageId: page.id, image: image))
        processNextQueuedCapture()
    }

    private func ensurePhotoObserver() {
        guard !hasPhotoObserver else { return }
        guard let streamVM = streamViewModel else { return }

        hasPhotoObserver = true
        streamVM.$capturedPhoto
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                guard let self else { return }
                self.handleCapturedPhoto(image)
                streamVM.showPhotoPreview = false
                streamVM.capturedPhoto = nil
            }
            .store(in: &cancellables)
    }

    private func handleCapturedPhoto(_ image: UIImage) {
        guard !pendingPhotoPageIDs.isEmpty else { return }
        let pageId = pendingPhotoPageIDs.removeFirst()
        guard pages.contains(where: { $0.id == pageId }) else { return }
        queuedCaptures.append((pageId: pageId, image: image))
        processNextQueuedCapture()
    }

    private func processNextQueuedCapture() {
        guard !isProcessingQueueActive else { return }
        guard !queuedCaptures.isEmpty else {
            isProcessing = false
            return
        }

        isProcessingQueueActive = true
        isProcessing = true

        let next = queuedCaptures.removeFirst()
        currentProcessingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await processCapture(image: next.image, pageId: next.pageId)
            isProcessingQueueActive = false
            currentProcessingTask = nil
            processNextQueuedCapture()
        }
    }

    private func processCapture(image: UIImage, pageId: UUID) async {
        guard let pageIndex = pages.firstIndex(where: { $0.id == pageId }) else { return }
        updateProgress(for: pageId, to: 0.18)

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
        updateProgress(for: pageId, to: 0.35)
        startTimedProgress(for: pageId)
        saveProgress()

        do {
            // OCR - extract text
            let text = try await memorizeService.extractText(from: image)
            guard let completedIndex = pages.firstIndex(where: { $0.id == pageId }) else { return }
            pages[completedIndex].extractedText = text
            updateProgress(for: pageId, to: 0.85)
            pages[completedIndex].status = .completed

            // Auto-detect metadata if title is still empty
            if currentBook?.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                let bookInfo = try await memorizeService.detectBookInfo(from: text)
                currentBook?.title = bookInfo.title
                currentBook?.author = bookInfo.author
            }

            updateProgress(for: pageId, to: 1.0)
            if let finishedIndex = pages.firstIndex(where: { $0.id == pageId }) {
                pages[finishedIndex].processingProgress = nil
            }
            stopTimedProgress(for: pageId)
            saveProgress()
            print("✅ [Memorize] Page \(pageIndex + 1) processed successfully")
        } catch {
            stopTimedProgress(for: pageId)
            if let failedIndex = pages.firstIndex(where: { $0.id == pageId }) {
                let failedPageId = pages[failedIndex].id
                pages.remove(at: failedIndex)
                storage.deleteThumbnail(for: failedPageId)
                saveProgress()
            }
            print("❌ [Memorize] OCR failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Save Progress

    private func saveProgress() {
        guard var book = currentBook else { return }
        book.pages = pages
        book.updatedAt = Date()
        currentBook = book

        // Check if book already exists in storage (top-level or inside a parent's sections)
        if storage.bookExists(book.id) {
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

    func generateExplanation(as persona: MemorizeExplainPersona) {
        guard !isGeneratingExplanation else { return }
        let completedPages = pages.filter { $0.status == .completed }
        guard !completedPages.isEmpty else {
            explanationErrorMessage = "memorize.explain_no_pages_error".localized
            return
        }

        explanationPersona = persona
        explanationText = ""
        explanationErrorMessage = nil
        isGeneratingExplanation = true
        showExplain = true

        Task {
            do {
                let explanation = try await memorizeService.explainSection(from: pages, as: persona)
                self.explanationText = explanation
                if explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.explanationErrorMessage = "memorize.explain_empty_error".localized
                }
            } catch {
                self.explanationErrorMessage = error.localizedDescription
            }
            self.isGeneratingExplanation = false
        }
    }

    // MARK: - Podcast

    func startPodcast() {
        let completedPages = pages.filter { $0.status == .completed }
        guard !completedPages.isEmpty else {
            podcastErrorMessage = "memorize.explain_no_pages_error".localized
            return
        }
        podcastErrorMessage = nil
        showPodcastModePicker = true
    }

    func startPodcastWithMode(_ mode: PodcastMode) {
        podcastMode = mode
        showPodcastModePicker = false
        showPodcastPlayer = true
    }

    // MARK: - Done Reading

    func finishSession() {
        cancelPendingAndInFlightProcessing()
        saveProgress()
        cancelCountdown()
    }

    // MARK: - Delete Page

    func deletePage(_ page: PageCapture) {
        guard page.status != .processing && page.status != .capturing else { return }

        cropReprocessTasks[page.id]?.cancel()
        cropReprocessTasks[page.id] = nil
        pendingPhotoPageIDs.removeAll { $0 == page.id }
        queuedCaptures.removeAll { $0.pageId == page.id }
        stopTimedProgress(for: page.id)
        pages.removeAll { $0.id == page.id }
        storage.deleteThumbnail(for: page.id)
        saveProgress()
    }

    func startReprocessCroppedPage(pageId: UUID, image: UIImage) {
        cropReprocessTasks[pageId]?.cancel()
        cropReprocessTasks[pageId] = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.reprocessCroppedPage(pageId: pageId, image: image)
            cropReprocessTasks[pageId] = nil
        }
    }

    private func reprocessCroppedPage(pageId: UUID, image: UIImage) async {
        guard let pageIndex = pages.firstIndex(where: { $0.id == pageId }) else { return }

        let previousText = pages[pageIndex].extractedText
        let thumbnailData = image.jpegData(compressionQuality: 0.3)
        pages[pageIndex].thumbnailData = thumbnailData
        if let thumbnailData {
            storage.saveThumbnail(thumbnailData, for: pageId)
        }

        pages[pageIndex].status = .processing
        pages[pageIndex].processingProgress = 0.2
        pages[pageIndex].extractedText = ""
        startTimedProgress(for: pageId)
        saveProgress()

        do {
            let text = try await extractTextWithTimeout(from: image, timeoutSeconds: 45)
            guard !Task.isCancelled else { return }
            guard let finishedIndex = pages.firstIndex(where: { $0.id == pageId }) else { return }
            pages[finishedIndex].extractedText = text
            pages[finishedIndex].status = .completed
            pages[finishedIndex].processingProgress = nil
            stopTimedProgress(for: pageId)
            saveProgress()
        } catch {
            guard !Task.isCancelled else { return }
            // Retry with a larger, enhanced image. Small crop regions can cause OCR to return empty text.
            do {
                let enhanced = enhanceCroppedImageForOCR(image)
                let retryText = try await extractTextWithTimeout(from: enhanced, timeoutSeconds: 45)
                guard !Task.isCancelled else { return }
                guard let retryIndex = pages.firstIndex(where: { $0.id == pageId }) else { return }
                pages[retryIndex].extractedText = retryText
                pages[retryIndex].status = .completed
                pages[retryIndex].processingProgress = nil
                stopTimedProgress(for: pageId)
                saveProgress()
                print("✅ [Memorize] Crop reprocess succeeded after enhancement")
                return
            } catch {
                stopTimedProgress(for: pageId)
                if let failedIndex = pages.firstIndex(where: { $0.id == pageId }) {
                    // Preserve prior OCR so quiz flow remains usable even when cropped OCR is unreadable.
                    pages[failedIndex].extractedText = previousText
                    pages[failedIndex].status = .completed
                    pages[failedIndex].processingProgress = nil
                    saveProgress()
                }
                print("❌ [Memorize] Crop reprocess failed: \(error.localizedDescription)")
            }
        }
    }

    private func extractTextWithTimeout(from image: UIImage, timeoutSeconds: Double) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { [memorizeService] in
                try await memorizeService.extractText(from: image)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw NSError(
                    domain: "MemorizeReprocess",
                    code: 408,
                    userInfo: [NSLocalizedDescriptionKey: "OCR timed out"]
                )
            }

            guard let first = try await group.next() else {
                throw NSError(
                    domain: "MemorizeReprocess",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "OCR did not return a result"]
                )
            }
            let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw NSError(
                    domain: "MemorizeReprocess",
                    code: 422,
                    userInfo: [NSLocalizedDescriptionKey: "OCR returned empty text"]
                )
            }
            group.cancelAll()
            return trimmed
        }
    }

    private func enhanceCroppedImageForOCR(_ image: UIImage) -> UIImage {
        let targetWidth = max(image.size.width, 1400)
        let scaleFactor = targetWidth / max(image.size.width, 1)
        let targetSize = CGSize(
            width: image.size.width * scaleFactor,
            height: image.size.height * scaleFactor
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func removeStaleInProgressPages(from book: inout Book) -> Bool {
        let stalePages = book.pages.filter { $0.status == .capturing || $0.status == .processing }
        guard !stalePages.isEmpty else { return false }

        for page in stalePages {
            storage.deleteThumbnail(for: page.id)
        }
        book.pages.removeAll { $0.status == .capturing || $0.status == .processing }
        book.updatedAt = Date()
        return true
    }

    private func cancelPendingAndInFlightProcessing() {
        currentProcessingTask?.cancel()
        currentProcessingTask = nil
        isProcessingQueueActive = false

        for task in processingProgressTasks.values {
            task.cancel()
        }
        processingProgressTasks.removeAll()

        let pageIDsToDiscard = Set(
            pages
                .filter { $0.status == .capturing || $0.status == .processing }
                .map(\.id)
        )

        pendingPhotoPageIDs.removeAll()
        queuedCaptures.removeAll()
        for (pageID, task) in cropReprocessTasks {
            task.cancel()
            stopTimedProgress(for: pageID)
        }
        cropReprocessTasks.removeAll()

        for pageID in pageIDsToDiscard {
            storage.deleteThumbnail(for: pageID)
        }
        pages.removeAll { pageIDsToDiscard.contains($0.id) }

        isProcessing = false
        lastCapturedImage = nil
    }

    private func updateProgress(for pageId: UUID, to newValue: Double) {
        guard let index = pages.firstIndex(where: { $0.id == pageId }) else { return }
        let clamped = min(max(newValue, 0), 1)
        pages[index].processingProgress = max(pages[index].processingProgress ?? 0, clamped)
    }

    private func startTimedProgress(for pageId: UUID) {
        stopTimedProgress(for: pageId)
        processingProgressTasks[pageId] = Task { @MainActor [weak self] in
            guard let self else { return }
            let startTime = Date()

            while !Task.isCancelled {
                guard let index = pages.firstIndex(where: { $0.id == pageId }) else { break }
                guard pages[index].status == .processing else { break }

                let elapsed = Date().timeIntervalSince(startTime)
                // Increase from 35% to 80% over roughly 60 seconds based on real elapsed processing time.
                let timedProgress = 0.35 + min(elapsed / 60.0, 1.0) * 0.45
                updateProgress(for: pageId, to: timedProgress)
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func stopTimedProgress(for pageId: UUID) {
        processingProgressTasks[pageId]?.cancel()
        processingProgressTasks[pageId] = nil
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
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-US")
        synthesizer.speak(utterance)
    }

    private func configureCountdownSpeechAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [Memorize] Failed to configure speech audio session: \(error.localizedDescription)")
        }
    }

    deinit {
        countdownTask?.cancel()
        currentProcessingTask?.cancel()
        for task in cropReprocessTasks.values {
            task.cancel()
        }
        for task in processingProgressTasks.values {
            task.cancel()
        }
        cancellables.removeAll()
        let session = phoneCaptureSession
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning { session.stopRunning() }
        }
    }
}

// MARK: - Phone Camera Photo Delegate

class PhoneCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("❌ [PhoneCapture] Error: \(error)")
            completion(nil)
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(image)
    }
}
