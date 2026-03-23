/*
 * Memorize Capture View
 * Page capture screen with countdown, camera button, and session timeline
 */

import SwiftUI
import Speech
import AVFoundation

struct MemorizeCaptureView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    let book: Book?

    @StateObject private var viewModel = MemorizeCaptureViewModel()
    @StateObject private var captureVoiceController = CaptureVoiceCommandController()
    @StateObject private var introAnnouncer = CaptureIntroAnnouncer()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedThumbnail: TimelineThumbnailPreview?
    @State private var showPostCaptureActions = false
    @State private var didPlayIntroInstruction = false
    @State private var introSequenceTask: Task<Void, Never>?
    private let processingAccent = Color(red: 0.34, green: 0.86, blue: 1.0)

    struct TimelineThumbnailPreview: Identifiable {
        let id: UUID
        let pageId: UUID
        let image: UIImage
        let extractedText: String
        let pageNumber: Int
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection

                // Live camera preview
                cameraPreview
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.top, AppSpacing.md)

                Spacer()

                // Countdown overlay
                if viewModel.isCountingDown {
                    countdownOverlay
                }

                // Camera button
                captureButton

                // 3S Delay indicator
                delayIndicator
                    .padding(.top, AppSpacing.md)

                Text("Say \"take a photo\" or \"done reading\"")
                    .font(AppTypography.caption)
                    .foregroundColor(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.md)

                Spacer()

                // Session Timeline
                if !viewModel.pages.isEmpty {
                    timelineSection
                }

                // Done Reading button
                doneButton
                    .padding(.bottom, AppSpacing.lg)
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        introAnnouncer.stop()
                        captureVoiceController.stopListening()
                        viewModel.finishSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .fullScreenCover(item: $selectedThumbnail) { preview in
            TimelinePreviewEditorView(
                preview: preview,
                onClose: {
                    selectedThumbnail = nil
                },
                onApplyCrop: { pageId, croppedImage in
                    viewModel.startReprocessCroppedPage(pageId: pageId, image: croppedImage)
                    selectedThumbnail = nil
                }
            )
        }
        .fullScreenCover(isPresented: $showPostCaptureActions) {
            MemorizePostCaptureActionsView(
                viewModel: viewModel,
                bookTitle: displayBookTitle,
                sectionTitle: viewModel.currentBook?.chapter.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            ) {
                showPostCaptureActions = false
                dismiss()
            }
        }
        .onAppear {
            viewModel.streamViewModel = streamViewModel
            viewModel.loadBook(book)
            // Release any audio session held by previous voice controllers
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            introSequenceTask?.cancel()
            introSequenceTask = Task {
                // Brief delay to let previous audio sessions fully release
                try? await Task.sleep(nanoseconds: 500_000_000)
                await streamViewModel.handleStartStreaming()

                if !didPlayIntroInstruction {
                    didPlayIntroInstruction = true
                    captureVoiceController.suspendListening()

                    // Let startup/system announcement finish before intro guidance.
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard !Task.isCancelled else { return }

                    introAnnouncer.speak("Say take a photo to capture a page, or say done reading when you are finished") {
                        startCaptureVoiceCommands()
                    }
                } else {
                    startCaptureVoiceCommands()
                }
            }
        }
        .onChange(of: viewModel.isCountingDown) { isCountingDown in
            if isCountingDown {
                captureVoiceController.suspendListening()
            } else {
                if !showPostCaptureActions && selectedThumbnail == nil {
                    captureVoiceController.resumeListening()
                }
            }
        }
        .onChange(of: showPostCaptureActions) { isPresented in
            if isPresented {
                captureVoiceController.suspendListening()
            } else if !viewModel.isCountingDown && selectedThumbnail == nil {
                captureVoiceController.resumeListening()
            }
        }
        .onChange(of: selectedThumbnail?.id) { selectedID in
            if selectedID != nil {
                captureVoiceController.suspendListening()
            } else if !viewModel.isCountingDown && !showPostCaptureActions {
                captureVoiceController.resumeListening()
            }
        }
        .onDisappear {
            introSequenceTask?.cancel()
            introSequenceTask = nil
            introAnnouncer.stop()
            captureVoiceController.stopListening()
        }
    }

    private func startCaptureVoiceCommands() {
        Task {
            await captureVoiceController.requestPermissionsIfNeeded()
            captureVoiceController.startListening { command in
                switch command {
                case .takePhoto:
                    if !viewModel.isCountingDown {
                        captureVoiceController.suspendListening()
                        viewModel.startCountdown()
                    }
                case .doneReading:
                    guard isDoneReadingEnabled else {
                        // Pages still processing — ignore the voice command
                        return
                    }
                    introAnnouncer.stop()
                    captureVoiceController.stopListening()
                    viewModel.finishSession()
                    Task {
                        await streamViewModel.stopSession()
                    }
                    showPostCaptureActions = true
                }
            }
        }
    }

    // MARK: - Camera Preview

    private var cameraPreview: some View {
        ZStack {
            if let videoFrame = streamViewModel.currentVideoFrame {
                Image(uiImage: videoFrame)
                    .resizable()
                    .aspectRatio(videoFrame.size, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .tint(AppColors.memorizeAccent)
                    Text("memorize.connecting_camera".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .frame(minHeight: 200)
                .frame(maxWidth: .infinity)
            }

            // Captured photo flash overlay
            if let captured = viewModel.lastCapturedImage {
                Image(uiImage: captured)
                    .resizable()
                    .aspectRatio(captured.size, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.3))
        .cornerRadius(AppCornerRadius.md)
        .animation(.easeInOut(duration: 0.3), value: viewModel.lastCapturedImage != nil)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("memorize.ready_to_capture".localized)
                .font(AppTypography.title)
                .foregroundColor(.white)

            Text(displayBookTitle)
                .font(AppTypography.headline)
                .foregroundColor(AppColors.memorizeAccent)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, AppSpacing.md)

            Text("memorize.capture_subtitle".localized)
                .font(AppTypography.subheadline)
                .foregroundColor(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppSpacing.lg)
    }

    private var displayBookTitle: String {
        let title = viewModel.currentBook?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "memorize.unknown_book".localized : title
    }

    // MARK: - Countdown Overlay

    private var countdownOverlay: some View {
        Text("\(viewModel.countdownValue)")
            .font(.system(size: 72, weight: .bold, design: .rounded))
            .foregroundColor(AppColors.memorizeAccent)
            .transition(.scale.combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: viewModel.countdownValue)
    }

    // MARK: - Capture Button

    private var captureButton: some View {
        Button {
            if viewModel.isCountingDown {
                viewModel.cancelCountdown()
            } else {
                viewModel.startCountdown()
            }
        } label: {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(AppColors.memorizeAccent.opacity(0.3), lineWidth: 4)
                    .frame(width: 100, height: 100)

                // Inner filled circle
                Circle()
                    .fill(
                        viewModel.isCountingDown
                            ? Color.red.opacity(0.8)
                            : AppColors.memorizeAccent
                    )
                    .frame(width: 80, height: 80)

                // Icon
                Image(systemName: viewModel.isCountingDown ? "stop.fill" : "camera.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
        }
        .disabled(viewModel.isGeneratingQuiz)
        .opacity(viewModel.isGeneratingQuiz ? 0.5 : 1.0)
    }

    // MARK: - Delay Indicator

    private var delayIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 12))
            Text("memorize.delay_3s".localized)
                .font(AppTypography.caption)
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .foregroundColor(Color.white.opacity(0.4))
    }

    // MARK: - Session Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("memorize.session_timeline".localized)
                    .font(AppTypography.headline)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.pages) { page in
                        pageCard(page: page)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
        .padding(.bottom, AppSpacing.md)
    }

    private func pageCard(page: PageCapture) -> some View {
        ZStack {
            // Thumbnail background
            if let data = page.thumbnailData, let uiImage = UIImage(data: data) {
                Button {
                    selectedThumbnail = TimelineThumbnailPreview(
                        id: page.id,
                        pageId: page.id,
                        image: uiImage,
                        extractedText: page.extractedText,
                        pageNumber: page.pageNumber
                    )
                } label: {
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 90)
                            .clipped()

                        // Dark overlay for text readability
                        Color.black.opacity(0.4)
                    }
                }
                .buttonStyle(.plain)
            } else {
                AppColors.memorizeCard
            }

            VStack {
                HStack {
                    Spacer()

                    Button {
                        viewModel.deletePage(page)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.45))
                                .frame(width: 28, height: 28)

                            Image(systemName: "trash.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                        }
                        .frame(width: 40, height: 40) // Larger hit target
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDelete(page))
                    .opacity(canDelete(page) ? 1 : 0.35)
                }
                Spacer()
            }
            .padding(4)

            if page.status == .processing {
                VStack {
                    Spacer()
                    ProcessingBarIndicator(
                        accent: processingAccent,
                        progress: page.processingProgress ?? 0.35
                    )
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                }
            }

            // Labels overlay
            VStack(spacing: 4) {
                Spacer()

                Text("P\(page.pageNumber)")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                statusIcon(for: page.status)
            }
            .padding(.bottom, 6)
        }
        .frame(width: 70, height: 90)
        .cornerRadius(AppCornerRadius.sm)
    }

    private func canDelete(_ page: PageCapture) -> Bool {
        page.status != .processing && page.status != .capturing
    }

    @ViewBuilder
    private func statusIcon(for status: PageCaptureStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 14))
        case .processing:
            ProgressView()
                .tint(processingAccent)
                .scaleEffect(0.7)
        case .capturing:
            Image(systemName: "camera.fill")
                .foregroundColor(AppColors.memorizeAccent)
                .font(.system(size: 14))
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 14))
        }
    }

    // MARK: - Done Button

    private var isDoneReadingEnabled: Bool {
        guard !viewModel.pages.isEmpty else { return true }
        guard !viewModel.isProcessing else { return false }

        return viewModel.pages.allSatisfy { page in
            switch page.status {
            case .completed:
                return page.thumbnailData != nil
            case .capturing, .processing:
                return false
            case .failed:
                return true
            }
        }
    }

    private var doneButton: some View {
        Button {
            introAnnouncer.stop()
            captureVoiceController.stopListening()
            viewModel.finishSession()
            Task {
                await streamViewModel.stopSession()
            }
            showPostCaptureActions = true
        } label: {
            Text("memorize.done_reading".localized)
                .font(AppTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isDoneReadingEnabled ? Color.blue : Color.gray.opacity(0.5))
                .cornerRadius(AppCornerRadius.md)
        }
        .padding(.horizontal, AppSpacing.md)
        .disabled(!isDoneReadingEnabled)
    }
}

@MainActor
private final class CaptureVoiceCommandController: NSObject, ObservableObject {
    enum Command {
        case takePhoto
        case doneReading
    }

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onCommand: ((Command) -> Void)?
    private var lastTriggerAt: Date = .distantPast
    private var speechPermissionDenied = false
    private var micPermissionDenied = false
    private var shouldListen = false
    private var restartTask: Task<Void, Never>?

    func requestPermissionsIfNeeded() async {
        let speechAuthorized: Bool = await withCheckedContinuation { continuation in
            let status = SFSpeechRecognizer.authorizationStatus()
            if status == .authorized {
                continuation.resume(returning: true)
            } else {
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus == .authorized)
                }
            }
        }
        speechPermissionDenied = !speechAuthorized

        let micAuthorized: Bool = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        micPermissionDenied = !micAuthorized
    }

    func startListening(onCommand: @escaping (Command) -> Void) {
        self.onCommand = onCommand
        shouldListen = true
        beginListeningIfNeeded()
    }

    func suspendListening() {
        shouldListen = false
        stopListeningInternal()
    }

    func resumeListening() {
        shouldListen = true
        beginListeningIfNeeded()
    }

    func stopListening() {
        shouldListen = false
        stopListeningInternal()
    }

    private func beginListeningIfNeeded() {
        guard shouldListen else { return }
        guard !speechPermissionDenied, !micPermissionDenied else { return }
        guard recognitionTask == nil else { return }

        restartTask?.cancel()
        restartTask = nil
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            scheduleRestart()
            return
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let text = result?.bestTranscription.formattedString.lowercased(),
                   let command = parseCommand(from: text) {
                    let now = Date()
                    if now.timeIntervalSince(lastTriggerAt) > 1.5 {
                        lastTriggerAt = now
                        self.onCommand?(command)
                    }
                }

                if error != nil || (result?.isFinal ?? false) {
                    stopListeningInternal()
                    scheduleRestart()
                }
            }
        }
    }

    private func stopListeningInternal() {
        restartTask?.cancel()
        restartTask = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func scheduleRestart() {
        guard shouldListen else { return }
        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            self?.beginListeningIfNeeded()
        }
    }

    private func parseCommand(from text: String) -> Command? {
        let normalized = text.replacingOccurrences(of: "-", with: " ")
        if normalized.contains("take photo") ||
            normalized.contains("take a photo") ||
            normalized.contains("capture photo") ||
            normalized.contains("take picture") ||
            normalized.contains("capture page") {
            return .takePhoto
        }
        if normalized.contains("done reading") ||
            normalized.contains("finish reading") ||
            normalized.contains("i'm done") ||
            normalized.contains("im done") {
            return .doneReading
        }
        return nil
    }
}

@MainActor
private final class CaptureIntroAnnouncer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var onFinish: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {}

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-US")
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        onFinish = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Brief delay so the last word fully renders through the audio output
            try? await Task.sleep(nanoseconds: 600_000_000)
            let callback = onFinish
            onFinish = nil
            callback?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let callback = onFinish
            onFinish = nil
            callback?()
        }
    }
}

private struct TimelinePreviewEditorView: View {
    let preview: MemorizeCaptureView.TimelineThumbnailPreview
    let onClose: () -> Void
    let onApplyCrop: (UUID, UIImage) -> Void

    @State private var topInset: Double = 0
    @State private var bottomInset: Double = 0
    @State private var leftInset: Double = 0
    @State private var rightInset: Double = 0

    private let minSpan: Double = 0.25

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Color.black

                    GeometryReader { imageGeo in
                        let imageRect = fittedRect(in: imageGeo.size, imageSize: preview.image.size)
                        let cropRect = cropRect(in: imageRect)

                        ZStack {
                            Image(uiImage: preview.image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: imageGeo.size.width, height: imageGeo.size.height)

                            Path { path in
                                path.addRect(imageRect)
                                path.addRect(cropRect)
                            }
                            .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))

                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: cropRect.width, height: cropRect.height)
                                .position(x: cropRect.midX, y: cropRect.midY)
                        }
                    }
                    .padding(AppSpacing.md)

                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.top, AppSpacing.sm)
                            .padding(.trailing, AppSpacing.md)
                    }
                }
                .frame(height: geo.size.height * 0.50)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("P\(preview.pageNumber) • OCR")
                            .font(AppTypography.headline)
                            .foregroundColor(.white)

                        cropSlider(label: "Top", value: $topInset, maxAllowed: maxInset(top: true))
                        cropSlider(label: "Bottom", value: $bottomInset, maxAllowed: maxInset(bottom: true))
                        cropSlider(label: "Left", value: $leftInset, maxAllowed: maxInset(left: true))
                        cropSlider(label: "Right", value: $rightInset, maxAllowed: maxInset(right: true))

                        HStack(spacing: AppSpacing.sm) {
                            Button {
                                topInset = 0
                                bottomInset = 0
                                leftInset = 0
                                rightInset = 0
                            } label: {
                                Text("Reset")
                                    .font(AppTypography.body)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(AppCornerRadius.md)
                            }

                            Button {
                                if let cropped = cropImage(preview.image) {
                                    onApplyCrop(preview.pageId, cropped)
                                }
                            } label: {
                                Text("Apply Crop")
                                    .font(AppTypography.body)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppColors.memorizeAccent)
                                    .cornerRadius(AppCornerRadius.md)
                            }
                        }

                        Text(preview.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? "memorize.no_ocr_text".localized
                             : preview.extractedText)
                            .font(AppTypography.caption)
                            .foregroundColor(Color.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, AppSpacing.xs)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
                .frame(maxHeight: .infinity)
                .background(AppColors.memorizeBackground)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color.black)
    }

    private func cropSlider(label: String, value: Binding<Double>, maxAllowed: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(Color.white.opacity(0.7))
            Slider(value: value, in: 0...maxAllowed)
                .tint(AppColors.memorizeAccent)
        }
    }

    private func maxInset(top: Bool = false, bottom: Bool = false, left: Bool = false, right: Bool = false) -> Double {
        if top {
            return max(0, 1.0 - bottomInset - minSpan)
        }
        if bottom {
            return max(0, 1.0 - topInset - minSpan)
        }
        if left {
            return max(0, 1.0 - rightInset - minSpan)
        }
        if right {
            return max(0, 1.0 - leftInset - minSpan)
        }
        return 0.8
    }

    private func fittedRect(in container: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let x = (container.width - width) / 2
        let y = (container.height - height) / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func cropRect(in imageRect: CGRect) -> CGRect {
        let x = imageRect.minX + imageRect.width * leftInset
        let y = imageRect.minY + imageRect.height * topInset
        let width = imageRect.width * (1.0 - leftInset - rightInset)
        let height = imageRect.height * (1.0 - topInset - bottomInset)
        return CGRect(x: x, y: y, width: max(1, width), height: max(1, height))
    }

    private func cropImage(_ image: UIImage) -> UIImage? {
        let source = normalizedImageForCropping(image)
        let cropWidth = max(0.01, 1.0 - leftInset - rightInset)
        let cropHeight = max(0.01, 1.0 - topInset - bottomInset)
        let normalized = CGRect(
            x: leftInset,
            y: topInset,
            width: cropWidth,
            height: cropHeight
        )
        let cropRect = CGRect(
            x: source.size.width * normalized.origin.x,
            y: source.size.height * normalized.origin.y,
            width: source.size.width * normalized.size.width,
            height: source.size.height * normalized.size.height
        ).integral

        guard cropRect.width > 1, cropRect.height > 1 else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = source.scale
        let renderer = UIGraphicsImageRenderer(size: cropRect.size, format: format)
        return renderer.image { _ in
            source.draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
        }
    }

    private func normalizedImageForCropping(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

private struct MemorizePostCaptureActionsView: View {
    @ObservedObject var viewModel: MemorizeCaptureViewModel
    let bookTitle: String
    let sectionTitle: String
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showExplainPersonaSelector = false
    @State private var showVoiceSummary = false
    @State private var showInteract = false
    @State private var voiceMenuRestartTask: Task<Void, Never>?
    @StateObject private var voiceMenu = PostCaptureVoiceMenuController()

    private var completedPages: [PageCapture] {
        viewModel.pages.filter { $0.status == .completed }
    }

    private func startVoiceMenu() {
        guard !completedPages.isEmpty else { return }
        voiceMenu.askAndListen { command in
            switch command {
            case .interact:
                showInteract = true
            case .explain:
                showExplainPersonaSelector = true
            case .popQuiz:
                viewModel.generateQuiz()
            case .voiceSummary:
                showVoiceSummary = true
            case .podcast:
                viewModel.startPodcast()
            }
        }
    }

    private func restartVoiceMenuAfterDelay() {
        voiceMenuRestartTask?.cancel()
        voiceMenuRestartTask = Task {
            // Wait for Gemini audio session to release
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            // Force-reset audio session so SFSpeechRecognizer can claim it
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            startVoiceMenu()
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        Text(bookTitle)
                            .font(AppTypography.title2)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.lg)

                        if !sectionTitle.isEmpty {
                            Text(sectionTitle)
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.memorizeAccent)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, AppSpacing.md)
                        }

                        interactButton
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.md)

                        explainButton
                            .padding(.horizontal, AppSpacing.md)

                        podcastButton
                            .padding(.horizontal, AppSpacing.md)

                        Text("memorize.test_mode_prompt".localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.sm)

                        popQuizButton
                            .padding(.horizontal, AppSpacing.md)

                        voiceSummaryButton
                            .padding(.horizontal, AppSpacing.md)

                        if let podcastError = viewModel.podcastErrorMessage, !podcastError.isEmpty {
                            Text(podcastError)
                                .font(AppTypography.caption)
                                .foregroundColor(.red.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.bottom, AppSpacing.md)
                }

                Button {
                    dismiss()
                    onClose()
                } label: {
                    Text("memorize.done".localized)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(AppCornerRadius.md)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("memorize.done_reading".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $viewModel.showQuiz) {
            MemorizeQuizView(questions: $viewModel.quizQuestions)
        }
        .fullScreenCover(isPresented: $showVoiceSummary) {
            MemorizeVoiceSummaryView(
                pages: completedPages,
                bookTitle: bookTitle
            )
        }
        .fullScreenCover(isPresented: $showInteract) {
            MemorizeInteractView(
                pages: completedPages,
                bookTitle: bookTitle
            )
        }
        .fullScreenCover(isPresented: $viewModel.showExplain) {
            MemorizeExplainView(
                viewModel: viewModel,
                bookTitle: bookTitle,
                pages: viewModel.pages,
                onClose: {
                    viewModel.showExplain = false
                }
            )
        }
        .sheet(isPresented: $showExplainPersonaSelector) {
            ExplainPersonaPickerView { persona in
                showExplainPersonaSelector = false
                viewModel.generateExplanation(as: persona)
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $viewModel.showPodcastPlayer) {
            MemorizePodcastPlayerView(
                pages: completedPages,
                bookTitle: bookTitle,
                onClose: {
                    viewModel.showPodcastPlayer = false
                }
            )
        }
        .task {
            guard !completedPages.isEmpty else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            startVoiceMenu()
        }
        .onChange(of: showExplainPersonaSelector) { showing in
            if showing { voiceMenu.stop() }
            // Don't restart here — the summary view will open next.
            // Voice menu restarts when showExplain closes.
        }
        .onChange(of: showInteract) { showing in
            if showing { voiceMenu.stop() } else { restartVoiceMenuAfterDelay() }
        }
        .onChange(of: showVoiceSummary) { showing in
            if showing { voiceMenu.stop() } else { restartVoiceMenuAfterDelay() }
        }
        .onChange(of: viewModel.showExplain) { showing in
            if showing { voiceMenu.stop() } else { restartVoiceMenuAfterDelay() }
        }
        .onChange(of: viewModel.showQuiz) { showing in
            if showing { voiceMenu.stop() } else { restartVoiceMenuAfterDelay() }
        }
        .onChange(of: viewModel.showPodcastPlayer) { showing in
            if showing { voiceMenu.stop() } else { restartVoiceMenuAfterDelay() }
        }
        .onDisappear {
            voiceMenu.stop()
            voiceMenuRestartTask?.cancel()
        }
    }

    private var interactButton: some View {
        Button {
            showInteract = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("memorize.interact".localized)
                    .font(AppTypography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.72, blue: 0.52), Color(red: 0.10, green: 0.60, blue: 0.44)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppCornerRadius.md)
        }
        .disabled(viewModel.isGeneratingQuiz || completedPages.isEmpty)
        .opacity((viewModel.isGeneratingQuiz || completedPages.isEmpty) ? 0.5 : 1.0)
    }

    private var explainButton: some View {
        Button {
            showExplainPersonaSelector = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("memorize.explain".localized)
                    .font(AppTypography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.94, green: 0.55, blue: 0.24), Color(red: 0.87, green: 0.43, blue: 0.14)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppCornerRadius.md)
        }
        .disabled(viewModel.isGeneratingQuiz || completedPages.isEmpty || viewModel.isGeneratingExplanation)
        .opacity((viewModel.isGeneratingQuiz || completedPages.isEmpty || viewModel.isGeneratingExplanation) ? 0.5 : 1.0)
    }

    private var popQuizButton: some View {
        Button {
            viewModel.generateQuiz()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isGeneratingQuiz {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(viewModel.isGeneratingQuiz
                     ? "memorize.generating_quiz".localized
                     : "memorize.pop_quiz".localized)
                    .font(AppTypography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [AppColors.memorizeAccent, AppColors.memorizeAccent.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppCornerRadius.md)
        }
        .disabled(viewModel.isGeneratingQuiz || completedPages.isEmpty)
        .opacity((viewModel.isGeneratingQuiz || completedPages.isEmpty) ? 0.5 : 1.0)
    }

    private var voiceSummaryButton: some View {
        Button {
            showVoiceSummary = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("memorize.voice_summary".localized)
                    .font(AppTypography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.33, green: 0.56, blue: 1.0), Color(red: 0.26, green: 0.47, blue: 0.95)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppCornerRadius.md)
        }
        .disabled(viewModel.isGeneratingQuiz || completedPages.isEmpty)
        .opacity((viewModel.isGeneratingQuiz || completedPages.isEmpty) ? 0.5 : 1.0)
    }

    private var podcastButton: some View {
        Button {
            viewModel.startPodcast()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("memorize.podcast".localized)
                    .font(AppTypography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.64, green: 0.21, blue: 0.83), Color(red: 0.50, green: 0.14, blue: 0.70)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppCornerRadius.md)
        }
        .disabled(viewModel.isGeneratingQuiz || completedPages.isEmpty)
        .opacity((viewModel.isGeneratingQuiz || completedPages.isEmpty) ? 0.5 : 1.0)
    }
}

// MARK: - Podcast Player View (Gemini Live)

private struct MemorizePodcastPlayerView: View {
    let pages: [PageCapture]
    let bookTitle: String
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var geminiService: GeminiLiveService?
    @State private var isConnected = false
    @State private var isRecording = false
    @State private var isMuted = true
    @State private var currentTranscript = ""
    @State private var fullTranscript = ""
    @State private var errorMessage: String?
    @State private var isPlaying = false
    @State private var barHeights: [CGFloat] = [12, 12, 12, 12, 12]
    @State private var barTimer: Timer?

    private let podcastAccent = Color(red: 0.64, green: 0.21, blue: 0.83)
    private let barMinHeight: CGFloat = 8
    private let barMaxHeights: [CGFloat] = [36, 48, 40, 44, 32]

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.md) {
                Spacer()

                // Podcast artwork with soundwave bars
                ZStack {
                    Circle()
                        .fill(podcastAccent.opacity(0.1))
                        .frame(width: 200, height: 200)

                    Circle()
                        .fill(podcastAccent.opacity(0.18))
                        .frame(width: 160, height: 160)

                    Circle()
                        .fill(podcastAccent.opacity(0.25))
                        .frame(width: 120, height: 120)

                    // Soundwave bars
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(podcastAccent)
                                .frame(width: 6, height: barHeights[i])
                                .animation(.easeInOut(duration: 0.3), value: barHeights[i])
                        }
                    }
                }

                Text(bookTitle)
                    .font(AppTypography.title2)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, AppSpacing.lg)

                Text("memorize.podcast_header".localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.white.opacity(0.6))

                // Status indicator
                if !isConnected || !isPlaying {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("memorize.podcast_loading".localized)
                            .font(AppTypography.caption)
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    .padding(AppSpacing.md)
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }

                if isConnected {
                    microphoneButton
                }

                Spacer()

                Button {
                    disconnectAndDismiss()
                } label: {
                    Text("memorize.podcast_stop".localized)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(podcastAccent)
                        .cornerRadius(AppCornerRadius.md)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("memorize.podcast".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        disconnectAndDismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            try? await Task.sleep(nanoseconds: 500_000_000)
            setupAndConnect()
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                startBarTimer()
            } else {
                stopBarTimer()
            }
        }
        .onDisappear {
            stopBarTimer()
            geminiService?.disconnect()
            geminiService = nil
        }
    }

    private var microphoneButton: some View {
        Button {
            guard isConnected, let service = geminiService else { return }
            if isMuted {
                // Unmute — allow user to interrupt and speak
                service.interruptPlayback()
                service.isMicMuted = false
                isMuted = false
                print("🎙️ [Podcast] Mic unmuted")
            } else {
                // Mute — stop sending audio to Gemini
                service.isMicMuted = true
                isMuted = true
                print("🎙️ [Podcast] Mic muted")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text(isMuted ? "memorize.podcast_unmute".localized : "memorize.podcast_mute".localized)
                    .font(AppTypography.subheadline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isMuted ? Color.white.opacity(0.15) : podcastAccent.opacity(0.5))
            .cornerRadius(AppCornerRadius.md)
        }
    }

    private func startBarTimer() {
        barTimer?.invalidate()
        barTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            Task { @MainActor in
                for i in 0..<5 {
                    barHeights[i] = CGFloat.random(in: barMinHeight...barMaxHeights[i])
                }
            }
        }
    }

    private func stopBarTimer() {
        barTimer?.invalidate()
        barTimer = nil
        for i in 0..<5 { barHeights[i] = barMinHeight }
    }

    private func disconnectAndDismiss() {
        geminiService?.disconnect()
        geminiService = nil
        dismiss()
        onClose()
    }

    private func setupAndConnect() {
        let completedPages = pages.filter { $0.status == .completed }
        print("🎙️ [Podcast] Starting setup — \(completedPages.count) completed pages, \(pages.count) total pages")

        let combinedText = completedPages
            .enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element.extractedText)" }
            .joined(separator: "\n\n")

        print("🎙️ [Podcast] Combined text length: \(combinedText.count) chars")

        if combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("❌ [Podcast] No text content in completed pages!")
            errorMessage = "No text content available. Capture some pages first."
            return
        }

        let maxChars = 15000
        let truncatedText = combinedText.count > maxChars
            ? String(combinedText.prefix(maxChars)) + "\n[... text truncated ...]"
            : combinedText

        let systemPrompt = """
        You are the host of an engaging educational podcast called "Deep Dive". You have a warm, enthusiastic personality.

        Your task: Create a compelling podcast episode discussing the following reading material from "\(bookTitle)".

        ---
        \(truncatedText)
        ---

        Guidelines for your podcast:
        1. Start with a brief, energetic intro: "Welcome to Deep Dive! Today we're exploring..."
        2. Present the key ideas, themes, and insights from the text in a conversational, engaging way
        3. Use a dynamic speaking style — vary your tone, add emphasis, use rhetorical questions
        4. Break down complex ideas into digestible explanations with real-world analogies
        5. Highlight surprising or particularly interesting points from the text
        6. Add your own analysis and connections between ideas
        7. End with a brief wrap-up summarizing the main takeaways

        Speak naturally as if recording a real podcast episode. Be enthusiastic but not over the top.
        Keep the episode concise — aim for about 3-4 minutes of content.
        Do NOT mention that you are an AI. Speak as a human podcast host would.
        Begin the podcast immediately.
        """

        let apiKey = APIProviderManager.staticLiveAIAPIKey
        print("🎙️ [Podcast] API key present: \(!apiKey.isEmpty) (length: \(apiKey.count))")

        let service = GeminiLiveService(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            includeTools: false
        )

        service.onConnected = { [service] in
            Task { @MainActor in
                print("🎙️ [Podcast] Connected to Gemini Live!")
                isConnected = true
                // Start recording with mic muted — keeps audio session alive for playback
                service.isMicMuted = true
                service.startRecording()
                isRecording = true
                isMuted = true
                // Send a text prompt to trigger the AI to start the podcast
                try? await Task.sleep(nanoseconds: 300_000_000)
                service.sendTextInput("Begin the podcast now. Start with your intro and dive into the content.")
                print("🎙️ [Podcast] Sent trigger prompt to start podcast")
            }
        }

        service.onTranscriptDelta = { (delta: String) in
            Task { @MainActor in
                let cleaned = delta.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return }
                if !isPlaying { isPlaying = true }
                print("🎙️ [Podcast] Transcript delta: \(cleaned.prefix(80))...")
                if cleaned.hasPrefix(currentTranscript) && cleaned.count > currentTranscript.count {
                    currentTranscript = cleaned
                } else if currentTranscript.isEmpty || !cleaned.hasPrefix(currentTranscript) {
                    if currentTranscript.isEmpty {
                        currentTranscript = cleaned
                    } else {
                        let needsSpace = !currentTranscript.hasSuffix(" ") && !cleaned.hasPrefix(" ")
                        currentTranscript += (needsSpace ? " " : "") + cleaned
                    }
                }
            }
        }

        service.onTranscriptDone = { (fullText: String) in
            print("🎙️ [Podcast] Transcript done: \(fullText.prefix(80))...")
            Task { @MainActor in
                let trimmed = (fullText.isEmpty ? currentTranscript : fullText)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    if !fullTranscript.isEmpty {
                        fullTranscript += "\n\n"
                    }
                    fullTranscript += trimmed
                }
                currentTranscript = ""
            }
        }

        service.onAudioDone = {
            print("🎙️ [Podcast] Audio playback done")
        }

        service.onError = { (errorText: String) in
            print("❌ [Podcast] Error: \(errorText)")
            Task { @MainActor in
                errorMessage = errorText
            }
        }

        geminiService = service
        print("🎙️ [Podcast] Calling service.connect()...")
        service.connect()
    }
}

private struct ProcessingBarIndicator: View {
    let accent: Color
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 5)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.75), accent, accent.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * min(max(progress, 0), 1), height: 5)
            }
            .animation(.easeInOut(duration: 0.2), value: progress)
        }
        .frame(height: 5)
    }
}

@MainActor
private final class VoiceSummarySpeechRecognizer: NSObject, ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var speechPermissionDenied: Bool = false
    @Published var micPermissionDenied: Bool = false

    private var audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func requestPermissionsIfNeeded() async {
        let speechAuthorized: Bool = await withCheckedContinuation { continuation in
            let status = SFSpeechRecognizer.authorizationStatus()
            if status == .authorized {
                continuation.resume(returning: true)
            } else {
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus == .authorized)
                }
            }
        }
        speechPermissionDenied = !speechAuthorized

        let micAuthorized: Bool = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        micPermissionDenied = !micAuthorized
    }

    func startListening() throws {
        guard !speechPermissionDenied, !micPermissionDenied else { return }
        guard !isListening else { return }

        transcript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Fresh engine to avoid stale input node after Gemini session
        audioEngine = AVAudioEngine()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw NSError(
                domain: "VoiceSummarySpeechRecognizer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Speech recognizer is unavailable"]
            )
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw NSError(
                domain: "VoiceSummarySpeechRecognizer",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Microphone input format is unavailable"]
            )
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private struct MemorizeVoiceSummaryView: View {
    let pages: [PageCapture]
    let bookTitle: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechRecognizer = VoiceSummarySpeechRecognizer()
    @State private var isGrading: Bool = false
    @State private var gradeResult: MemorizeService.VoiceSummaryEvaluation?
    @State private var errorMessage: String?
    @State private var pulseAnimation: Bool = false

    private let memorizeService = MemorizeService()
    private let voiceAccent = Color(red: 0.33, green: 0.56, blue: 1.0)

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.md) {
                Text("memorize.voice_summary_prompt".localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)

                transcriptCard
                    .padding(.horizontal, AppSpacing.md)

                microphoneButton

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }

                if let gradeResult {
                    gradeCard(gradeResult)
                        .padding(.horizontal, AppSpacing.md)
                }

                Spacer()

                doneButton
                    .padding(.horizontal, AppSpacing.md)

                Button {
                    speechRecognizer.stopListening()
                    dismiss()
                } label: {
                    Text("memorize.pause_cancel".localized)
                        .font(AppTypography.body)
                        .foregroundColor(Color.white.opacity(0.65))
                }
                .padding(.bottom, AppSpacing.lg)
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
                    .navigationTitle("memorize.voice_summary".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        speechRecognizer.stopListening()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            // Release any previous audio session (voice menu, Gemini, etc.)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            await speechRecognizer.requestPermissionsIfNeeded()
            if speechRecognizer.speechPermissionDenied || speechRecognizer.micPermissionDenied {
                errorMessage = "memorize.voice_permission_required".localized
            }
        }
        .onDisappear {
            speechRecognizer.stopListening()
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(bookTitle)
                .font(AppTypography.caption)
                .foregroundColor(Color.white.opacity(0.55))
                .lineLimit(1)

            ScrollView {
                Text(speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                     ? "memorize.voice_summary_placeholder".localized
                     : speechRecognizer.transcript)
                    .font(AppTypography.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
            }
            .frame(minHeight: 140, maxHeight: 200)
            .background(AppColors.memorizeCard)
            .cornerRadius(AppCornerRadius.md)
        }
    }

    private var microphoneButton: some View {
        Button {
            errorMessage = nil
            if speechRecognizer.isListening {
                speechRecognizer.stopListening()
                Task {
                    await gradeSummary()
                }
            } else {
                do {
                    try speechRecognizer.startListening()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            ZStack {
                if speechRecognizer.isListening {
                    Circle()
                        .stroke(voiceAccent.opacity(0.45), lineWidth: 3)
                        .frame(width: 150, height: 150)
                        .scaleEffect(pulseAnimation ? 1.28 : 1.0)
                        .opacity(pulseAnimation ? 0.1 : 0.85)

                    Circle()
                        .stroke(voiceAccent.opacity(0.28), lineWidth: 2)
                        .frame(width: 176, height: 176)
                        .scaleEffect(pulseAnimation ? 1.18 : 0.92)
                        .opacity(pulseAnimation ? 0.06 : 0.55)
                } else {
                    Circle()
                        .fill(voiceAccent.opacity(0.2))
                        .frame(width: 150, height: 150)
                }

                Circle()
                    .fill(voiceAccent)
                    .frame(width: 112, height: 112)

                Image(systemName: speechRecognizer.isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .disabled(isGrading || speechRecognizer.speechPermissionDenied || speechRecognizer.micPermissionDenied)
        .opacity((isGrading || speechRecognizer.speechPermissionDenied || speechRecognizer.micPermissionDenied) ? 0.5 : 1.0)
        .onChange(of: speechRecognizer.isListening) { isListening in
            if isListening {
                pulseAnimation = true
            } else {
                pulseAnimation = false
            }
        }
        .animation(
            speechRecognizer.isListening
                ? .easeOut(duration: 1.0).repeatForever(autoreverses: true)
                : .easeOut(duration: 0.2),
            value: pulseAnimation
        )
    }

    private var doneButton: some View {
        Button {
            Task {
                await gradeSummary()
            }
        } label: {
            HStack(spacing: 8) {
                if isGrading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(isGrading ? "memorize.grading_summary".localized : "memorize.done".localized)
                    .font(AppTypography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(voiceAccent)
            .cornerRadius(AppCornerRadius.md)
        }
        .disabled(isGrading || speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity((isGrading || speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.5 : 1.0)
    }

    private func gradeCard(_ result: MemorizeService.VoiceSummaryEvaluation) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(String(format: "memorize.summary_score".localized, result.score))
                    .font(AppTypography.title2)
                    .foregroundColor(.white)

                if !result.strengths.isEmpty {
                    Text("memorize.strengths".localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(voiceAccent)
                    ForEach(result.strengths.prefix(8), id: \.self) { item in
                        Text("• \(item)")
                            .font(AppTypography.body)
                            .foregroundColor(Color.white.opacity(0.9))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !result.improvements.isEmpty {
                    Text("memorize.improvements".localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(voiceAccent)
                        .padding(.top, 4)
                    ForEach(result.improvements.prefix(8), id: \.self) { item in
                        Text("• \(item)")
                            .font(AppTypography.body)
                            .foregroundColor(Color.white.opacity(0.9))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(result.feedback)
                    .font(AppTypography.body)
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
        }
        .frame(minHeight: 180, maxHeight: 300)
        .background(AppColors.memorizeCard)
        .cornerRadius(AppCornerRadius.md)
    }

    private func gradeSummary() async {
        speechRecognizer.stopListening()
        let summary = speechRecognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else {
            errorMessage = "memorize.voice_summary_empty_error".localized
            return
        }
        errorMessage = nil
        isGrading = true
        defer { isGrading = false }

        do {
            let result = try await memorizeService.gradeVoiceSummary(
                summary: summary,
                from: pages
            )
            gradeResult = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MemorizeExplainView: View {
    @ObservedObject var viewModel: MemorizeCaptureViewModel
    let bookTitle: String
    let pages: [PageCapture]
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var geminiService: GeminiLiveService?
    @State private var isConnected = false
    @State private var isRecording = false
    @State private var messages: [MemorizeInteractMessage] = []
    @State private var currentAIText = ""
    @State private var currentUserText = ""
    @State private var isAIThinking = false
    @State private var errorMessage: String?
    @State private var isMuted = false
    @State private var loadingPulse = false
    private let explainAccent = Color(red: 0.94, green: 0.55, blue: 0.24)

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.md) {
                Label {
                    Text(viewModel.explanationPersona.displayKey.localized)
                } icon: {
                    Text(viewModel.explanationPersona.iconSystemImage)
                }
                .font(AppTypography.title2)
                .foregroundColor(explainAccent)
                .multilineTextAlignment(.center)

                Text(bookTitle)
                    .font(AppTypography.caption)
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(1)
                    .padding(.horizontal, AppSpacing.md)

                // Show generating state before Gemini connects
                if viewModel.isGeneratingExplanation && viewModel.explanationText.isEmpty {
                    generatingCard
                        .padding(.horizontal, AppSpacing.md)
                } else {
                    conversationCard
                        .padding(.horizontal, AppSpacing.md)
                }

                if !isConnected && !viewModel.isGeneratingExplanation {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("memorize.interact_connecting".localized)
                            .font(AppTypography.caption)
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }

                if isConnected {
                    microphoneButton
                }

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }

                if let explanationError = viewModel.explanationErrorMessage, !explanationError.isEmpty {
                    VStack(spacing: AppSpacing.sm) {
                        Text(explanationError)
                            .font(AppTypography.caption)
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                        Button {
                            viewModel.generateExplanation(as: viewModel.explanationPersona)
                        } label: {
                            Text("memorize.retry".localized)
                                .font(AppTypography.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.18))
                                .cornerRadius(AppCornerRadius.sm)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }

                Button {
                    disconnectAndDismiss()
                } label: {
                    Text("memorize.done".localized)
                        .font(AppTypography.body)
                        .foregroundColor(Color.white.opacity(0.65))
                        .padding(.bottom, AppSpacing.lg)
                }
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("memorize.explain".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        disconnectAndDismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            loadingPulse = false
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                loadingPulse = true
            }
        }
        .onChange(of: viewModel.explanationText) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            // Summary text is ready — connect Gemini Live to speak it and allow conversation
            if geminiService == nil {
                setupAndConnect(summaryText: trimmed)
            }
        }
        .task {
            // If summary text is already available (e.g. cached), connect immediately
            let existing = viewModel.explanationText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !existing.isEmpty {
                // Let previous audio session fully release
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                try? await Task.sleep(nanoseconds: 500_000_000)
                setupAndConnect(summaryText: existing)
            }
        }
        .onDisappear {
            viewModel.explanationErrorMessage = nil
            loadingPulse = false
        }
    }

    private func disconnectAndDismiss() {
        geminiService?.disconnect()
        geminiService = nil
        dismiss()
        onClose()
    }

    // MARK: - Setup

    private func setupAndConnect(summaryText: String) {
        guard geminiService == nil else { return }

        let completedPages = pages.filter { $0.status == .completed }
        let combinedText = completedPages
            .enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element.extractedText)" }
            .joined(separator: "\n\n")

        let maxChars = 15000
        let truncatedText = combinedText.count > maxChars
            ? String(combinedText.prefix(maxChars)) + "\n[... text truncated ...]"
            : combinedText

        let personaInstruction = viewModel.explanationPersona.promptInstruction

        let systemPrompt = """
        You are a friendly reading tutor summarizing a book for a student. Explain as if the student is \(personaInstruction)

        The student has read the following text from "\(bookTitle)":

        ---
        \(truncatedText)
        ---

        Here is a written summary that was prepared:

        ---
        \(summaryText)
        ---

        Your task:
        1. First, read the summary aloud to the student in a clear, engaging way. Use the persona style described above.
        2. After reading the summary, pause briefly and invite the student to ask questions — for example: "Do you have any questions about what we just covered?"
        3. Then answer any follow-up questions the student asks, drawing from the original text and the summary.

        Keep your responses concise and conversational. Speak clearly and at a pace suitable for learning.
        Do not apologize. Do not mention that you are an AI unless asked.
        """

        let apiKey = APIProviderManager.staticLiveAIAPIKey
        let service = GeminiLiveService(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            includeTools: false
        )

        service.onConnected = { [service] in
            Task { @MainActor in
                isConnected = true
                // Start recording with mic live — user can interrupt anytime
                service.isMicMuted = false
                service.startRecording()
                isRecording = true
                isMuted = false
                // Trigger the AI to start reading the summary aloud immediately
                try? await Task.sleep(nanoseconds: 300_000_000)
                service.sendTextInput("Please begin reading the summary aloud now.")
            }
        }

        service.onUserTranscript = { (userText: String) in
            Task { @MainActor in
                guard !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                currentUserText += userText
                isAIThinking = true
            }
        }

        service.onTranscriptDelta = { (delta: String) in
            Task { @MainActor in
                let cleaned = delta.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return }
                if !currentUserText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let finalUserText = currentUserText
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    messages.append(MemorizeInteractMessage(isUser: true, text: finalUserText))
                    currentUserText = ""
                }
                isAIThinking = false
                if cleaned.hasPrefix(currentAIText) && cleaned.count > currentAIText.count {
                    currentAIText = cleaned
                } else if currentAIText.isEmpty || !cleaned.hasPrefix(currentAIText) {
                    if currentAIText.isEmpty {
                        currentAIText = cleaned
                    } else {
                        let needsSpace = !currentAIText.hasSuffix(" ") && !cleaned.hasPrefix(" ")
                        currentAIText += (needsSpace ? " " : "") + cleaned
                    }
                }
            }
        }

        service.onTranscriptDone = { (fullText: String) in
            Task { @MainActor in
                let trimmed = (fullText.isEmpty ? currentAIText : fullText)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    messages.append(MemorizeInteractMessage(isUser: false, text: trimmed))
                }
                currentAIText = ""
                isAIThinking = false
            }
        }

        service.onError = { (errorText: String) in
            Task { @MainActor in
                errorMessage = errorText
            }
        }

        geminiService = service
        service.connect()
    }

    // MARK: - UI Components

    private var generatingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.9)
                Text("memorize.explain_generating".localized)
                    .font(AppTypography.body)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, AppSpacing.md)

            ForEach(0..<4, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 14)
                    .overlay(
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0), Color.white.opacity(0.45), Color.white.opacity(0)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: loadingPulse ? geo.size.width : 0)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, AppSpacing.md)
                    .frame(maxWidth: .infinity)
                    .opacity(idx == 3 ? 0.7 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: loadingPulse)
            }
        }
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.md)
        .frame(minHeight: 240, maxHeight: 320)
        .background(AppColors.memorizeCard)
        .cornerRadius(AppCornerRadius.md)
    }

    private var conversationCard: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty && currentAIText.isEmpty && !isAIThinking {
                    Text("memorize.explain_result_placeholder".localized)
                        .font(AppTypography.body)
                        .foregroundColor(Color.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.md)
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            HStack {
                                if message.isUser { Spacer() }
                                Text(message.text)
                                    .font(AppTypography.body)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(message.isUser ? .trailing : .leading)
                                    .padding(AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                            .fill(message.isUser ? explainAccent.opacity(0.3) : AppColors.memorizeCard)
                                    )
                                if !message.isUser { Spacer() }
                            }
                            .id(message.id)
                        }

                        if !currentUserText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack {
                                Spacer()
                                Text(currentUserText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression))
                                    .font(AppTypography.body)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                            .fill(explainAccent.opacity(0.2))
                                    )
                            }
                            .id("userStreaming")
                        }

                        if isAIThinking && currentAIText.isEmpty {
                            HStack {
                                ThinkingDotsView()
                                    .padding(AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                            .fill(AppColors.memorizeCard.opacity(0.7))
                                    )
                                Spacer()
                            }
                            .id("thinking")
                        }

                        if !currentAIText.isEmpty {
                            HStack {
                                Text(currentAIText)
                                    .font(AppTypography.body)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                            .fill(AppColors.memorizeCard.opacity(0.7))
                                    )
                                Spacer()
                            }
                            .id("streaming")
                        }
                    }
                    .padding(AppSpacing.sm)
                }
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: currentUserText) { _ in
                withAnimation { proxy.scrollTo("userStreaming", anchor: .bottom) }
            }
            .onChange(of: isAIThinking) { _ in
                withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
            }
            .onChange(of: currentAIText) { _ in
                withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
            }
        }
        .frame(minHeight: 260, maxHeight: 400)
        .background(AppColors.memorizeCard)
        .cornerRadius(AppCornerRadius.md)
    }

    private var microphoneButton: some View {
        Button {
            guard isConnected, let service = geminiService else { return }
            if isMuted {
                // Unmute — allow user to interrupt and speak
                service.interruptPlayback()
                service.isMicMuted = false
                isMuted = false
            } else {
                // Mute — stop sending audio to Gemini
                service.isMicMuted = true
                isMuted = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text(isMuted ? "memorize.podcast_unmute".localized : "memorize.podcast_mute".localized)
                    .font(AppTypography.subheadline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isMuted ? Color.white.opacity(0.15) : explainAccent.opacity(0.5))
            .cornerRadius(AppCornerRadius.md)
        }
        .disabled(!isConnected)
        .opacity(!isConnected ? 0.5 : 1.0)
    }
}

// MARK: - Memorize Interact View (Gemini Live Voice)

private struct MemorizeInteractMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
}

// MARK: - Post-Capture Voice Menu Controller

@MainActor
private final class PostCaptureVoiceMenuController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    enum MenuCommand {
        case interact
        case explain
        case popQuiz
        case voiceSummary
        case podcast
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onCommand: ((MenuCommand) -> Void)?
    private var hasTriggered = false
    private var shouldListen = false
    private var restartTask: Task<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func askAndListen(onCommand: @escaping (MenuCommand) -> Void) {
        self.onCommand = onCommand
        hasTriggered = false
        shouldListen = true

        // Speak a prompt, then listen for the command
        speakPromptThenListen()
    }

    private func speakPromptThenListen() {
        guard shouldListen, !hasTriggered else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [VoiceMenu] TTS session setup failed: \(error.localizedDescription)")
            beginListeningIfNeeded()
            return
        }

        let promptText = "memorize.voice_menu_prompt".localized
        let utterance = AVSpeechUtterance(string: promptText)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-US")
        synthesizer.speak(utterance)
    }

    // AVSpeechSynthesizerDelegate — start listening after TTS finishes
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard shouldListen, !hasTriggered else { return }
            // Small delay to let audio session transition
            try? await Task.sleep(nanoseconds: 300_000_000)
            beginListeningIfNeeded()
        }
    }

    func stop() {
        shouldListen = false
        restartTask?.cancel()
        restartTask = nil
        synthesizer.stopSpeaking(at: .immediate)
        stopListeningInternal(deactivateSession: true)
    }

    private func beginListeningIfNeeded() {
        guard shouldListen, !hasTriggered else { return }
        guard recognitionTask == nil else { return }

        restartTask?.cancel()
        restartTask = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [VoiceMenu] Record session setup failed: \(error.localizedDescription)")
            scheduleRestart()
            return
        }

        // Create a fresh audio engine to avoid stale input node state
        audioEngine = AVAudioEngine()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            print("⚠️ [VoiceMenu] Speech recognizer not available")
            return
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            print("⚠️ [VoiceMenu] Invalid input format: rate=\(inputFormat.sampleRate), channels=\(inputFormat.channelCount)")
            scheduleRestart()
            return
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("⚠️ [VoiceMenu] Audio engine start failed: \(error.localizedDescription)")
            scheduleRestart()
            return
        }

        print("🎤 [VoiceMenu] Listening for menu command...")

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if hasTriggered {
                    print("🎤 [VoiceMenu] Ignoring (already triggered)")
                    return
                }
                if let text = result?.bestTranscription.formattedString {
                    let lower = text.lowercased()
                    print("🎤 [VoiceMenu] Heard: \"\(text)\" (isFinal: \(result?.isFinal ?? false))")
                    if let command = parseMenuCommand(from: lower) {
                        print("✅ [VoiceMenu] Matched command: \(command)")
                        hasTriggered = true
                        stopListeningInternal(deactivateSession: true)
                        onCommand?(command)
                        return
                    }
                }
                if let error {
                    print("⚠️ [VoiceMenu] Recognition error: \(error.localizedDescription)")
                    stopListeningInternal()
                    scheduleRestart()
                } else if result?.isFinal ?? false {
                    print("ℹ️ [VoiceMenu] Final result, no match — restarting")
                    stopListeningInternal()
                    scheduleRestart()
                }
            }
        }
    }

    private func stopListeningInternal(deactivateSession: Bool = false) {
        restartTask?.cancel()
        restartTask = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func scheduleRestart() {
        guard shouldListen, !hasTriggered else { return }
        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            self?.beginListeningIfNeeded()
        }
    }

    private func parseMenuCommand(from text: String) -> MenuCommand? {
        let normalized = text.replacingOccurrences(of: "-", with: " ").lowercased()
        if normalized.contains("interact") || normalized.contains("conversation") || normalized.contains("chat") {
            return .interact
        }
        if normalized.contains("quiz") {
            return .popQuiz
        }
        if normalized.contains("voice summary") || (normalized.contains("voice") && !normalized.contains("quiz")) {
            return .voiceSummary
        }
        if normalized.contains("summary") && !normalized.contains("voice") {
            return .explain
        }
        if normalized.contains("summarize") || normalized.contains("summar") {
            return .explain
        }
        if normalized.contains("podcast") {
            return .podcast
        }
        return nil
    }

}

// MARK: - Explain Persona Picker with Voice

private struct ExplainPersonaPickerView: View {
    let onSelect: (MemorizeExplainPersona) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceListener = ExplainPersonaVoiceListener()
    private let explainAccent = Color(red: 0.94, green: 0.55, blue: 0.24)

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text("memorize.explain.select_persona".localized)
                .font(AppTypography.headline)
                .foregroundColor(.white)
                .padding(.top, 32)

            if voiceListener.isListening {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(explainAccent)
                    Text("Listening...")
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }

            ForEach(MemorizeExplainPersona.allCases) { persona in
                Button {
                    voiceListener.stop()
                    onSelect(persona)
                } label: {
                    HStack(spacing: 10) {
                        Text(persona.iconSystemImage)
                            .font(.system(size: 22))
                        Text(persona.displayKey.localized)
                            .font(AppTypography.body)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, AppSpacing.md)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(AppCornerRadius.sm)
                }
            }
            .padding(.horizontal, AppSpacing.md)

            Button {
                voiceListener.stop()
                dismiss()
            } label: {
                Text("memorize.cancel".localized)
                    .font(AppTypography.body)
                    .foregroundColor(Color.white.opacity(0.65))
            }
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.memorizeBackground.ignoresSafeArea())
        .task {
            // Brief delay for audio session to settle
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            try? await Task.sleep(nanoseconds: 800_000_000)
            voiceListener.startListening { persona in
                onSelect(persona)
            }
        }
        .onDisappear {
            voiceListener.stop()
        }
    }
}

@MainActor
private final class ExplainPersonaVoiceListener: ObservableObject {
    @Published var isListening = false

    private var audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onPersona: ((MemorizeExplainPersona) -> Void)?
    private var hasTriggered = false
    private var restartTask: Task<Void, Never>?

    func startListening(onPersona: @escaping (MemorizeExplainPersona) -> Void) {
        self.onPersona = onPersona
        hasTriggered = false
        beginListening()
    }

    func stop() {
        hasTriggered = true
        restartTask?.cancel()
        restartTask = nil
        stopInternal()
    }

    private func beginListening() {
        guard !hasTriggered else { return }
        guard recognitionTask == nil else { return }

        restartTask?.cancel()
        restartTask = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [PersonaVoice] Audio session setup failed: \(error.localizedDescription)")
            scheduleRestart()
            return
        }

        audioEngine = AVAudioEngine()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            print("⚠️ [PersonaVoice] Speech recognizer not available")
            return
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            print("⚠️ [PersonaVoice] Invalid input format")
            scheduleRestart()
            return
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("⚠️ [PersonaVoice] Audio engine start failed: \(error.localizedDescription)")
            scheduleRestart()
            return
        }

        isListening = true
        print("🎤 [PersonaVoice] Listening for persona...")

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.hasTriggered else { return }
                if let text = result?.bestTranscription.formattedString.lowercased() {
                    print("🎤 [PersonaVoice] Heard: \(text)")
                    if let persona = self.parsePersona(from: text) {
                        self.hasTriggered = true
                        self.stopInternal()
                        self.onPersona?(persona)
                        return
                    }
                }
                if let error {
                    print("⚠️ [PersonaVoice] Recognition error: \(error.localizedDescription)")
                    self.stopInternal()
                    self.scheduleRestart()
                } else if result?.isFinal ?? false {
                    self.stopInternal()
                    self.scheduleRestart()
                }
            }
        }
    }

    private func stopInternal() {
        restartTask?.cancel()
        restartTask = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func scheduleRestart() {
        guard !hasTriggered else { return }
        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            self?.beginListening()
        }
    }

    private func parsePersona(from text: String) -> MemorizeExplainPersona? {
        let normalized = text.replacingOccurrences(of: "-", with: " ")
        if normalized.contains("5") || normalized.contains("five") || normalized.contains("like i am") || normalized.contains("like a kid") || normalized.contains("year old") {
            return .likeIAm5
        }
        if normalized.contains("high school") {
            return .highSchoolStudent
        }
        if normalized.contains("college") || normalized.contains("university") {
            return .collegeStudent
        }
        if normalized.contains("artist") || normalized.contains("creative") {
            return .artist
        }
        if normalized.contains("research") || normalized.contains("academic") || normalized.contains("scientist") {
            return .researcher
        }
        return nil
    }
}

private struct ThinkingDotsView: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(index < dotCount ? 0.8 : 0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .onReceive(timer) { _ in
            dotCount = (dotCount % 3) + 1
        }
    }
}

private struct MemorizeInteractView: View {
    let pages: [PageCapture]
    let bookTitle: String

    @Environment(\.dismiss) private var dismiss
    @State private var geminiService: GeminiLiveService?
    @State private var isConnected = false
    @State private var isRecording = false
    @State private var messages: [MemorizeInteractMessage] = []
    @State private var currentAIText = ""
    @State private var currentUserText = ""
    @State private var isAIThinking = false
    @State private var errorMessage: String?
    @State private var isMuted = true

    private let interactAccent = Color(red: 0.15, green: 0.72, blue: 0.52)

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.md) {
                Text("memorize.interact_prompt".localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)

                Text(bookTitle)
                    .font(AppTypography.caption)
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(1)
                    .padding(.horizontal, AppSpacing.md)

                conversationCard
                    .padding(.horizontal, AppSpacing.md)

                if !isConnected {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("memorize.interact_connecting".localized)
                            .font(AppTypography.caption)
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }

                microphoneButton

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }

                Button {
                    disconnectAndDismiss()
                } label: {
                    Text("memorize.pause_cancel".localized)
                        .font(AppTypography.body)
                        .foregroundColor(Color.white.opacity(0.65))
                        .padding(.bottom, AppSpacing.lg)
                }
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("memorize.interact".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        disconnectAndDismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            guard geminiService == nil else { return }
            setupAndConnect()
        }
    }

    private func disconnectAndDismiss() {
        geminiService?.disconnect()
        geminiService = nil
        dismiss()
    }

    // MARK: - Setup

    private func setupAndConnect() {
        let completedPages = pages.filter { $0.status == .completed }
        let combinedText = completedPages
            .enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element.extractedText)" }
            .joined(separator: "\n\n")

        // Truncate if too long (keep under ~15k chars for system prompt)
        let maxChars = 15000
        let truncatedText = combinedText.count > maxChars
            ? String(combinedText.prefix(maxChars)) + "\n[... text truncated ...]"
            : combinedText

        let systemPrompt = """
        You are a friendly, knowledgeable reading tutor. The student has just read the following text from "\(bookTitle)":

        ---
        \(truncatedText)
        ---

        Help the student understand what they read. You can:
        - Answer questions about the text
        - Explain difficult concepts or vocabulary
        - Ask comprehension questions to test understanding
        - Summarize key points when asked
        - Connect ideas in the text to broader knowledge

        Keep your responses concise and conversational. Speak clearly and at a pace suitable for learning.
        Do not apologize. Do not mention that you are an AI unless asked.
        Start by briefly greeting the student and asking what they'd like to discuss about the reading.
        """

        let apiKey = APIProviderManager.staticLiveAIAPIKey
        let service = GeminiLiveService(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            includeTools: false
        )

        service.onConnected = { [service] in
            Task { @MainActor in
                isConnected = true
                // Start recording with mic live — conversation mode is fully hands-free
                service.isMicMuted = false
                service.startRecording()
                isRecording = true
                isMuted = false
            }
        }

        service.onUserTranscript = { (userText: String) in
            Task { @MainActor in
                guard !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                currentUserText += userText
                isAIThinking = true
            }
        }

        service.onTranscriptDelta = { (delta: String) in
            Task { @MainActor in
                let cleaned = delta.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return }
                // Finalize the user message when the AI starts responding
                if !currentUserText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let finalUserText = currentUserText
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    messages.append(MemorizeInteractMessage(isUser: true, text: finalUserText))
                    currentUserText = ""
                }
                isAIThinking = false
                // Gemini sends cumulative or incremental deltas — handle both
                if cleaned.hasPrefix(currentAIText) && cleaned.count > currentAIText.count {
                    // Cumulative: the delta contains everything so far
                    currentAIText = cleaned
                } else if currentAIText.isEmpty || !cleaned.hasPrefix(currentAIText) {
                    // Incremental: append the new fragment
                    if currentAIText.isEmpty {
                        currentAIText = cleaned
                    } else {
                        let needsSpace = !currentAIText.hasSuffix(" ") && !cleaned.hasPrefix(" ")
                        currentAIText += (needsSpace ? " " : "") + cleaned
                    }
                }
            }
        }

        service.onTranscriptDone = { (fullText: String) in
            Task { @MainActor in
                let trimmed = (fullText.isEmpty ? currentAIText : fullText)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    messages.append(MemorizeInteractMessage(isUser: false, text: trimmed))
                }
                currentAIText = ""
                isAIThinking = false
            }
        }

        service.onError = { (errorText: String) in
            Task { @MainActor in
                errorMessage = errorText
            }
        }

        geminiService = service
        service.connect()
    }

    // MARK: - UI Components

    private var conversationCard: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty && currentAIText.isEmpty {
                    Text("memorize.interact_placeholder".localized)
                        .font(AppTypography.body)
                        .foregroundColor(Color.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.md)
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            HStack {
                                if message.isUser { Spacer() }
                                Text(message.text)
                                    .font(AppTypography.body)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(message.isUser ? .trailing : .leading)
                                    .padding(AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                            .fill(message.isUser ? interactAccent.opacity(0.3) : AppColors.memorizeCard)
                                    )
                                if !message.isUser { Spacer() }
                            }
                            .id(message.id)
                        }

                        // Show streaming user text
                        if !currentUserText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack {
                                Spacer()
                                Text(currentUserText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression))
                                    .font(AppTypography.body)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                            .fill(interactAccent.opacity(0.2))
                                    )
                            }
                            .id("userStreaming")
                        }

                        // Show thinking indicator
                        if isAIThinking && currentAIText.isEmpty {
                            HStack {
                                ThinkingDotsView()
                                    .padding(AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                            .fill(AppColors.memorizeCard.opacity(0.7))
                                    )
                                Spacer()
                            }
                            .id("thinking")
                        }

                        // Show streaming AI text
                        if !currentAIText.isEmpty {
                            HStack {
                                Text(currentAIText)
                                    .font(AppTypography.body)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                            .fill(AppColors.memorizeCard.opacity(0.7))
                                    )
                                Spacer()
                            }
                            .id("streaming")
                        }
                    }
                    .padding(AppSpacing.sm)
                }
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: currentUserText) { _ in
                withAnimation { proxy.scrollTo("userStreaming", anchor: .bottom) }
            }
            .onChange(of: isAIThinking) { _ in
                withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
            }
            .onChange(of: currentAIText) { _ in
                withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
            }
        }
        .frame(minHeight: 260, maxHeight: 400)
        .background(AppColors.memorizeCard)
        .cornerRadius(AppCornerRadius.md)
    }

    private var microphoneButton: some View {
        Button {
            guard isConnected, let service = geminiService else { return }
            if isMuted {
                service.interruptPlayback()
                service.isMicMuted = false
                isMuted = false
            } else {
                service.isMicMuted = true
                isMuted = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text(isMuted ? "memorize.podcast_unmute".localized : "memorize.podcast_mute".localized)
                    .font(AppTypography.subheadline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isMuted ? Color.white.opacity(0.15) : interactAccent.opacity(0.5))
            .cornerRadius(AppCornerRadius.md)
        }
        .disabled(!isConnected)
        .opacity(!isConnected ? 0.5 : 1.0)
    }
}
