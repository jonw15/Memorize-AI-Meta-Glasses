/*
 * Memorize Home View
 * Homepage for the Memorize feature - shows library and current reading
 */

import SwiftUI
import Combine
import UIKit
import AVFoundation

struct MemorizeHomeView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var wearablesViewModel: WearablesViewModel

    @StateObject private var viewModel = MemorizeHomeViewModel()
    @State private var showNewSessionForm = false
    @State private var newSessionDetent: PresentationDetent = .medium
    @State private var selectedBook: Book?
    @State private var pendingDeleteBook: Book?
    @State private var newSessionTitle: String = ""
    @State private var newSessionAuthor: String = ""
    @State private var newSessionChapter: String = ""
    @State private var isAutoFillingBookInfo = false
    @State private var isWaitingForCoverSnapshot = false
    @State private var showCoverCapturePanel = false
    @State private var coverCountdownValue: Int?
    @State private var autoFillErrorMessage: String?
    @State private var coverSnapshotTimeoutTask: Task<Void, Never>?
    @State private var coverCountdownTask: Task<Void, Never>?
    @State private var didStartStreamForCoverCapture = false
    @State private var coverCountdownSynthesizer = AVSpeechSynthesizer()
    private let memorizeService = MemorizeService()

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.lg) {
                homeHeaderSection

                // Add to Library Section (top)
                addBookSection

                // Existing Projects Section (scrollable panel)
                if !viewModel.books.isEmpty {
                    existingProjectsSection
                } else {
                    Spacer(minLength: 40)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.loadBooks()
        }
        .fullScreenCover(item: $selectedBook, onDismiss: {
            viewModel.loadBooks()
        }) { book in
            MemorizeCaptureView(
                streamViewModel: streamViewModel,
                book: book
            )
        }
        .sheet(isPresented: $showNewSessionForm) {
            newSessionSheet
                .presentationDetents([.medium, .large], selection: $newSessionDetent)
                .presentationDragIndicator(.visible)
        }
        .alert(item: $pendingDeleteBook) { book in
            Alert(
                title: Text("memorize.delete_session_title".localized),
                message: Text(String(format: "memorize.delete_session_message".localized, book.title.isEmpty ? "memorize.untitled".localized : book.title)),
                primaryButton: .destructive(Text("memorize.delete_session_confirm".localized)) {
                    viewModel.deleteBook(book.id)
                },
                secondaryButton: .cancel(Text("memorize.cancel".localized))
            )
        }
        .onReceive(streamViewModel.$capturedPhoto.compactMap { $0 }) { image in
            guard isWaitingForCoverSnapshot else { return }
            coverSnapshotTimeoutTask?.cancel()
            coverSnapshotTimeoutTask = nil
            coverCountdownTask?.cancel()
            coverCountdownTask = nil
            coverCountdownValue = nil
            stopCoverCountdownSpeech()
            isWaitingForCoverSnapshot = false
            showCoverCapturePanel = false
            stopCoverCaptureStreamIfNeeded()
            streamViewModel.showPhotoPreview = false
            streamViewModel.capturedPhoto = nil
            Task {
                await fillBookInfo(from: image)
            }
        }
    }

    // MARK: - Existing Projects Section

    private var existingProjectsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("memorize.existing_projects".localized)
                .font(AppTypography.headline)
                .foregroundColor(.white)

            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.books) { book in
                        projectCard(book: book)
                    }
                }
            }
            .frame(maxHeight: 420)
        }
    }

    // MARK: - Home Header

    private var homeHeaderSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("memorize.title".localized)
                    .font(AppTypography.largeTitle)
                    .foregroundColor(.white)

                Text("memorize.add_to_library".localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            if wearablesViewModel.registrationState == .registered {
                disconnectGlassesButton
            }
        }
    }

    private func projectCard(book: Book) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title.isEmpty ? "memorize.untitled".localized : book.title)
                        .font(AppTypography.title2)
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if !book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(book.author)
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color.white.opacity(0.6))
                    }

                    if !book.chapter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(book.chapter)
                            .font(AppTypography.caption)
                            .foregroundColor(Color.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    pendingDeleteBook = book
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }

            HStack(spacing: AppSpacing.sm) {
                Label("\(book.completedPages)", systemImage: "doc.text.fill")
                    .font(AppTypography.caption)
                    .foregroundColor(Color.white.opacity(0.5))

                Text("memorize.pages_captured".localized)
                    .font(AppTypography.caption)
                    .foregroundColor(Color.white.opacity(0.5))
            }

            Button {
                selectedBook = book
            } label: {
                Text("memorize.continue_session".localized)
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [AppColors.memorizeAccent, AppColors.memorizeAccent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppCornerRadius.md)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.memorizeCard)
        .cornerRadius(AppCornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                .stroke(AppColors.memorizeAccent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Add Book Section

    private var addBookSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button {
                newSessionTitle = ""
                newSessionAuthor = ""
                newSessionChapter = ""
                autoFillErrorMessage = nil
                isWaitingForCoverSnapshot = false
                coverSnapshotTimeoutTask?.cancel()
                coverSnapshotTimeoutTask = nil
                newSessionDetent = .medium
                showNewSessionForm = true
            } label: {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(Color.white.opacity(0.4))

                    Text("memorize.add_new_book".localized)
                        .font(AppTypography.callout)
                        .foregroundColor(Color.white.opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.clear)
                .cornerRadius(AppCornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                        .foregroundColor(Color.white.opacity(0.15))
                )
            }
        }
    }

    private var isNewSessionValid: Bool {
        !newSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var newSessionSheet: some View {
        NavigationView {
            Group {
                if showCoverCapturePanel {
                    coverCapturePanel
                } else {
                    newSessionFormContent
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle(showCoverCapturePanel ? "memorize.cover_capture_title".localized : "memorize.new_session".localized)
            .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("memorize.cancel".localized) {
                        if showCoverCapturePanel {
                            closeCoverCapturePanel()
                        } else {
                            isWaitingForCoverSnapshot = false
                            coverSnapshotTimeoutTask?.cancel()
                            coverSnapshotTimeoutTask = nil
                            coverCountdownTask?.cancel()
                            coverCountdownTask = nil
                            coverCountdownValue = nil
                            showCoverCapturePanel = false
                            stopCoverCaptureStreamIfNeeded()
                            showNewSessionForm = false
                        }
                    }
                    .foregroundColor(.white)
                    }
                }
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var disconnectGlassesButton: some View {
        Button {
            Task {
                await disconnectGlassesForAddSession()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "link.badge.minus")
                    .font(.system(size: 14, weight: .semibold))
                Text("memorize.disconnect_glasses".localized)
                    .font(AppTypography.caption)
            }
            .foregroundColor(.red)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.12))
            .clipShape(Capsule())
        }
    }

    private func disconnectGlassesForAddSession() async {
        await wearablesViewModel.disconnectGlasses()
        isWaitingForCoverSnapshot = false
        coverSnapshotTimeoutTask?.cancel()
        coverSnapshotTimeoutTask = nil
        coverCountdownTask?.cancel()
        coverCountdownTask = nil
        coverCountdownValue = nil
        stopCoverCountdownSpeech()
        showCoverCapturePanel = false
        showNewSessionForm = false
    }

    private var coverCapturePanel: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: AppSpacing.md) {
                ZStack {
                    Group {
                        if let frame = streamViewModel.currentVideoFrame {
                            Image(uiImage: frame)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Rectangle()
                                .fill(AppColors.memorizeCard)
                                .overlay(
                                    VStack(spacing: AppSpacing.sm) {
                                        ProgressView()
                                            .tint(AppColors.memorizeAccent)
                                        Text("memorize.connecting_camera".localized)
                                            .font(AppTypography.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.xl)

                    if let coverCountdownValue {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.55))
                                .frame(width: 110, height: 110)
                            Text("\(coverCountdownValue)")
                                .font(.system(size: 54, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    if isWaitingForCoverSnapshot {
                        VStack(spacing: AppSpacing.sm) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("memorize.cover_capture_processing".localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(AppSpacing.md)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(AppCornerRadius.md)
                    }
                }
                .frame(height: 420)
                .cornerRadius(AppCornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                        .stroke(AppColors.memorizeAccent.opacity(0.35), lineWidth: 1)
                )

                VStack(spacing: AppSpacing.xs) {
                    Text("memorize.cover_capture_subtitle".localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    Text("memorize.cover_capture_align_hint".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    if coverCountdownValue != nil {
                        cancelCoverCaptureCountdown()
                    } else {
                        startCoverCaptureCountdown()
                    }
                } label: {
                    Text(coverCountdownValue != nil
                         ? "memorize.cover_capture_cancel_countdown".localized
                         : "memorize.cover_capture_take_photo".localized)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [AppColors.memorizeAccent, AppColors.memorizeAccent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppCornerRadius.md)
                }
                .disabled(isWaitingForCoverSnapshot)
                .opacity(isWaitingForCoverSnapshot ? 0.5 : 1)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
            .onAppear {
                Task {
                    await prepareCoverCaptureStream()
                }
            }
        }
    }

    private var newSessionFormContent: some View {
        VStack(spacing: AppSpacing.md) {
            Text("memorize.enter_book_details".localized)
                .font(AppTypography.subheadline)
                .foregroundColor(Color.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: AppSpacing.sm) {
                Button {
                    openCoverCapturePanel()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if isAutoFillingBookInfo || isWaitingForCoverSnapshot {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "camera.viewfinder")
                        }
                        Text("memorize.autofill_cover".localized)
                            .font(AppTypography.subheadline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.memorizeAccent.opacity(0.25))
                    .cornerRadius(AppCornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.md)
                            .stroke(AppColors.memorizeAccent.opacity(0.45), lineWidth: 1)
                    )
                }
                .disabled(isAutoFillingBookInfo || isWaitingForCoverSnapshot || showCoverCapturePanel)

                if let autoFillErrorMessage, !autoFillErrorMessage.isEmpty {
                    Text(autoFillErrorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(.red.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TextField("memorize.book_name_field".localized, text: $newSessionTitle)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 14)
                    .background(AppColors.memorizeCard)
                    .foregroundColor(.white)
                    .cornerRadius(AppCornerRadius.md)

                TextField("memorize.author_field".localized, text: $newSessionAuthor)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 14)
                    .background(AppColors.memorizeCard)
                    .foregroundColor(.white)
                    .cornerRadius(AppCornerRadius.md)

                TextField("memorize.chapter_field".localized, text: $newSessionChapter)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 14)
                    .background(AppColors.memorizeCard)
                    .foregroundColor(.white)
                    .cornerRadius(AppCornerRadius.md)
            }

            Button {
                isWaitingForCoverSnapshot = false
                coverSnapshotTimeoutTask?.cancel()
                coverSnapshotTimeoutTask = nil
                coverCountdownTask?.cancel()
                coverCountdownTask = nil
                coverCountdownValue = nil
                showCoverCapturePanel = false
                stopCoverCaptureStreamIfNeeded()
                selectedBook = Book(
                    title: newSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    author: newSessionAuthor.trimmingCharacters(in: .whitespacesAndNewlines),
                    chapter: newSessionChapter.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                showNewSessionForm = false
            } label: {
                Text("memorize.start_session".localized)
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [AppColors.memorizeAccent, AppColors.memorizeAccent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppCornerRadius.md)
            }
            .disabled(!isNewSessionValid)
            .opacity(isNewSessionValid ? 1 : 0.5)

            Spacer()
        }
    }

    private func openCoverCapturePanel() {
        guard !isAutoFillingBookInfo else { return }
        autoFillErrorMessage = nil
        coverCountdownTask?.cancel()
        coverCountdownTask = nil
        coverCountdownValue = nil
        newSessionDetent = .large
        showCoverCapturePanel = true
    }

    private func closeCoverCapturePanel() {
        coverCountdownTask?.cancel()
        coverCountdownTask = nil
        coverCountdownValue = nil
        stopCoverCountdownSpeech()
        isWaitingForCoverSnapshot = false
        coverSnapshotTimeoutTask?.cancel()
        coverSnapshotTimeoutTask = nil
        showCoverCapturePanel = false
        newSessionDetent = .medium
        stopCoverCaptureStreamIfNeeded()
    }

    private func prepareCoverCaptureStream() async {
        guard !streamViewModel.isStreaming else {
            didStartStreamForCoverCapture = false
            return
        }
        didStartStreamForCoverCapture = true
        await streamViewModel.handleStartStreaming()
    }

    private func startCoverCaptureCountdown() {
        guard coverCountdownTask == nil, !isWaitingForCoverSnapshot else { return }

        coverCountdownTask = Task { @MainActor in
            defer {
                coverCountdownTask = nil
            }
            for value in stride(from: 3, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                coverCountdownValue = value
                speakCoverCountdownNumber(value)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            guard !Task.isCancelled else { return }
            coverCountdownValue = nil
            triggerCoverSnapshotCapture()
        }
    }

    private func cancelCoverCaptureCountdown() {
        coverCountdownTask?.cancel()
        coverCountdownTask = nil
        coverCountdownValue = nil
        stopCoverCountdownSpeech()
    }

    private func triggerCoverSnapshotCapture() {
        guard !isAutoFillingBookInfo else { return }
        isWaitingForCoverSnapshot = true
        coverSnapshotTimeoutTask?.cancel()
        streamViewModel.capturePhoto()

        coverSnapshotTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            if isWaitingForCoverSnapshot {
                isWaitingForCoverSnapshot = false
                showCoverCapturePanel = false
                autoFillErrorMessage = "memorize.autofill_cover_failed".localized
                stopCoverCaptureStreamIfNeeded()
            }
        }
    }

    private func stopCoverCaptureStreamIfNeeded() {
        guard didStartStreamForCoverCapture else { return }
        didStartStreamForCoverCapture = false
        Task {
            await streamViewModel.stopSession()
        }
    }

    private func speakCoverCountdownNumber(_ value: Int) {
        configureCoverCountdownAudioSession()
        if coverCountdownSynthesizer.isSpeaking {
            coverCountdownSynthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: "\(value)")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        coverCountdownSynthesizer.speak(utterance)
    }

    private func stopCoverCountdownSpeech() {
        if coverCountdownSynthesizer.isSpeaking {
            coverCountdownSynthesizer.stopSpeaking(at: .immediate)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureCoverCountdownAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [Memorize] Countdown voice audio session setup failed: \(error.localizedDescription)")
        }
    }

    private func fillBookInfo(from image: UIImage) async {
        guard !isAutoFillingBookInfo else { return }
        isAutoFillingBookInfo = true
        defer { isAutoFillingBookInfo = false }

        do {
            let bookInfo = try await memorizeService.detectBookInfo(from: image)
            let detectedTitle = cleanedDetectedValue(bookInfo.title, unknownValue: "memorize.unknown_book".localized)
            let detectedAuthor = cleanedDetectedValue(bookInfo.author, unknownValue: "memorize.unknown_author".localized)

            if !detectedTitle.isEmpty {
                newSessionTitle = detectedTitle
            }
            if !detectedAuthor.isEmpty {
                newSessionAuthor = detectedAuthor
            }

            if detectedTitle.isEmpty && detectedAuthor.isEmpty {
                autoFillErrorMessage = "memorize.autofill_cover_failed".localized
            }
        } catch {
            autoFillErrorMessage = "memorize.autofill_cover_failed".localized
            print("❌ [Memorize] Cover auto-fill failed: \(error.localizedDescription)")
        }
    }

    private func cleanedDetectedValue(_ value: String, unknownValue: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.caseInsensitiveCompare(unknownValue) == .orderedSame {
            return ""
        }
        return trimmed
    }
}
