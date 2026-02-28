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
    @Environment(\.dismiss) private var dismiss
    @State private var selectedThumbnail: TimelineThumbnailPreview?
    @State private var showVoiceSummary = false
    private let processingAccent = Color(red: 0.34, green: 0.86, blue: 1.0)

    private struct TimelineThumbnailPreview: Identifiable {
        let id = UUID()
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
                    .padding(.horizontal, AppSpacing.md)
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

                Spacer()

                // Session Timeline
                if !viewModel.pages.isEmpty {
                    timelineSection
                }

                // Learning checks
                if hasCompletedPages {
                    popQuizButton
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.sm)

                    voiceSummaryButton
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.sm)
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
        .fullScreenCover(isPresented: $viewModel.showQuiz) {
            MemorizeQuizView(questions: $viewModel.quizQuestions)
        }
        .fullScreenCover(isPresented: $showVoiceSummary) {
            MemorizeVoiceSummaryView(
                pages: viewModel.pages.filter { $0.status == .completed },
                bookTitle: displayBookTitle
            )
        }
        .fullScreenCover(item: $selectedThumbnail) { preview in
            GeometryReader { geo in
                VStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        Color.black

                        Image(uiImage: preview.image)
                            .resizable()
                            .scaledToFit()
                            .padding(AppSpacing.md)

                        Button {
                            selectedThumbnail = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.top, AppSpacing.lg)
                                .padding(.trailing, AppSpacing.md)
                        }
                    }
                    .frame(height: geo.size.height * 0.5)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("P\(preview.pageNumber) • OCR")
                            .font(AppTypography.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.md)

                        ScrollView {
                            Text(preview.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                 ? "memorize.no_ocr_text".localized
                                 : preview.extractedText)
                                .font(AppTypography.body)
                                .foregroundColor(Color.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(AppSpacing.md)
                        }
                    }
                    .frame(height: geo.size.height * 0.5)
                    .background(AppColors.memorizeBackground)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            viewModel.streamViewModel = streamViewModel
            viewModel.loadBook(book)
            Task {
                await streamViewModel.handleStartStreaming()
            }
        }
    }

    // MARK: - Camera Preview

    private var cameraPreview: some View {
        ZStack {
            if let videoFrame = streamViewModel.currentVideoFrame {
                Image(uiImage: videoFrame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .tint(AppColors.memorizeAccent)
                    Text("memorize.connecting_camera".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            }

            // Captured photo flash overlay
            if let captured = viewModel.lastCapturedImage {
                Image(uiImage: captured)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .transition(.opacity)
            }
        }
        .frame(height: 200)
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

    private var hasCompletedPages: Bool {
        viewModel.pages.contains(where: { $0.status == .completed })
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
        .disabled(viewModel.isProcessing || viewModel.isGeneratingQuiz)
        .opacity((viewModel.isProcessing || viewModel.isGeneratingQuiz) ? 0.5 : 1.0)
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

                if viewModel.pages.count > 3 {
                    Text("memorize.view_all".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.memorizeAccent)
                }
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
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.95))
                            .background(Circle().fill(Color.black.opacity(0.35)))
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
        !viewModel.isProcessing && page.status != .processing && page.status != .capturing
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

    // MARK: - Pop Quiz Button

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
        .disabled(viewModel.isGeneratingQuiz)
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
        .disabled(viewModel.isGeneratingQuiz)
        .opacity(viewModel.isGeneratingQuiz ? 0.5 : 1.0)
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            viewModel.finishSession()
            dismiss()
        } label: {
            Text("memorize.done_reading".localized)
                .font(AppTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.1))
                .cornerRadius(AppCornerRadius.md)
        }
        .padding(.horizontal, AppSpacing.md)
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

    private let audioEngine = AVAudioEngine()
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
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

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
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, _ in
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
            } else {
                do {
                    try speechRecognizer.startListening()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(voiceAccent.opacity(0.2))
                    .frame(width: 150, height: 150)

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
        errorMessage = nil
        isGrading = true
        defer { isGrading = false }

        do {
            gradeResult = try await memorizeService.gradeVoiceSummary(
                summary: speechRecognizer.transcript,
                from: pages
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
