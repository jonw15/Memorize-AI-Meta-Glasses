/*
 * Memorize Capture View
 * Page capture screen with countdown, camera button, and session timeline
 */

import SwiftUI
import Speech
import AVFoundation

private func normalizeMemorizeLiveText(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func clippedMemorizeLiveText(_ text: String, maxChars: Int) -> String {
    let normalized = normalizeMemorizeLiveText(text)
    guard !normalized.isEmpty else { return "" }
    guard normalized.count > maxChars else { return normalized }

    let endIndex = normalized.index(normalized.startIndex, offsetBy: maxChars)
    var clipped = String(normalized[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)

    if let sentenceEnd = clipped.lastIndex(where: { ".!?".contains($0) }),
       clipped.distance(from: clipped.startIndex, to: sentenceEnd) > maxChars / 2 {
        clipped = String(clipped[...sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return clipped + " ..."
}

func buildMemorizeLiveSourceContext(
    from pages: [PageCapture],
    maxPages: Int,
    maxCharsPerPage: Int,
    maxTotalChars: Int
) -> String {
    let completedPages = pages.filter { $0.status == .completed }
    guard !completedPages.isEmpty else { return "" }

    let selectedPages: [PageCapture]
    if completedPages.count <= maxPages {
        selectedPages = completedPages
    } else {
        let leadingCount = max(1, maxPages / 2)
        let trailingCount = max(1, maxPages - leadingCount)
        selectedPages = Array(completedPages.prefix(leadingCount)) + Array(completedPages.suffix(trailingCount))
    }

    let sections = selectedPages.compactMap { page -> String? in
        let excerpt = clippedMemorizeLiveText(page.extractedText, maxChars: maxCharsPerPage)
        guard !excerpt.isEmpty else { return nil }
        return "--- Page \(page.pageNumber) ---\n\(excerpt)"
    }

    guard !sections.isEmpty else { return "" }

    var context = sections.joined(separator: "\n\n")
    if completedPages.count > selectedPages.count {
        context += "\n\n[Reference notes condensed from \(completedPages.count) pages.]"
    }

    if context.count > maxTotalChars {
        context = clippedMemorizeLiveText(context, maxChars: maxTotalChars)
        context += "\n[... additional context omitted ...]"
    }

    return context
}

struct MemorizeCaptureView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    let book: Book?

    @StateObject private var viewModel = MemorizeCaptureViewModel()
    @StateObject private var captureVoiceController = CaptureVoiceCommandController()
    @StateObject private var introAnnouncer = CaptureIntroAnnouncer()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedThumbnail: TimelineThumbnailPreview?
    @State private var showPostCaptureActions = false
    @State private var hasSelectedDevice = false
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
            if !hasSelectedDevice {
                deviceSelectionScreen
            } else {
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

                // 3S Delay indicator (glasses only)
                if viewModel.captureDevice == .glasses {
                    delayIndicator
                        .padding(.top, AppSpacing.md)

                    Text("Say \"take a photo\" or \"done reading\"")
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacing.sm)
                        .padding(.horizontal, AppSpacing.md)
                }

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
                        Task {
                            await streamViewModel.stopSession()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            } // end else (hasSelectedDevice)
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
                bookTitle: displayBookTitle ?? "",
                sectionTitle: viewModel.currentBook?.chapter.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            ) {
                showPostCaptureActions = false
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $viewModel.showPhoneCamera) {
            PhoneCameraView { image in
                viewModel.showPhoneCamera = false
                if let image {
                    viewModel.handlePhoneCameraCapture(image)
                }
            }
        }
        .onAppear {
            viewModel.streamViewModel = streamViewModel
            viewModel.loadBook(book)
            // Release any audio session held by previous voice controllers
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            // Don't start streaming yet — wait for device selection
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
        .onChange(of: hasSelectedDevice) { selected in
            guard selected else { return }
            if viewModel.captureDevice == .phone {
                viewModel.setupPhoneCamera()
            } else {
                // Glasses selected — start streaming
                introSequenceTask?.cancel()
                introSequenceTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await streamViewModel.handleStartStreaming()

                    if !didPlayIntroInstruction {
                        didPlayIntroInstruction = true
                        captureVoiceController.suspendListening()
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
            viewModel.stopPhoneCamera()
            Task {
                await streamViewModel.stopSession()
            }
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
            if viewModel.captureDevice == .phone {
                PhoneCameraPreviewView(session: viewModel.phoneCaptureSession)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 300)
            } else if let videoFrame = streamViewModel.currentVideoFrame {
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

            if let title = displayBookTitle {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.memorizeAccent)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, AppSpacing.md)
            }

            Text("memorize.capture_subtitle".localized)
                .font(AppTypography.subheadline)
                .foregroundColor(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppSpacing.lg)
    }

    private var displayBookTitle: String? {
        let title = viewModel.currentBook?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? nil : title
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
                Circle()
                    .stroke(AppColors.memorizeAccent.opacity(0.3), lineWidth: 4)
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(
                        viewModel.isCountingDown
                            ? Color.red.opacity(0.8)
                            : AppColors.memorizeAccent
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: viewModel.isCountingDown ? "stop.fill" : "camera.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
        }
        .disabled(viewModel.isGeneratingQuiz)
        .opacity(viewModel.isGeneratingQuiz ? 0.5 : 1.0)
    }

    // MARK: - Device Selection Screen

    private var deviceSelectionScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.memorizeAccent)

                Text("memorize.select_device".localized)
                    .font(AppTypography.title2)
                    .foregroundColor(.white)

                Text("memorize.select_device_desc".localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)

                VStack(spacing: AppSpacing.sm) {
                    ForEach(CaptureDevice.allCases, id: \.self) { device in
                        Button {
                            viewModel.captureDevice = device
                            hasSelectedDevice = true
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: device.iconName)
                                    .font(.system(size: 24))
                                    .frame(width: 44, height: 44)
                                    .background(AppColors.memorizeAccent.opacity(0.15))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.rawValue)
                                        .font(AppTypography.headline)
                                    Text(device == .glasses ? "memorize.device_glasses_desc".localized : "memorize.device_phone_desc".localized)
                                        .font(AppTypography.caption)
                                        .foregroundColor(Color.white.opacity(0.5))
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.3))
                            }
                            .foregroundColor(.white)
                            .padding(AppSpacing.md)
                            .background(AppColors.memorizeCard)
                            .cornerRadius(AppCornerRadius.lg)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }

            Spacer()
        }
        .background(AppColors.memorizeBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
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
        // Don't enable until intro announcer finishes speaking
        guard introAnnouncer.hasSpoken else { return false }
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
            dismiss()
        } label: {
            Text("memorize.done".localized)
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
    @Published var hasSpoken = false
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

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, !hasSpoken else { return }
            hasSpoken = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            hasSpoken = true
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

struct MemorizePostCaptureActionsView: View {
    @ObservedObject var viewModel: MemorizeCaptureViewModel
    let bookTitle: String
    let sectionTitle: String
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showExplainPersonaSelector = false
    @State private var showVoiceSummary = false
    @State private var showInteract = false
    @State private var showReadAloud = false
    @State private var showInfographics = false
    @State private var showPodcastModePicker = false
    @State private var voiceMenuRestartTask: Task<Void, Never>?
    @StateObject private var voiceMenu = PostCaptureVoiceMenuController()

    private var completedPages: [PageCapture] {
        viewModel.pages.filter { $0.status == .completed }
    }

    private var usesPDFLengthHeuristic: Bool {
        viewModel.currentBook?.sources.contains(where: { $0.sourceType == .pdf }) ?? false
    }

    /// True when buttons should be disabled — before voice menu speaks or while a feature is active
    private var isButtonsDisabled: Bool {
        !voiceMenu.hasSpoken ||
        showInteract || showExplainPersonaSelector || showVoiceSummary || showReadAloud || showInfographics ||
        viewModel.showExplain || viewModel.showQuiz || viewModel.showPodcastPlayer || viewModel.showPodcastModePicker ||
        viewModel.isGeneratingQuiz || viewModel.isGeneratingExplanation
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
            case .readAloud:
                showReadAloud = true
            case .infographics:
                showInfographics = true
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

                        readAloudButton
                            .padding(.horizontal, AppSpacing.md)

                        infographicsButton
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
                bookTitle: bookTitle,
                sectionTitle: sectionTitle
            )
        }
        .fullScreenCover(isPresented: $showInteract) {
            MemorizeInteractView(
                pages: completedPages,
                bookTitle: bookTitle,
                sectionTitle: sectionTitle
            )
        }
        .fullScreenCover(isPresented: $viewModel.showExplain) {
            MemorizeExplainView(
                viewModel: viewModel,
                bookTitle: bookTitle,
                sectionTitle: sectionTitle,
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
                sectionTitle: sectionTitle,
                mode: viewModel.podcastMode,
                usesPDFLengthHeuristic: usesPDFLengthHeuristic,
                onClose: {
                    viewModel.showPodcastPlayer = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showPodcastModePicker) {
            PodcastModePickerView { mode in
                viewModel.startPodcastWithMode(mode)
            }
            .presentationDetents([.height(280)])
        }
        .fullScreenCover(isPresented: $showReadAloud) {
            MemorizeReadAloudView(
                pages: completedPages,
                bookTitle: bookTitle,
                sectionTitle: sectionTitle
            )
        }
        .fullScreenCover(isPresented: $showInfographics) {
            MemorizeInfographicsView(
                pages: completedPages,
                bookTitle: bookTitle,
                sectionTitle: sectionTitle
            )
        }
        .task {
            guard !completedPages.isEmpty else { return }
            // Wait for the page transition to finish before the AI speaks
            try? await Task.sleep(nanoseconds: 2_300_000_000)
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
        .onChange(of: viewModel.showPodcastModePicker) { showing in
            if showing { voiceMenu.stop() } else if !viewModel.showPodcastPlayer { restartVoiceMenuAfterDelay() }
        }
        .onChange(of: viewModel.showPodcastPlayer) { showing in
            if showing { voiceMenu.stop() } else { restartVoiceMenuAfterDelay() }
        }
        .onChange(of: showReadAloud) { showing in
            if showing { voiceMenu.stop() } else { restartVoiceMenuAfterDelay() }
        }
        .onChange(of: showInfographics) { showing in
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
        .disabled(isButtonsDisabled || completedPages.isEmpty)
        .opacity((isButtonsDisabled || completedPages.isEmpty) ? 0.5 : 1.0)
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
        .disabled(isButtonsDisabled || completedPages.isEmpty)
        .opacity((isButtonsDisabled || completedPages.isEmpty) ? 0.5 : 1.0)
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
        .disabled(isButtonsDisabled || completedPages.isEmpty)
        .opacity((isButtonsDisabled || completedPages.isEmpty) ? 0.5 : 1.0)
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
        .disabled(isButtonsDisabled || completedPages.isEmpty)
        .opacity((isButtonsDisabled || completedPages.isEmpty) ? 0.5 : 1.0)
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
        .disabled(isButtonsDisabled || completedPages.isEmpty)
        .opacity((isButtonsDisabled || completedPages.isEmpty) ? 0.5 : 1.0)
    }

    private var readAloudButton: some View {
        Button {
            showReadAloud = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("memorize.read_aloud".localized)
                    .font(AppTypography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.20, green: 0.60, blue: 0.86), Color(red: 0.14, green: 0.48, blue: 0.72)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppCornerRadius.md)
        }
        .disabled(isButtonsDisabled || completedPages.isEmpty)
        .opacity((isButtonsDisabled || completedPages.isEmpty) ? 0.5 : 1.0)
    }

    private var infographicsButton: some View {
        Button {
            showInfographics = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("memorize.infographics".localized)
                    .font(AppTypography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.93, green: 0.35, blue: 0.47), Color(red: 0.80, green: 0.22, blue: 0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppCornerRadius.md)
        }
        .disabled(isButtonsDisabled || completedPages.isEmpty)
        .opacity((isButtonsDisabled || completedPages.isEmpty) ? 0.5 : 1.0)
    }
}

// MARK: - Infographics View (Gemini Image Generation)

struct MemorizeInfographicsView: View {
    let pages: [PageCapture]
    let bookTitle: String
    let sectionTitle: String

    @Environment(\.dismiss) private var dismiss
    @State private var infographics: [UIImage] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var progress: Int = 0
    @State private var totalToGenerate: Int = 0

    private let infographicsAccent = Color(red: 0.93, green: 0.35, blue: 0.47)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isGenerating && infographics.isEmpty {
                    // Loading state
                    Spacer()
                    VStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("memorize.infographics_generating".localized)
                            .font(AppTypography.headline)
                            .foregroundColor(.white)
                        if totalToGenerate > 0 {
                            Text("\(progress)/\(totalToGenerate)")
                                .font(AppTypography.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    Spacer()
                } else if infographics.isEmpty && !isGenerating {
                    // Error or empty state
                    Spacer()
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        if let errorMessage {
                            Text(errorMessage)
                                .font(AppTypography.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.lg)
                        }
                    }
                    Spacer()
                } else {
                    // Infographics scroll view
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(Array(infographics.enumerated()), id: \.offset) { index, image in
                                ZoomableImageView(image: image, accent: infographicsAccent)
                                    .padding(.horizontal, AppSpacing.md)
                            }

                            if isGenerating {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                    Text("memorize.infographics_generating_more".localized)
                                        .font(AppTypography.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(AppSpacing.md)
                            }
                        }
                        .padding(.vertical, AppSpacing.md)
                    }
                }

                // Done button
                Button {
                    dismiss()
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
            .navigationTitle("memorize.infographics".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
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
            await generateInfographics()
        }
    }

    private func generateInfographics() async {
        let completedPages = pages.filter { $0.status == .completed }

        guard !completedPages.isEmpty else {
            errorMessage = "No text content available."
            return
        }

        // Scale infographic count by page count:
        // 1-5 pages → 1-2, 6-10 → 2-3, 11-20 → 3-6, 20-40 → 5-10
        let pageCount = completedPages.count
        let infographicCount: Int
        switch pageCount {
        case 1...2:   infographicCount = 1
        case 3...5:   infographicCount = 2
        case 6...7:   infographicCount = 2
        case 8...10:  infographicCount = 3
        case 11...14: infographicCount = 3
        case 15...17: infographicCount = 4
        case 18...20: infographicCount = 5
        case 21...25: infographicCount = 6
        case 26...30: infographicCount = 7
        case 31...35: infographicCount = 8
        case 36...40: infographicCount = 9
        default:      infographicCount = max(10, pageCount / 4)
        }
        let pagesPerChunk = max(1, Int(ceil(Double(pageCount) / Double(infographicCount))))
        let sections = groupPagesByChunk(completedPages, pagesPerChunk: pagesPerChunk)
        totalToGenerate = sections.count
        isGenerating = true

        let apiKey = APIProviderManager.staticLiveAIAPIKey
        guard !apiKey.isEmpty else {
            errorMessage = "API key not configured."
            isGenerating = false
            return
        }

        for (index, sectionText) in sections.enumerated() {
            progress = index + 1

            let prompt = """
            Create a visually striking infographic image in portrait orientation (9:16 aspect ratio) for mobile viewing.

            Topic: \(bookTitle)\(sectionTitle.isEmpty ? "" : " — \(sectionTitle)")

            Content to visualize (section \(index + 1) of \(sections.count)):
            \(sectionText)

            Design requirements:
            - Portrait/vertical layout optimized for mobile phone screens
            - Bold, clear typography with key facts and figures highlighted
            - Use icons, charts, diagrams, or illustrations to represent concepts visually
            - Professional color scheme with good contrast for readability
            - Organize information in a clear visual hierarchy
            - Include a section title or heading at the top
            - Make it educational and visually engaging
            """

            if let image = await callGeminiImageGeneration(prompt: prompt, apiKey: apiKey) {
                infographics.append(image)
            }
        }

        isGenerating = false

        if infographics.isEmpty {
            errorMessage = "Could not generate infographics. Please try again."
        }
    }

    /// Group pages into chunks of N pages each, returning combined text per chunk
    private func groupPagesByChunk(_ pages: [PageCapture], pagesPerChunk: Int) -> [String] {
        var sections: [String] = []
        let chunkSize = max(1, pagesPerChunk)

        for startIndex in stride(from: 0, to: pages.count, by: chunkSize) {
            let endIndex = min(startIndex + chunkSize, pages.count)
            let chunk = pages[startIndex..<endIndex]
            let text = chunk
                .map { $0.extractedText }
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                sections.append(text)
            }
        }

        return sections
    }

    private func callGeminiImageGeneration(prompt: String, apiKey: String) async -> UIImage? {
        let model = "gemini-3.1-flash-image-preview"
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"

        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseModalities": ["TEXT", "IMAGE"]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("❌ [Infographics] HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                print("❌ [Infographics] Failed to parse response")
                return nil
            }

            // Find the image part in the response
            for part in parts {
                if let inlineData = part["inlineData"] as? [String: Any],
                   let base64String = inlineData["data"] as? String,
                   let imageData = Data(base64Encoded: base64String),
                   let image = UIImage(data: imageData) {
                    print("✅ [Infographics] Generated image: \(image.size)")
                    return image
                }
            }

            print("⚠️ [Infographics] No image in response")
            return nil
        } catch {
            print("❌ [Infographics] Network error: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Gemini Voice Picker

struct GeminiVoice: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String

    static let all: [GeminiVoice] = [
        GeminiVoice(id: "Aoede", name: "Aoede", description: "Warm, clear female voice", icon: "person.wave.2"),
        GeminiVoice(id: "Kore", name: "Kore", description: "Bright, friendly female voice", icon: "person.wave.2"),
        GeminiVoice(id: "Puck", name: "Puck", description: "Energetic, youthful male voice", icon: "person.wave.2.fill"),
        GeminiVoice(id: "Charon", name: "Charon", description: "Deep, authoritative male voice", icon: "person.wave.2.fill"),
        GeminiVoice(id: "Fenrir", name: "Fenrir", description: "Strong, resonant male voice", icon: "person.wave.2.fill"),
    ]
}

struct GeminiVoicePickerView: View {
    @Binding var selectedVoice: String
    let accent: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(GeminiVoice.all) { voice in
                Button {
                    selectedVoice = voice.id
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: voice.icon)
                            .font(.system(size: 20))
                            .foregroundColor(voice.id == selectedVoice ? accent : .white.opacity(0.5))
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(voice.name)
                                .font(AppTypography.headline)
                                .foregroundColor(.white)
                            Text(voice.description)
                                .font(AppTypography.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        if voice.id == selectedVoice {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(accent)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.white.opacity(voice.id == selectedVoice ? 0.1 : 0.0))
            }
            .listStyle(.plain)
            .background(AppColors.memorizeBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("memorize.select_voice".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Zoomable Image View

struct ZoomableImageView: View {
    let image: UIImage
    let accent: Color

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private var isZoomed: Bool { scale > 1.05 }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .cornerRadius(AppCornerRadius.md)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(pinchGesture)
            .gesture(isZoomed ? dragGesture : nil)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3)) {
                    if isZoomed {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = lastScale * value
            }
            .onEnded { _ in
                lastScale = scale
                if scale < 1.0 {
                    withAnimation(.spring(response: 0.3)) {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
}

// MARK: - Read Aloud View (Gemini Live)

struct MemorizeReadAloudView: View {
    let pages: [PageCapture]
    let bookTitle: String
    let sectionTitle: String

    @Environment(\.dismiss) private var dismiss
    @State private var geminiService: GeminiLiveService?
    @State private var isConnected = false
    @State private var errorMessage: String?
    @AppStorage("geminiSelectedVoice") private var selectedVoice = "Aoede"
    @State private var showVoicePicker = false

    // Audio accumulation & playback tracking
    @State private var accumulatedAudio = Data()
    @State private var isStreaming = false       // Gemini is still sending audio
    @State private var isStreamDone = false      // Gemini finished sending all audio
    @State private var isPaused = false
    @State private var hasStartedPlaying = false // First audio chunk received
    @State private var playbackPosition: TimeInterval = 0
    @State private var seekTarget: TimeInterval? = nil  // Non-nil while user is dragging slider
    @State private var positionTimer: Timer?
    @State private var isSeeking = false
    @State private var seekDebounceTask: Task<Void, Never>?
    /// Timestamp when playback started/resumed (used to calculate position)
    @State private var playbackStartDate: Date?
    /// Position offset when playback started/resumed (after seek or pause)
    @State private var playbackStartOffset: TimeInterval = 0

    // Text chunking — send text in pieces to work around Gemini's ~60-90s response cap
    @State private var textChunks: [String] = []
    @State private var currentChunkIndex = 0

    // Estimated total duration based on word count (~150 words/min speaking rate)
    @State private var estimatedTotalDuration: TimeInterval = 0

    // Slider range — only grows, updated by position timer to avoid per-chunk jitter
    @State private var sliderMax: TimeInterval = 0.1

    // Soundwave animation
    @State private var barHeights: [CGFloat] = [12, 12, 12, 12, 12]
    @State private var barTimer: Timer?

    private let readAloudAccent = Color(red: 0.20, green: 0.60, blue: 0.86)
    private let barMinHeight: CGFloat = 8
    private let barMaxHeights: [CGFloat] = [36, 48, 40, 44, 32]
    private let skipInterval: TimeInterval = 15

    /// Bytes per second at 24kHz, 16-bit mono
    private let bytesPerSecond: Double = 48000

    private var totalDuration: TimeInterval {
        Double(accumulatedAudio.count) / bytesPerSecond
    }

    private var displayPosition: TimeInterval {
        seekTarget ?? playbackPosition
    }

    /// Stable max for the slider — uses estimated total while streaming, actual total when done
    private var effectiveMax: TimeInterval {
        if isStreamDone {
            return max(totalDuration, 0.1)
        }
        return max(estimatedTotalDuration, sliderMax, 0.1)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.md) {
                Spacer()

                // Artwork with soundwave bars
                ZStack {
                    Circle()
                        .fill(readAloudAccent.opacity(0.1))
                        .frame(width: 200, height: 200)

                    Circle()
                        .fill(readAloudAccent.opacity(0.18))
                        .frame(width: 160, height: 160)

                    Circle()
                        .fill(readAloudAccent.opacity(0.25))
                        .frame(width: 120, height: 120)

                    // Soundwave bars
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(readAloudAccent)
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

                if !sectionTitle.isEmpty {
                    Text(sectionTitle)
                        .font(AppTypography.subheadline)
                        .foregroundColor(readAloudAccent)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Text("memorize.read_aloud_header".localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.white.opacity(0.6))

                // Loading indicator
                if !hasStartedPlaying {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("memorize.read_aloud_loading".localized)
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

                Spacer()

                // Playback controls
                if hasStartedPlaying {
                    playbackControls
                        .padding(.horizontal, AppSpacing.md)
                }

                // Done button
                Button {
                    disconnectAndDismiss()
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
            .navigationTitle("memorize.read_aloud".localized)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showVoicePicker = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showVoicePicker) {
            GeminiVoicePickerView(selectedVoice: $selectedVoice, accent: readAloudAccent)
                .presentationDetents([.medium])
        }
        .onChange(of: selectedVoice) { newVoice in
            // Reconnect with new voice if already connected
            guard geminiService != nil else { return }
            disconnectAndReconnect()
        }
        .task {
            // Force-release any lingering audio session (voice menu speech recognizer)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            setupAndConnect()
        }
        .onChange(of: hasStartedPlaying) { playing in
            if playing && !isPaused {
                playbackPosition = 0
                playbackStartOffset = 0
                startBarTimer()
                startPositionTimer()
            }
        }
        .onDisappear {
            stopBarTimer()
            stopPositionTimer()
            geminiService?.disconnect()
            geminiService = nil
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        VStack(spacing: AppSpacing.sm) {
            // Transport controls
            HStack(spacing: AppSpacing.xl) {
                // Skip back
                Button {
                    skip(by: -skipInterval)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }

                // Play / Pause
                Button {
                    togglePlayPause()
                } label: {
                    Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundColor(readAloudAccent)
                }

                // Skip forward
                Button {
                    skip(by: skipInterval)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, AppSpacing.sm)
        }
    }

    // MARK: - Playback Actions

    private func togglePlayPause() {
        guard let service = geminiService else { return }
        if isPaused {
            service.resumePlayback()
            isPaused = false
            startBarTimer()
            startPositionTimer()  // Resets playbackStartDate/Offset from current position
        } else {
            stopPositionTimer()   // Snapshots position before pausing
            service.pausePlayback()
            isPaused = true
            stopBarTimer()
        }
    }

    private func skip(by seconds: TimeInterval) {
        let newPosition = max(0, min(playbackPosition + seconds, totalDuration))
        seek(to: newPosition)
    }

    private func seek(to position: TimeInterval) {
        guard let service = geminiService else { return }

        seekTarget = nil
        isSeeking = true

        let availableDuration = totalDuration
        let clampedPosition = max(0, min(position, availableDuration))
        let byteOffset = Int(clampedPosition * bytesPerSecond)
        let alignedOffset = byteOffset & ~1

        if alignedOffset < accumulatedAudio.count {
            service.seekAndPlay(audioData: accumulatedAudio, fromByteOffset: alignedOffset)
        }

        playbackPosition = clampedPosition
        isPaused = false
        startBarTimer()
        startPositionTimer()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            isSeeking = false
        }
    }

    // MARK: - Position Tracking

    private func startPositionTimer() {
        playbackStartDate = Date()
        playbackStartOffset = playbackPosition
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                let currentTotal = totalDuration
                if currentTotal > sliderMax {
                    sliderMax = currentTotal
                }

                guard !isPaused, let startDate = playbackStartDate else { return }
                if seekTarget != nil { return }
                let elapsed = Date().timeIntervalSince(startDate)
                playbackPosition = playbackStartOffset + elapsed
                if isStreamDone && !isSeeking && playbackPosition >= currentTotal {
                    playbackPosition = currentTotal
                    sliderMax = currentTotal
                    isPaused = true
                    playbackStartDate = nil
                    stopBarTimer()
                    stopPositionTimer()
                }
            }
        }
    }

    private func stopPositionTimer() {
        // Snapshot current position before stopping
        if let startDate = playbackStartDate {
            playbackPosition = playbackStartOffset + Date().timeIntervalSince(startDate)
        }
        playbackStartDate = nil
        positionTimer?.invalidate()
        positionTimer = nil
    }

    // MARK: - Soundwave Animation

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

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func sendNextChunk(service: GeminiLiveService) {
        guard currentChunkIndex < textChunks.count else { return }
        let chunk = textChunks[currentChunkIndex]
        currentChunkIndex += 1
        print("📖 [ReadAloud] Sending chunk \(currentChunkIndex)/\(textChunks.count) (\(chunk.count) chars)")
        service.sendTextInput("Read the following text aloud now:\n\n\(chunk)")
    }

    private func disconnectAndDismiss() {
        geminiService?.disconnect()
        geminiService = nil
        dismiss()
    }

    private func disconnectAndReconnect() {
        // Reset all state and reconnect with new voice
        geminiService?.disconnect()
        geminiService = nil
        accumulatedAudio = Data()
        isConnected = false
        hasStartedPlaying = false
        isStreaming = false
        isStreamDone = false
        isPaused = false
        playbackPosition = 0
        playbackStartOffset = 0
        playbackStartDate = nil
        sliderMax = 0.1
        currentChunkIndex = 0
        stopBarTimer()
        stopPositionTimer()
        setupAndConnect()
    }

    // MARK: - Gemini Setup

    /// Split text into chunks at paragraph/sentence boundaries
    private static func splitTextIntoChunks(_ text: String, maxChunkSize: Int = 2000) -> [String] {
        var chunks: [String] = []
        var remaining = text

        while !remaining.isEmpty {
            if remaining.count <= maxChunkSize {
                chunks.append(remaining)
                break
            }

            // Try to split at a paragraph break within the limit
            let prefix = String(remaining.prefix(maxChunkSize))
            var splitIndex: String.Index

            if let paragraphBreak = prefix.range(of: "\n\n", options: .backwards) {
                splitIndex = paragraphBreak.upperBound
            } else if let sentenceBreak = prefix.range(of: ". ", options: .backwards) {
                splitIndex = sentenceBreak.upperBound
            } else {
                // Hard split at limit
                splitIndex = remaining.index(remaining.startIndex, offsetBy: maxChunkSize)
            }

            let chunk = String(remaining[remaining.startIndex..<splitIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                chunks.append(chunk)
            }
            remaining = String(remaining[splitIndex...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return chunks
    }

    private func setupAndConnect() {
        let completedPages = pages.filter { $0.status == .completed }
        let combinedText = completedPages
            .enumerated()
            .map { "--- Page \($0.offset + 1) ---\n\($0.element.extractedText)" }
            .joined(separator: "\n\n")

        if combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "No text content available. Capture some pages first."
            return
        }

        // Split text into chunks that fit within Gemini's ~60-90s response limit
        textChunks = Self.splitTextIntoChunks(combinedText)
        currentChunkIndex = 0

        // Estimate total duration: ~150 words per minute average speaking rate
        let totalWordCount = combinedText.split(separator: " ").count
        estimatedTotalDuration = Double(totalWordCount) / 150.0 * 60.0

        print("📖 [ReadAloud] Split into \(textChunks.count) chunks, ~\(totalWordCount) words, est. \(Int(estimatedTotalDuration))s")

        let systemPrompt = """
        You are a professional narrator reading text aloud.

        Guidelines:
        1. Read the text exactly as written — do NOT summarize, paraphrase, or add commentary
        2. Use clear, natural pacing with appropriate pauses at paragraph breaks
        3. Pronounce words carefully and articulate clearly
        4. Use natural intonation — not monotone, but don't be overly dramatic
        5. Do NOT add any introduction, greeting, or closing remarks — just read the text
        6. When you receive text, begin reading it immediately
        """

        let apiKey = APIProviderManager.staticLiveAIAPIKey

        let service = GeminiLiveService(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            includeTools: false
        )
        service.playbackOnly = true
        service.isMicMuted = true
        service.voiceName = selectedVoice

        service.onConnected = { [service] in
            Task { @MainActor in
                isConnected = true
                service.isMicMuted = true
                try? await Task.sleep(nanoseconds: 300_000_000)
                // Send first chunk
                sendNextChunk(service: service)
            }
        }

        // Accumulate raw PCM audio for seeking
        service.onAudioDelta = { (audioData: Data) in
            Task { @MainActor in
                accumulatedAudio.append(audioData)
                if !hasStartedPlaying {
                    hasStartedPlaying = true
                    isStreaming = true
                }
            }
        }

        service.onTranscriptDelta = { (_: String) in }
        service.onTranscriptDone = { (_: String) in }

        service.onAudioDone = { [service] in
            Task { @MainActor in
                // Small delay to let audio finish playing
                try? await Task.sleep(nanoseconds: 300_000_000)

                if currentChunkIndex < textChunks.count {
                    // More chunks to read
                    print("📖 [ReadAloud] Chunk done, sending next (\(currentChunkIndex + 1)/\(textChunks.count))")
                    sendNextChunk(service: service)
                } else {
                    // All chunks sent and audio done
                    print("📖 [ReadAloud] All \(textChunks.count) chunks complete")
                    isStreaming = false
                    isStreamDone = true
                }
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
}

// MARK: - Podcast Mode Picker

struct PodcastModePickerView: View {
    let onSelect: (PodcastMode) -> Void
    @Environment(\.dismiss) private var dismiss
    private let podcastAccent = Color(red: 0.64, green: 0.21, blue: 0.83)

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Podcast Mode")
                .font(AppTypography.title2)
                .foregroundColor(.white)
                .padding(.top, AppSpacing.lg)

            VStack(spacing: AppSpacing.md) {
                Button {
                    onSelect(.play)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Play")
                                .font(AppTypography.headline)
                            Text("Listen with playback controls")
                                .font(AppTypography.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .foregroundColor(.white)
                    .padding(AppSpacing.md)
                    .background(podcastAccent.opacity(0.25))
                    .cornerRadius(AppCornerRadius.md)
                }

                Button {
                    onSelect(.interactive)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Interactive")
                                .font(AppTypography.headline)
                            Text("Interrupt and talk to the host")
                                .font(AppTypography.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .foregroundColor(.white)
                    .padding(AppSpacing.md)
                    .background(podcastAccent.opacity(0.25))
                    .cornerRadius(AppCornerRadius.md)
                }
            }
            .padding(.horizontal, AppSpacing.md)

            Spacer()
        }
        .background(AppColors.memorizeBackground.ignoresSafeArea())
    }
}

// MARK: - Podcast Player View (Gemini Live)

struct MemorizePodcastPlayerView: View {
    let pages: [PageCapture]
    let bookTitle: String
    let sectionTitle: String
    let mode: PodcastMode
    let usesPDFLengthHeuristic: Bool
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var geminiService: GeminiLiveService?
    @State private var isConnected = false
    @State private var isRecording = false
    @State private var isMuted = true
    @State private var listenerQuestionArmed = false
    @State private var isAnsweringListenerQuestion = false
    @State private var pendingListenerTranscript = ""
    @State private var listenerTranscriptTask: Task<Void, Never>?
    @State private var lastMicRearmTime: Date?
    @State private var questionAnsweredAt: Date?
    @State private var errorMessage: String?
    @State private var micLevel: Float = 0
    @AppStorage("geminiSelectedVoice") private var selectedVoice = "Aoede"
    @State private var showVoicePicker = false

    // Audio accumulation & playback tracking
    @State private var accumulatedAudio = Data()
    @State private var hasStartedPlaying = false
    @State private var isStreamDone = false
    @State private var isPaused = false
    @State private var playbackPosition: TimeInterval = 0
    @State private var seekTarget: TimeInterval? = nil
    @State private var scrubPosition: TimeInterval = 0
    @State private var isScrubbing = false
    @State private var positionTimer: Timer?
    @State private var playbackStartDate: Date?
    @State private var playbackStartOffset: TimeInterval = 0
    @State private var sliderMax: TimeInterval = 0.1
    @State private var isSeeking = false
    @State private var seekDebounceTask: Task<Void, Never>?

    @State private var estimatedTotalDuration: TimeInterval = 0

    // Transcript tracking for play mode
    @State private var transcriptSegments: [(time: TimeInterval, text: String)] = []
    @State private var currentTranscriptText = ""
    @State private var transcriptStartTime: Date?
    @State private var isWaitingForSeekAudio = false
    @State private var currentAudioTimelineStart: TimeInterval = 0
    @State private var pendingPodcastLaunchPrompt: String?

    // Soundwave animation
    @State private var barHeights: [CGFloat] = [12, 12, 12, 12, 12]
    @State private var barTimer: Timer?

    private let podcastAccent = Color(red: 0.64, green: 0.21, blue: 0.83)
    private let barMinHeight: CGFloat = 8
    private let barMaxHeights: [CGFloat] = [36, 48, 40, 44, 32]
    private let skipInterval: TimeInterval = 15
    private let bytesPerSecond: Double = 48000
    private let wordsPerPodcastMinute = 170.0

    private var completedPages: [PageCapture] {
        pages.filter { $0.status == .completed }
    }

    private var sourceWordCount: Int {
        completedPages.reduce(0) { total, page in
            total + page.extractedText
                .split { $0.isWhitespace || $0.isNewline }
                .count
        }
    }

    private var targetLengthStrategyLabel: String {
        usesPDFLengthHeuristic ? "page_based" : "word_based"
    }

    private var targetPodcastMinutes: Int {
        if usesPDFLengthHeuristic {
            return max(4, completedPages.count * 2)
        }

        let estimatedMinutes = Int(ceil(Double(max(sourceWordCount, 1)) / wordsPerPodcastMinute))
        return max(4, estimatedMinutes)
    }

    private var startupLoadingText: String {
        switch mode {
        case .play:
            return "memorize.podcast_loading_play".localized
        case .interactive:
            return "memorize.podcast_loading_interactive".localized
        }
    }

    private var totalDuration: TimeInterval {
        Double(accumulatedAudio.count) / bytesPerSecond
    }

    private var displayPosition: TimeInterval {
        isScrubbing ? scrubPosition : (seekTarget ?? playbackPosition)
    }

    private var effectiveMax: TimeInterval {
        return max(estimatedTotalDuration, totalDuration, 0.1)
    }

    private var availableTimelineEnd: TimeInterval {
        currentAudioTimelineStart + totalDuration
    }

    private let tealAccent = Color(red: 0.18, green: 0.55, blue: 0.53)
    private let coralAccent = Color(red: 0.89, green: 0.36, blue: 0.35)

    var body: some View {
        NavigationView {
            if mode == .interactive {
                interactiveBody
            } else {
                playBody
            }
        }
        .sheet(isPresented: $showVoicePicker) {
            GeminiVoicePickerView(selectedVoice: $selectedVoice, accent: mode == .interactive ? tealAccent : podcastAccent)
                .presentationDetents([.medium])
        }
        .onChange(of: selectedVoice) { newVoice in
            guard geminiService != nil else { return }
            podcastReconnectWithNewVoice()
        }
        .task {
            let modeLabel = mode == .interactive ? "interactive" : "play"
            print("🎙️ [MemorizePodcast] View task started mode=\(modeLabel) target length=\(targetPodcastMinutes) min strategy=\(targetLengthStrategyLabel) words=\(sourceWordCount) pages=\(completedPages.count)")
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            try? await Task.sleep(nanoseconds: 500_000_000)
            setupAndConnect()
        }
        .onChange(of: hasStartedPlaying) { playing in
            if playing && !isPaused {
                playbackPosition = 0
                scrubPosition = 0
                playbackStartOffset = 0
                startBarTimer()
                startPositionTimer()
            }
        }
        .onChange(of: playbackPosition) { newPosition in
            guard !isScrubbing else { return }
            scrubPosition = min(newPosition, effectiveMax)
        }
        .onDisappear {
            stopBarTimer()
            stopPositionTimer()
            geminiService?.disconnect()
            geminiService = nil
        }
    }

    // MARK: - Interactive Body

    private var interactiveBody: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()

            // "AI-Generated Summary" pill
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                Text("Interactive Podcast")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(tealAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(tealAccent.opacity(0.15))
            .cornerRadius(20)

            // Title
            Text(bookTitle)
                .font(AppTypography.title2)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, AppSpacing.lg)

            if !sectionTitle.isEmpty {
                Text(sectionTitle)
                    .font(AppTypography.subheadline)
                    .foregroundColor(tealAccent)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Loading indicator
            if !hasStartedPlaying {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                    Text(startupLoadingText)
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

            // Audio waveform visualization
            if hasStartedPlaying {
                interactiveWaveform
                    .frame(height: 80)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.sm)
            }

            Spacer()

            // Large circular "TAP TO INTERRUPT" button
            interactiveMicButton

            Spacer()

            // Bottom playback controls
            if hasStartedPlaying {
                interactivePlaybackControls
                    .padding(.bottom, AppSpacing.lg)
            }

            // Done button
            Button {
                disconnectAndDismiss()
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showVoicePicker = true
                } label: {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.white)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Play Body (original dark theme)

    private var playBody: some View {
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

            if !sectionTitle.isEmpty {
                Text(sectionTitle)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.memorizeAccent)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Text("memorize.podcast_header".localized)
                .font(AppTypography.subheadline)
                .foregroundColor(Color.white.opacity(0.6))

            // Loading indicator
            if !hasStartedPlaying {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                    Text(startupLoadingText)
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

            Spacer()

            // Playback controls
            if hasStartedPlaying {
                podcastPlaybackControls
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xl)
            }

            // Done button
            Button {
                disconnectAndDismiss()
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showVoicePicker = true
                } label: {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.white)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Interactive Waveform

    private func waveformBarColor(at index: Int, of total: Int) -> Color {
        let t = Double(index) / Double(total - 1)
        // Coral (0.89, 0.36, 0.35) → Teal (0.18, 0.55, 0.53)
        return Color(
            red: 0.89 * (1.0 - t) + 0.18 * t,
            green: 0.36 * (1.0 - t) + 0.55 * t,
            blue: 0.35 * (1.0 - t) + 0.53 * t
        )
    }

    private var interactiveWaveform: some View {
        let totalBars = 25
        return HStack(spacing: 2.5) {
            ForEach(0..<totalBars, id: \.self) { i in
                let barColor = waveformBarColor(at: i, of: totalBars)
                // Height varies — taller in center, shorter at edges
                let centerDistance = abs(CGFloat(i) - 12.0) / 12.0
                let baseHeight: CGFloat = hasStartedPlaying && !isPaused ? (1.0 - centerDistance * 0.6) : 0.15
                let randomFactor = barHeights[i % 5] / barMaxHeights[i % 5]
                let height = max(6, baseHeight * randomFactor * 70)

                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: 4, height: height)
                    .animation(.easeInOut(duration: 0.3), value: barHeights[i % 5])
            }
        }
    }

    // MARK: - Interactive Mic Button

    private var interactiveMicButton: some View {
        Button {
            guard isConnected, let service = geminiService else { return }
            if listenerQuestionArmed && !isMuted {
                // Already armed — mute
                service.isMicMuted = true
                service.activatePlaybackOnlyMode()
                isRecording = false
                isMuted = true
                listenerQuestionArmed = false
                pendingListenerTranscript = ""
                listenerTranscriptTask?.cancel()
            } else {
                // Interrupt and arm mic — set isAnsweringListenerQuestion
                // immediately so the onAudioDone from the interrupted
                // podcast doesn't trigger the continuation path.
                isAnsweringListenerQuestion = true
                service.activateConversationMode(startRecordingIfNeeded: true)
                service.interruptPlayback(expectServerInterruption: true)
                service.sendSilentAudioToInterrupt()
                rearmInteractivePodcastMic(service, activateConversation: false)
            }
        } label: {
            ZStack {
                // Outer glow rings
                Circle()
                    .fill(tealAccent.opacity(0.06))
                    .frame(width: 200, height: 200)

                Circle()
                    .fill(tealAccent.opacity(0.10))
                    .frame(width: 170, height: 170)

                // Main circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tealAccent.opacity(0.9), tealAccent.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: tealAccent.opacity(0.4), radius: 16, y: 4)

                // Ring
                Circle()
                    .stroke(tealAccent.opacity(0.5), lineWidth: 2)
                    .frame(width: 142, height: 142)

                // Icon + label
                VStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)

                    Text(listenerQuestionArmed && !isMuted ? "LISTENING" : "TAP TO INTERRUPT")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .disabled(!isConnected || !hasStartedPlaying)
        .opacity(!isConnected || !hasStartedPlaying ? 0.4 : 1.0)
    }

    // MARK: - Interactive Playback Controls

    private var interactivePlaybackControls: some View {
        Button { togglePodcastPlayPause() } label: {
            Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                .font(.system(size: 56, weight: .medium))
                .foregroundColor(tealAccent)
        }
    }

    // MARK: - Playback Controls

    private var podcastPlaybackControls: some View {
        VStack(spacing: AppSpacing.sm) {
            // Scrub bar
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { displayPosition },
                        set: { newValue in
                            scrubPosition = newValue
                            if !isScrubbing {
                                isScrubbing = true
                            }
                        }
                    ),
                    in: 0...effectiveMax,
                    onEditingChanged: { editing in
                        if !editing {
                            isScrubbing = false
                            podcastSeek(to: scrubPosition)
                        }
                    }
                )
                .tint(podcastAccent)

                HStack {
                    Text(formatTime(displayPosition))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                    Spacer()
                    Text(formatTime(effectiveMax))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }

            if isWaitingForSeekAudio {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(podcastAccent)
                        .scaleEffect(0.75)
                    Text("Jumping to \(formatTime(displayPosition))... transcript catching up.")
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppSpacing.xs)
            }

            // Playback controls
            HStack(spacing: AppSpacing.xl) {
                Button { podcastSkip(by: -skipInterval) } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }

                Button { togglePodcastPlayPause() } label: {
                    Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundColor(podcastAccent)
                }

                Button { podcastSkip(by: skipInterval) } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, AppSpacing.sm)
        }
    }

    // MARK: - Playback Actions

    private func togglePodcastPlayPause() {
        guard let service = geminiService else { return }
        if isPaused {
            service.resumePlayback()
            isPaused = false
            startBarTimer()
            startPositionTimer()
        } else {
            stopPositionTimer()
            service.pausePlayback()
            isPaused = true
            stopBarTimer()
        }
    }

    private func podcastSkip(by seconds: TimeInterval) {
        let current = isScrubbing ? scrubPosition : playbackPosition
        let newPosition = max(0, min(current + seconds, effectiveMax))
        podcastSeek(to: newPosition)
    }

    private func podcastSeek(to position: TimeInterval) {
        guard let service = geminiService else { return }
        let clampedPosition = max(0, min(position, effectiveMax))
        seekTarget = clampedPosition
        isSeeking = true
        scrubPosition = clampedPosition

        if clampedPosition >= currentAudioTimelineStart && clampedPosition <= availableTimelineEnd {
            let localOffset = clampedPosition - currentAudioTimelineStart
            let byteOffset = Int(localOffset * bytesPerSecond)
            let alignedOffset = byteOffset & ~1

            if alignedOffset < accumulatedAudio.count {
                service.seekAndPlay(audioData: accumulatedAudio, fromByteOffset: alignedOffset)
            } else {
                service.resumePlayback()
            }

            seekTarget = nil
            isWaitingForSeekAudio = false
            playbackPosition = clampedPosition
            isPaused = false
            startBarTimer()
            startPositionTimer()
        } else {
            jumpPodcast(to: clampedPosition)
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            isSeeking = false
        }
    }

    // MARK: - Position Tracking

    private func startPositionTimer() {
        playbackStartDate = Date()
        playbackStartOffset = playbackPosition
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                let currentTimelineEnd = availableTimelineEnd
                if currentTimelineEnd > sliderMax { sliderMax = currentTimelineEnd }
                guard !isPaused, !isScrubbing, let startDate = playbackStartDate else { return }
                // Don't update position while user is dragging the slider
                if seekTarget != nil { return }
                
                let elapsed = Date().timeIntervalSince(startDate)
                var newPos = playbackStartOffset + elapsed
                
                if newPos >= currentTimelineEnd {
                    newPos = currentTimelineEnd
                    // Shift base to prevent jumping ahead when more audio arrives
                    playbackStartOffset = currentTimelineEnd
                    playbackStartDate = Date()
                    
                    if isStreamDone && !isSeeking {
                        playbackPosition = currentTimelineEnd
                        sliderMax = currentTimelineEnd
                        isPaused = true
                        playbackStartDate = nil
                        stopBarTimer()
                        stopPositionTimer()
                        return
                    }
                }
                playbackPosition = newPos
            }
        }
    }

    private func stopPositionTimer() {
        if let startDate = playbackStartDate {
            playbackPosition = playbackStartOffset + Date().timeIntervalSince(startDate)
        }
        playbackStartDate = nil
        positionTimer?.invalidate()
        positionTimer = nil
    }

    // MARK: - Mic, Bars, Helpers

    private func rearmInteractivePodcastMic(_ service: GeminiLiveService, activateConversation: Bool = true) {
        guard mode == .interactive else { return }
        if activateConversation {
            service.activateConversationMode(startRecordingIfNeeded: true)
        }
        service.isMicMuted = false
        isRecording = true
        isMuted = false
        listenerQuestionArmed = true
        lastMicRearmTime = Date()
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

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func disconnectAndDismiss() {
        geminiService?.disconnect()
        geminiService = nil
        dismiss()
        onClose()
    }

    private func jumpPodcast(to targetPosition: TimeInterval) {
        let clampedPosition = max(0, min(targetPosition, effectiveMax))
        print("⏩ [MemorizePodcast] Jumping to \(formatTime(clampedPosition)) of \(formatTime(effectiveMax))")

        geminiService?.disconnect()
        geminiService = nil
        isConnected = false
        isRecording = false
        isStreamDone = false
        isPaused = true
        isWaitingForSeekAudio = true
        currentAudioTimelineStart = clampedPosition
        pendingPodcastLaunchPrompt = podcastLaunchPrompt(startingAt: clampedPosition)
        accumulatedAudio = Data()
        playbackPosition = clampedPosition
        scrubPosition = clampedPosition
        playbackStartOffset = clampedPosition
        playbackStartDate = nil
        seekTarget = clampedPosition
        currentTranscriptText = ""
        transcriptStartTime = nil
        stopBarTimer()
        stopPositionTimer()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            setupAndConnect()
        }
    }

    private func podcastLaunchPrompt(startingAt startTime: TimeInterval = 0) -> String {
        if startTime <= 1 {
            return "Begin the podcast now. Start with your intro and dive deep into the content. You have \(targetPodcastMinutes) minutes."
        }

        let remainingSeconds = max(0, estimatedTotalDuration - startTime)
        let remainingMinutes = max(1, Int(ceil(remainingSeconds / 60.0)))

        return """
        Continue this podcast from around \(formatTime(startTime)) into the episode.
        Do not restart the introduction or repeat earlier sections.
        Smoothly jump ahead as if the earlier part already played, and continue with the next major idea.
        You have about \(remainingMinutes) minutes left in the episode.
        """
    }

    private func podcastReconnectWithNewVoice() {
        geminiService?.disconnect()
        geminiService = nil
        accumulatedAudio = Data()
        isConnected = false
        hasStartedPlaying = false
        isStreamDone = false
        isPaused = false
        playbackPosition = 0
        scrubPosition = 0
        isScrubbing = false
        playbackStartOffset = 0
        playbackStartDate = nil
        sliderMax = 0.1
        currentAudioTimelineStart = 0
        pendingPodcastLaunchPrompt = nil
        stopBarTimer()
        stopPositionTimer()
        isWaitingForSeekAudio = false
        setupAndConnect()
    }

    // MARK: - Gemini Setup

    private func setupAndConnect() {
        let sourceContext = buildMemorizeLiveSourceContext(
            from: completedPages,
            maxPages: 20,
            maxCharsPerPage: 8000,
            maxTotalChars: 60000
        )

        if sourceContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "No text content available. Capture some pages first."
            return
        }

        // Scale podcast duration by page count: 2 min per page, minimum 4 min
        let pageCount = completedPages.count
        let targetMinutes = targetPodcastMinutes
        estimatedTotalDuration = Double(targetMinutes) * 60.0
        print("🎙️ [MemorizePodcast] Loaded target length: \(targetMinutes) min (\(Int(estimatedTotalDuration))s) strategy=\(targetLengthStrategyLabel) words=\(sourceWordCount) pages=\(pageCount)")

        // Track how many continuation prompts we've sent
        var continuationCount = 0
        let maxContinuations = max(1, targetMinutes / 2)  // ~2 min per response from Gemini

        // Keep system prompt lean — source text goes in the launch prompt
        // to avoid Gemini Live API system instruction size limits.
        let systemPrompt = """
        You are the host of an engaging educational podcast called "Deep Dive". You have a warm, enthusiastic personality.

        Your task: Create a compelling podcast episode discussing reading material that will be provided to you.

        Guidelines for your podcast:
        1. Start with a brief, energetic intro: "Welcome to Deep Dive! Today we're exploring..."
        2. Present the key ideas, themes, and insights from the text in a conversational, engaging way
        3. Use a dynamic speaking style — vary your tone, add emphasis, use rhetorical questions
        4. Break down complex ideas into digestible explanations with real-world analogies
        5. Highlight surprising or particularly interesting points from the text
        6. Add your own analysis and connections between ideas
        7. End with a brief wrap-up summarizing the main takeaways

        Speak naturally as if recording a real podcast episode. Be enthusiastic but not over the top.
        Do NOT mention that you are an AI. Speak as a human podcast host would.
        \(mode == .interactive ? """

        INTERACTIVE MODE RULES:
        - If the listener interrupts with a spoken question, immediately pause the podcast and answer the listener directly.
        - ALWAYS base your answer on the reading material. Search through the ENTIRE text to find the relevant information.
        - If the listener asks about a specific item (e.g. "what is step 5", "the third mistake"), find and cite that exact content from the text.
        - Answer in a concise, natural way.
        - After answering, immediately resume the podcast from where you left off. Do not ask if the listener wants to continue — just smoothly transition back.
        """ : "")
        """

        print("⚡️ [MemorizePodcast] Live context chars: \(sourceContext.count)")

        let apiKey = APIProviderManager.staticLiveAIAPIKey

        let service = GeminiLiveService(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            includeTools: false
        )
        service.voiceName = selectedVoice

        service.onConnected = { [service] in
            Task { @MainActor in
                isConnected = true
                // Start in playback-only for the launch prompt audio.
                // For interactive mode the mic button shows "TAP TO INTERRUPT"
                // from the start — it will fully arm once the user taps.
                service.activatePlaybackOnlyMode()
                service.isMicMuted = true
                isRecording = false
                isMuted = mode != .interactive
                listenerQuestionArmed = false
                isAnsweringListenerQuestion = false
                pendingListenerTranscript = ""
                listenerTranscriptTask?.cancel()
                questionAnsweredAt = nil
                try? await Task.sleep(nanoseconds: 300_000_000)
                // Send the full source text as a regular message (not system prompt)
                // to avoid Gemini Live API system instruction size limits.
                service.sendTextInput("""
                Here is the reading material from "\(bookTitle)"\(sectionTitle.isEmpty ? "" : " — section: \(sectionTitle)"):

                ---
                \(sourceContext)
                ---

                Memorize this entire text. You will need to reference ALL of it — including specific numbered items — when the listener asks questions.
                The episode should be about \(targetMinutes) minutes long.
                """)
                try? await Task.sleep(nanoseconds: 500_000_000)
                let launchPrompt = pendingPodcastLaunchPrompt ?? podcastLaunchPrompt()
                pendingPodcastLaunchPrompt = nil
                service.sendTextInput(launchPrompt)
            }
        }

        service.onUserTranscript = { (userText: String) in
            Task { @MainActor in
                let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                guard mode == .interactive, listenerQuestionArmed else { return }

                // Ignore transcripts that arrive shortly after a mic rearm —
                // these are echo from the AI's own speech being picked up.
                if let rearm = lastMicRearmTime, Date().timeIntervalSince(rearm) < 1.5 {
                    print("🎙️ [Podcast] Ignoring likely echo transcript: \(trimmed)")
                    return
                }

                // On the very first fragment, interrupt any in-progress AI
                // audio and switch to playback-only so Gemini doesn't
                // auto-respond to partial audio while we collect the full
                // utterance.
                // On first fragment: interrupt the podcast audio but keep
                // the mic OPEN so Gemini hears the full question.
                // The mic will be muted when the debounce fires.
                if pendingListenerTranscript.isEmpty {
                    service.interruptPlayback(expectServerInterruption: true)
                    service.sendSilentAudioToInterrupt()
                    isMuted = true
                    isAnsweringListenerQuestion = true
                }

                // Accumulate streaming transcript fragments and debounce
                // so the full utterance is captured before acting.
                let needsSpace = !pendingListenerTranscript.isEmpty
                    && !pendingListenerTranscript.hasSuffix(" ")
                    && !trimmed.hasPrefix(" ")
                pendingListenerTranscript += (needsSpace ? " " : "") + trimmed

                // Debounce: after 1.5s of silence, interrupt Gemini's
                // voice-triggered response and re-send as a text prompt
                // so the AI properly searches the full reading material.
                listenerTranscriptTask?.cancel()
                listenerTranscriptTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard !Task.isCancelled else { return }

                    let fullQuestion = pendingListenerTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                    pendingListenerTranscript = ""
                    listenerQuestionArmed = false
                    guard !fullQuestion.isEmpty else { return }

                    // Now mute the mic and interrupt Gemini's voice response
                    service.isMicMuted = true
                    service.activatePlaybackOnlyMode()
                    isRecording = false
                    service.interruptPlayback(expectServerInterruption: true)
                    service.sendSilentAudioToInterrupt()
                    // Re-set the flag so the text prompt's onAudioDone
                    // is handled correctly (the interrupted voice response
                    // may have already consumed the first flag).
                    isAnsweringListenerQuestion = true
                    questionAnsweredAt = nil

                    let normalized = fullQuestion.lowercased()
                    let isResumeRequest =
                        normalized == "continue"
                        || normalized == "resume"
                        || normalized.contains("continue the podcast")
                        || normalized.contains("resume the podcast")
                        || normalized.contains("keep going")

                    if isResumeRequest {
                        isAnsweringListenerQuestion = false
                        print("🎙️ [Podcast] Listener requested resume")
                        service.sendTextInput(
                            """
                            Resume the podcast now from exactly where you left off before the listener interruption.
                            Do not restart the episode or repeat the introduction.
                            Continue naturally with the next idea from the reading.
                            """
                        )
                    } else {
                        print("🎙️ [Podcast] Listener question: \(fullQuestion)")
                        service.sendTextInput(
                            """
                            The listener asked: "\(fullQuestion)"

                            IMPORTANT: Search through the ENTIRE reading material to find the answer.
                            If the question asks about a numbered item (step, mistake, point, etc.), locate that exact item in the text and quote or paraphrase it.
                            Answer directly and concisely based on the reading material.
                            Do not say the information is not available if it exists in the text.
                            After answering, immediately resume the podcast from exactly where you left off before the interruption. Transition smoothly back.
                            """
                        )
                    }
                }
            }
        }

        // Accumulate raw PCM audio for seeking
        service.onAudioDelta = { (audioData: Data) in
            Task { @MainActor in
                accumulatedAudio.append(audioData)
                let timelineEnd = availableTimelineEnd
                let wasAtEnd = playbackPosition >= timelineEnd - 0.1

                if !hasStartedPlaying {
                    hasStartedPlaying = true
                }
                if isStreamDone { // Un-mark done since more audio arrived
                    isStreamDone = false
                }
                if let pendingSeek = seekTarget,
                   pendingSeek >= currentAudioTimelineStart,
                   pendingSeek <= timelineEnd {
                    let localOffset = pendingSeek - currentAudioTimelineStart
                    let byteOffset = Int(localOffset * bytesPerSecond)
                    let alignedOffset = byteOffset & ~1
                    service.seekAndPlay(audioData: accumulatedAudio, fromByteOffset: alignedOffset)
                    playbackPosition = pendingSeek
                    scrubPosition = pendingSeek
                    seekTarget = nil
                    isWaitingForSeekAudio = false
                    isPaused = false
                    startBarTimer()
                    startPositionTimer()
                } else if isPaused && wasAtEnd && !isWaitingForSeekAudio {
                    // Auto-resume if it stalled waiting for chunks
                    isPaused = false
                    startBarTimer()
                    startPositionTimer()
                }
            }
        }

        service.onTranscriptDelta = { (delta: String) in
            Task { @MainActor in
                guard mode == .play else { return }
                let cleaned = delta.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return }
                if cleaned.hasPrefix(currentTranscriptText) && cleaned.count > currentTranscriptText.count {
                    currentTranscriptText = cleaned
                } else if currentTranscriptText.isEmpty || !cleaned.hasPrefix(currentTranscriptText) {
                    if currentTranscriptText.isEmpty {
                        currentTranscriptText = cleaned
                    } else {
                        let needsSpace = !currentTranscriptText.hasSuffix(" ") && !cleaned.hasPrefix(" ")
                        currentTranscriptText += (needsSpace ? " " : "") + cleaned
                    }
                }
            }
        }

        service.onTranscriptDone = { (_: String) in
            Task { @MainActor in
                guard mode == .play else { return }
                let text = currentTranscriptText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    transcriptSegments.append((time: playbackPosition, text: text))
                }
                currentTranscriptText = ""
            }
        }

        service.onAudioDone = { [service] in
            Task { @MainActor in
                // After answering a listener question, the AI auto-resumes
                // the podcast. Clear the flag and fall through to the
                // normal continuation path.
                if mode == .interactive && isAnsweringListenerQuestion {
                    print("🎙️ [Podcast] Finished answering + auto-resume segment")
                    isAnsweringListenerQuestion = false
                    questionAnsweredAt = Date()
                    // Fall through to continuation below
                }

                // Grace period: Gemini may fire a second turnComplete
                // (one for the voice-input response, one for the text prompt).
                // Absorb it so it doesn't trigger the continuation path.
                if mode == .interactive, let answered = questionAnsweredAt,
                   Date().timeIntervalSince(answered) < 3.0 {
                    print("🎙️ [Podcast] Ignoring duplicate turnComplete within question grace period")
                    questionAnsweredAt = nil
                    return
                }

                continuationCount += 1
                let elapsedMinutes = availableTimelineEnd / 60.0

                if elapsedMinutes < Double(targetMinutes) - 0.5 && continuationCount < maxContinuations {
                    // Not enough content yet — ask Gemini to continue
                    let remainingMinutes = Int(Double(targetMinutes) - elapsedMinutes)
                    print("🎙️ [Podcast] \(String(format: "%.1f", elapsedMinutes))min elapsed, target \(targetMinutes)min — requesting continuation")
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    service.sendTextInput("Continue the podcast. You still have about \(remainingMinutes) minutes. Keep discussing the material — go deeper into the details, share more insights, and cover points you haven't addressed yet. Do NOT wrap up or say goodbye yet.")
                } else {
                    print("🎙️ [Podcast] Done — \(String(format: "%.1f", elapsedMinutes))min total")
                    isStreamDone = true
                }
            }
        }

        service.onError = { (errorText: String) in
            Task { @MainActor in
                errorMessage = errorText
            }
        }

        service.onMicLevel = { level in
            Task { @MainActor in
                micLevel = level
            }
        }

        geminiService = service
        service.connect()
    }
}

// MARK: - Mic Waveform View

struct MicWaveformView: View {
    let level: Float
    let accent: Color
    private let barCount = 7

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                let distance = abs(Float(i) - Float(barCount) / 2.0) / (Float(barCount) / 2.0)
                let barLevel = max(0.08, CGFloat(level) * CGFloat(1.0 - distance * 0.5))

                RoundedRectangle(cornerRadius: 2)
                    .fill(accent.opacity(0.5 + Double(level) * 0.5))
                    .frame(width: 4, height: max(4, barLevel * 40))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }
}

struct ProcessingBarIndicator: View {
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

struct MemorizeVoiceSummaryView: View {
    let pages: [PageCapture]
    let bookTitle: String
    let sectionTitle: String

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
            Text(sectionTitle.isEmpty ? bookTitle : "\(bookTitle) — \(sectionTitle)")
                .font(AppTypography.caption)
                .foregroundColor(Color.white.opacity(0.55))
                .lineLimit(2)

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

struct MemorizeExplainView: View {
    @ObservedObject var viewModel: MemorizeCaptureViewModel
    let bookTitle: String
    let sectionTitle: String
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
    @State private var hasDeliveredOpeningExplanation = false
    @State private var userQuestionMuteTask: Task<Void, Never>?
    @AppStorage("geminiSelectedVoice") private var selectedVoice = "Aoede"
    @State private var showVoicePicker = false
    private let explainAccent = Color(red: 0.94, green: 0.55, blue: 0.24)
    private let questionEndMuteDelayNanoseconds: UInt64 = 450_000_000

    private var isStartingSummary: Bool {
        isConnected &&
        messages.isEmpty &&
        currentAIText.isEmpty &&
        currentUserText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isAIThinking
    }

    private var shouldShowStartupCard: Bool {
        (!isConnected && !viewModel.isGeneratingExplanation) || isStartingSummary
    }

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

                Text(sectionTitle.isEmpty ? bookTitle : "\(bookTitle) — \(sectionTitle)")
                    .font(AppTypography.caption)
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(2)
                    .padding(.horizontal, AppSpacing.md)

                // Show generating state before Gemini connects
                if viewModel.isGeneratingExplanation && viewModel.explanationText.isEmpty {
                    generatingCard
                        .padding(.horizontal, AppSpacing.md)
                } else if shouldShowStartupCard {
                    startupStatusCard(text: isStartingSummary ? "memorize.explain_starting".localized : "memorize.explain_connecting".localized)
                        .padding(.horizontal, AppSpacing.md)
                } else {
                    conversationCard
                        .padding(.horizontal, AppSpacing.md)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showVoicePicker = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showVoicePicker) {
            GeminiVoicePickerView(selectedVoice: $selectedVoice, accent: explainAccent)
                .presentationDetents([.medium])
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
        .onChange(of: selectedVoice) { _ in
            guard geminiService != nil else { return }
            let text = viewModel.explanationText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            explainReconnectWithNewVoice(summaryText: text)
        }
    }

    private func disconnectAndDismiss() {
        userQuestionMuteTask?.cancel()
        geminiService?.disconnect()
        geminiService = nil
        dismiss()
        onClose()
    }

    private func explainReconnectWithNewVoice(summaryText: String) {
        geminiService?.disconnect()
        geminiService = nil
        isConnected = false
        isRecording = false
        messages = []
        currentAIText = ""
        currentUserText = ""
        isAIThinking = false
        hasDeliveredOpeningExplanation = false
        userQuestionMuteTask?.cancel()
        errorMessage = nil
        setupAndConnect(summaryText: summaryText)
    }

    // MARK: - Setup

    private func setupAndConnect(summaryText: String) {
        let sourceContext = buildMemorizeLiveSourceContext(
            from: pages,
            maxPages: 6,
            maxCharsPerPage: 300,
            maxTotalChars: 3200
        )
        let compactSummary = clippedMemorizeLiveText(summaryText, maxChars: 1800)
        let personaInstruction = viewModel.explanationPersona.promptInstruction

        let systemPrompt = """
        You are a friendly reading tutor summarizing a book for a student. Explain as if the student is \(personaInstruction)

        The student has read the following reference notes from "\(bookTitle)"\(sectionTitle.isEmpty ? "" : " — section: \(sectionTitle)"):

        ---
        \(sourceContext)
        ---

        Here is a written persona summary that was prepared:

        ---
        \(compactSummary)
        ---

        Your task:
        1. Your first response must be a persona-based explanation of the source material, not a question.
        2. Use the prepared summary and source notes to give a clear spoken summary in the selected persona's style.
        3. Do not ask the student anything in your first response.
        4. After finishing that explanation, pause and wait silently for the student.
        5. Then answer any follow-up questions the student asks, drawing from the original text and the summary.
        6. If the student asks for a quick recap, answer in 1-2 short sentences first.

        Keep your responses concise and conversational. Speak clearly and at a pace suitable for learning.
        Your opening response should feel like diving straight into the summary of the material.
        Do not apologize. Do not mention that you are an AI unless asked.
        Do not open with a question. Do not proactively ask a follow-up question after the explanation unless the student asks you to continue.
        The first spoken line should begin with the explanation itself, not with a greeting, check-in, or prompt to the student.
        """

        print("⚡️ [MemorizeExplain] Live context chars: \(sourceContext.count), summary chars: \(compactSummary.count)")

        let apiKey = APIProviderManager.staticLiveAIAPIKey
        let service = GeminiLiveService(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            includeTools: false
        )
        service.voiceName = selectedVoice
        service.preferSpeakerInConversation = true

        service.onConnected = { [service] in
            Task { @MainActor in
                isConnected = true
                hasDeliveredOpeningExplanation = false
                // Keep the mic muted until the opening persona summary is finished.
                service.isMicMuted = true
                service.startRecording()
                isRecording = true
                isMuted = true
                // Trigger the AI to explain the sources in persona immediately.
                isAIThinking = true
                try? await Task.sleep(nanoseconds: 300_000_000)
                service.sendTextInput(
                    """
                    Dive straight into a spoken summary of the source material now in the selected persona.
                    This first turn must be summary only.
                    Start immediately with the summary itself.
                    Do not greet the student.
                    Do not ask a question.
                    Do not ask for clarification.
                    Do not invite discussion.
                    Do not say anything like "let's begin" or "here's a summary."
                    After your summary is complete, stop and wait silently for the student.
                    """
                )
            }
        }

        service.onUserTranscript = { (userText: String) in
            Task { @MainActor in
                guard !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                currentUserText += userText
                isAIThinking = true

                guard hasDeliveredOpeningExplanation, !isMuted else { return }

                userQuestionMuteTask?.cancel()
                userQuestionMuteTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: questionEndMuteDelayNanoseconds)
                    guard !Task.isCancelled else { return }
                    guard hasDeliveredOpeningExplanation, !isMuted else { return }
                    guard !currentUserText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    service.isMicMuted = true
                    service.stopRecording()
                    isRecording = false
                    isMuted = true
                }
            }
        }

        service.onTranscriptDelta = { (delta: String) in
            Task { @MainActor in
                userQuestionMuteTask?.cancel()
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
                userQuestionMuteTask?.cancel()
                let trimmed = (fullText.isEmpty ? currentAIText : fullText)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    messages.append(MemorizeInteractMessage(isUser: false, text: trimmed))
                    if !hasDeliveredOpeningExplanation {
                        hasDeliveredOpeningExplanation = true
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        service.activateConversationMode(startRecordingIfNeeded: true)
                        service.isMicMuted = false
                        isRecording = true
                        isMuted = false
                    }
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

        service.onSpeechStarted = {
            Task { @MainActor in
                if !hasDeliveredOpeningExplanation || isMuted {
                    service.isMicMuted = true
                }
            }
        }

        service.onSpeechStopped = {
            Task { @MainActor in
                guard hasDeliveredOpeningExplanation else { return }
                try? await Task.sleep(nanoseconds: 250_000_000)
                if !isMuted {
                    service.activateConversationMode(startRecordingIfNeeded: true)
                    service.isMicMuted = false
                    isRecording = true
                    isMuted = false
                }
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

    private func startupStatusCard(text: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(.white)
                .scaleEffect(0.95)

            Text(text)
                .font(AppTypography.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
        }
        .frame(maxWidth: .infinity)
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
                                if isStartingSummary {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ThinkingDotsView()
                                        Text("memorize.explain_starting".localized)
                                            .font(AppTypography.caption)
                                            .foregroundColor(.white.opacity(0.72))
                                    }
                                    .padding(AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                            .fill(AppColors.memorizeCard.opacity(0.7))
                                    )
                                } else {
                                    ThinkingDotsView()
                                        .padding(AppSpacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                                .fill(AppColors.memorizeCard.opacity(0.7))
                                        )
                                }
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
                // Unmute acts as a hard "stop and listen" command.
                userQuestionMuteTask?.cancel()
                currentAIText = ""
                isAIThinking = false
                service.interruptPlayback(expectServerInterruption: true)
                service.sendSilentAudioToInterrupt()
                service.activateConversationMode(startRecordingIfNeeded: true)
                service.isMicMuted = false
                isRecording = true
                isMuted = false
            } else {
                // Mute — stop sending audio to Gemini
                userQuestionMuteTask?.cancel()
                service.isMicMuted = true
                service.stopRecording()
                isRecording = false
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

struct MemorizeInteractMessage: Identifiable {
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
        case readAloud
        case infographics
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onCommand: ((MenuCommand) -> Void)?
    @Published var hasSpoken = false
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

    // AVSpeechSynthesizerDelegate — enable buttons as soon as first word is spoken
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !hasSpoken { hasSpoken = true }
        }
    }

    // Start listening after TTS finishes
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            hasSpoken = true
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
        if normalized.contains("read aloud") || normalized.contains("read out") || normalized.contains("read to me") || normalized.contains("text to speech") {
            return .readAloud
        }
        if normalized.contains("infographic") || normalized.contains("info graphic") || normalized.contains("visual") {
            return .infographics
        }
        return nil
    }

}

// MARK: - Explain Persona Picker with Voice

struct ExplainPersonaPickerView: View {
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

struct ThinkingDotsView: View {
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

struct MemorizeInteractView: View {
    let pages: [PageCapture]
    let bookTitle: String
    let sectionTitle: String
    var customSystemPrompt: String? = nil

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
    @State private var userQuestionMuteTask: Task<Void, Never>?
    @AppStorage("geminiSelectedVoice") private var selectedVoice = "Aoede"
    @State private var showVoicePicker = false

    private let interactAccent = Color(red: 0.15, green: 0.72, blue: 0.52)
    private let questionEndMuteDelayNanoseconds: UInt64 = 450_000_000

    private var isStartingConversation: Bool {
        isConnected &&
        messages.isEmpty &&
        currentAIText.isEmpty &&
        currentUserText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isAIThinking
    }

    private var shouldShowStartupCard: Bool {
        !isConnected || isStartingConversation
    }

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.md) {
                Text("memorize.interact_prompt".localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)

                Text(sectionTitle.isEmpty ? bookTitle : "\(bookTitle) — \(sectionTitle)")
                    .font(AppTypography.caption)
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(2)
                    .padding(.horizontal, AppSpacing.md)

                if shouldShowStartupCard {
                    startupStatusCard(text: isStartingConversation ? "memorize.interact_starting".localized : "memorize.interact_connecting".localized)
                        .padding(.horizontal, AppSpacing.md)
                } else {
                    conversationCard
                        .padding(.horizontal, AppSpacing.md)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showVoicePicker = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showVoicePicker) {
            GeminiVoicePickerView(selectedVoice: $selectedVoice, accent: interactAccent)
                .presentationDetents([.medium])
        }
        .task {
            guard geminiService == nil else { return }
            setupAndConnect()
        }
        .onChange(of: selectedVoice) { _ in
            guard geminiService != nil else { return }
            reconnectWithNewVoice()
        }
    }

    private func disconnectAndDismiss() {
        userQuestionMuteTask?.cancel()
        geminiService?.disconnect()
        geminiService = nil
        dismiss()
    }

    private func reconnectWithNewVoice() {
        geminiService?.disconnect()
        geminiService = nil
        isConnected = false
        isRecording = false
        messages = []
        currentAIText = ""
        currentUserText = ""
        isAIThinking = false
        userQuestionMuteTask?.cancel()
        errorMessage = nil
        setupAndConnect()
    }

    // MARK: - Setup

    private func setupAndConnect() {
        let sourceContext = buildMemorizeLiveSourceContext(
            from: pages,
            maxPages: 8,
            maxCharsPerPage: 340,
            maxTotalChars: 4200
        )

        let systemPrompt: String
        print("🗣️ [Interact] customSystemPrompt is \(customSystemPrompt == nil ? "nil" : "set (\(customSystemPrompt!.prefix(50))...)")")
        if let custom = customSystemPrompt {
            systemPrompt = custom.replacingOccurrences(of: "{{SOURCE_CONTEXT}}", with: sourceContext)
        } else {
            systemPrompt = """
            You are a friendly, knowledgeable reading tutor. The student has just read the following condensed notes from "\(bookTitle)"\(sectionTitle.isEmpty ? "" : " — section: \(sectionTitle)"):

            ---
            \(sourceContext)
            ---

            Help the student understand what they read. You can:
            - Answer questions about the text
            - Explain difficult concepts or vocabulary
            - Ask comprehension questions to test understanding
            - Summarize key points when asked
            - Connect ideas in the text to broader knowledge
            - Give very short recap answers when the student asks for a summary of what you just said

            Keep your responses concise and conversational. For simple recap questions, answer in 1-2 sentences before adding detail.
            Speak clearly and at a pace suitable for learning.
            Do not apologize. Do not mention that you are an AI unless asked.
            Start by briefly greeting the student and asking what they'd like to discuss about the reading.
            """
        }

        print("⚡️ [MemorizeConversation] Live context chars: \(sourceContext.count)")

        let apiKey = APIProviderManager.staticLiveAIAPIKey
        let service = GeminiLiveService(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            includeTools: false
        )
        service.voiceName = selectedVoice
        service.preferSpeakerInConversation = true

        service.onConnected = { [service] in
            Task { @MainActor in
                isConnected = true
                let isSummaryMode = customSystemPrompt != nil
                // Summary mode: mute mic so AI can summarize uninterrupted
                // Conversation mode: mic live for hands-free
                service.isMicMuted = isSummaryMode
                service.startRecording()
                isRecording = true
                isMuted = isSummaryMode
                isAIThinking = true
                try? await Task.sleep(nanoseconds: 500_000_000)
                service.startPlaybackEngineIfNeeded()
                if isSummaryMode {
                    service.sendTextInput("Begin the summary now. Start speaking immediately.")
                } else {
                    service.sendTextInput(
                        """
                        Start the conversation now.
                        Greet the student briefly, mention the reading naturally, and ask one clear opening question to get them talking.
                        """
                    )
                }
            }
        }

        service.onUserTranscript = { (userText: String) in
            Task { @MainActor in
                guard !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                currentUserText += userText
                isAIThinking = true

                let isSummaryMode = customSystemPrompt != nil
                guard isSummaryMode, !isMuted else { return }

                userQuestionMuteTask?.cancel()
                userQuestionMuteTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: questionEndMuteDelayNanoseconds)
                    guard !Task.isCancelled else { return }
                    guard customSystemPrompt != nil, !isMuted else { return }
                    guard !currentUserText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    service.isMicMuted = true
                    service.stopRecording()
                    isRecording = false
                    isMuted = true
                }
            }
        }

        service.onTranscriptDelta = { (delta: String) in
            Task { @MainActor in
                userQuestionMuteTask?.cancel()
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
                userQuestionMuteTask?.cancel()
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

        service.onSpeechStarted = {
            Task { @MainActor in
                // Only auto-mute if the user hasn't manually unmuted
                if isMuted {
                    service.isMicMuted = true
                }
            }
        }

        service.onSpeechStopped = {
            Task { @MainActor in
                // Only auto-unmute if the user hasn't manually unmuted
                if isMuted {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    service.isMicMuted = false
                }
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
                                if isStartingConversation {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ThinkingDotsView()
                                        Text("memorize.interact_starting".localized)
                                            .font(AppTypography.caption)
                                            .foregroundColor(.white.opacity(0.72))
                                    }
                                    .padding(AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                            .fill(AppColors.memorizeCard.opacity(0.7))
                                    )
                                } else {
                                    ThinkingDotsView()
                                        .padding(AppSpacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppCornerRadius.sm)
                                                .fill(AppColors.memorizeCard.opacity(0.7))
                                        )
                                }
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

    private func startupStatusCard(text: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(.white)
                .scaleEffect(0.95)

            Text(text)
                .font(AppTypography.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260, maxHeight: 400)
        .background(AppColors.memorizeCard)
        .cornerRadius(AppCornerRadius.md)
    }

    private var microphoneButton: some View {
        Button {
            guard isConnected, let service = geminiService else { return }
            if isMuted {
                userQuestionMuteTask?.cancel()
                currentAIText = ""
                isAIThinking = false
                service.interruptPlayback(expectServerInterruption: true)
                service.sendSilentAudioToInterrupt()
                service.activateConversationMode(startRecordingIfNeeded: true)
                service.isMicMuted = false
                isRecording = true
                isMuted = false
            } else {
                userQuestionMuteTask?.cancel()
                service.isMicMuted = true
                service.stopRecording()
                isRecording = false
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

// MARK: - Capture Device Picker

struct CaptureDevicePickerView: View {
    @Binding var selectedDevice: CaptureDevice
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text("memorize.select_device".localized)
                .font(AppTypography.headline)
                .foregroundColor(.white)
                .padding(.top, AppSpacing.md)

            ForEach(CaptureDevice.allCases, id: \.self) { device in
                Button {
                    selectedDevice = device
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: device.iconName)
                            .font(.system(size: 22))
                            .frame(width: 36)

                        Text(device.rawValue)
                            .font(AppTypography.subheadline)

                        Spacer()

                        if device == selectedDevice {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.memorizeAccent)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(AppSpacing.sm)
                    .background(device == selectedDevice ? AppColors.memorizeAccent.opacity(0.2) : Color.white.opacity(0.08))
                    .cornerRadius(AppCornerRadius.md)
                }
            }
            .padding(.horizontal, AppSpacing.md)

            Spacer()
        }
        .background(AppColors.memorizeBackground.ignoresSafeArea())
    }
}

// MARK: - Phone Camera View

struct PhoneCameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}

// MARK: - Phone Camera Live Preview

struct PhoneCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
