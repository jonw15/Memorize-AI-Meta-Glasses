/*
 * Memorize Home View
 * Homepage for the Memorize feature - shows library and current reading
 */

import SwiftUI
import Combine
import UIKit
import AVFoundation
import Speech
import UniformTypeIdentifiers

struct MemorizeHomeView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var wearablesViewModel: WearablesViewModel

    @StateObject private var viewModel = MemorizeHomeViewModel()
    @State private var showNewSessionForm = false
    @State private var newSessionDetent: PresentationDetent = .medium
    @State private var selectedBook: Book?
    @State private var selectedParentBook: Book?
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
    @State private var showPDFPicker = false
    @State private var isImportingPDF = false
    @State private var pdfImportProgress: PDFImportService.PDFImportProgress?
    @State private var pdfImportError: String?
    @State private var splitPDFBySections = false
    @StateObject private var addBookVoice = AddBookVoiceController()
    @StateObject private var homeVoice = HomeVoiceController()
    private let memorizeService = MemorizeService()
    private let pdfImportService = PDFImportService()

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
        .task {
            await homeVoice.requestPermissionsIfNeeded()
            homeVoice.startListening { command in
                newSessionTitle = ""
                newSessionAuthor = ""
                newSessionChapter = ""
                autoFillErrorMessage = nil
                isWaitingForCoverSnapshot = false
                coverSnapshotTimeoutTask?.cancel()
                coverSnapshotTimeoutTask = nil
                newSessionDetent = .medium
                showNewSessionForm = true

                if command == .scanCover {
                    // Auto-open scan cover after sheet appears, wait for camera to initialize
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        openCoverCapturePanel()
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        if showCoverCapturePanel && coverCountdownTask == nil && !isWaitingForCoverSnapshot {
                            startCoverCaptureCountdown()
                        }
                    }
                }
            }
        }
        .onChange(of: showNewSessionForm) { showing in
            if showing {
                homeVoice.suspendListening()
            } else {
                addBookVoice.stopListening()
                // Only resume home voice if we're not navigating to a capture view
                if selectedBook == nil {
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        homeVoice.resumeListening()
                    }
                }
            }
        }
        .onChange(of: selectedBook?.id) { id in
            if id != nil {
                homeVoice.suspendListening()
            } else {
                homeVoice.resumeListening()
            }
        }
        .onChange(of: selectedParentBook?.id) { id in
            if id != nil {
                homeVoice.suspendListening()
            } else {
                homeVoice.resumeListening()
            }
        }
        .fullScreenCover(item: $selectedBook, onDismiss: {
            viewModel.loadBooks()
        }) { book in
            MemorizeCaptureView(
                streamViewModel: streamViewModel,
                book: book
            )
        }
        .fullScreenCover(item: $selectedParentBook, onDismiss: {
            viewModel.loadBooks()
        }) { parentBook in
            BookSectionsView(
                parentBook: parentBook,
                streamViewModel: streamViewModel
            )
        }
        .sheet(isPresented: $showNewSessionForm) {
            newSessionSheet
                .presentationDetents([.medium, .large], selection: $newSessionDetent)
                .presentationDragIndicator(.visible)
                .task {
                    // Ensure home voice controller fully releases the mic first
                    homeVoice.suspendListening()
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await addBookVoice.requestPermissionsIfNeeded()
                    addBookVoice.startListening { command in
                        switch command {
                        case .scanCover:
                            if !showCoverCapturePanel && !isAutoFillingBookInfo && !isWaitingForCoverSnapshot {
                                openCoverCapturePanel()
                                // Wait for camera to fully initialize before starting countdown
                                Task {
                                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                                    if showCoverCapturePanel && coverCountdownTask == nil && !isWaitingForCoverSnapshot {
                                        startCoverCaptureCountdown()
                                    }
                                }
                            }
                        case .addBook:
                            if isNewSessionValid {
                                addBookVoice.stopListening()
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
                            }
                        }
                    }
                }
                .onDisappear {
                    addBookVoice.stopListening()
                }
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
                addBookVoice.resumeListening()
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
                if book.hasSections {
                    Label("\(book.sections.count)", systemImage: "list.bullet")
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.5))

                    Text("memorize.chapters".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.5))
                } else {
                    Label("\(book.completedPages)", systemImage: "doc.text.fill")
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.5))

                    Text("memorize.pages_captured".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }

            Button {
                if book.hasSections {
                    selectedParentBook = book
                } else {
                    selectedBook = book
                }
            } label: {
                Text(book.hasSections ? "memorize.view_chapters".localized : "memorize.continue_session".localized)
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
        ScrollView {
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
                .disabled(isAutoFillingBookInfo || isWaitingForCoverSnapshot || showCoverCapturePanel || isImportingPDF)

                Button {
                    showPDFPicker = true
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        if isImportingPDF {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "doc.fill")
                        }
                        if let progress = pdfImportProgress, isImportingPDF {
                            Text(String(format: "memorize.pdf_importing_progress".localized, progress.currentPage, progress.totalPages))
                                .font(AppTypography.subheadline)
                        } else {
                            Text("memorize.upload_pdf".localized)
                                .font(AppTypography.subheadline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.25))
                    .cornerRadius(AppCornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.md)
                            .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                    )
                }
                .disabled(isImportingPDF || isAutoFillingBookInfo || isWaitingForCoverSnapshot)

                // Sections toggle
                HStack {
                    Toggle(isOn: $splitPDFBySections) {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet.indent")
                                .font(.system(size: 14))
                            Text("memorize.pdf_sections".localized)
                                .font(AppTypography.subheadline)
                        }
                        .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Color.orange))
                }
                .padding(.horizontal, AppSpacing.sm)

                if let pdfImportError, !pdfImportError.isEmpty {
                    Text(pdfImportError)
                        .font(AppTypography.caption)
                        .foregroundColor(.red.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

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

        }
        } // ScrollView
        .fileImporter(
            isPresented: $showPDFPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await importPDF(from: url)
                }
            case .failure(let error):
                pdfImportError = error.localizedDescription
            }
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

        // Suspend voice commands during countdown to avoid audio session conflict
        addBookVoice.stopListening()

        coverCountdownTask = Task { @MainActor in
            defer {
                coverCountdownTask = nil
            }
            // Configure audio session and let it settle so "3" is audible
            configureCoverCountdownAudioSession()
            if coverCountdownSynthesizer.isSpeaking {
                coverCountdownSynthesizer.stopSpeaking(at: .immediate)
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
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

    private func importPDF(from url: URL) async {
        isImportingPDF = true
        pdfImportError = nil
        pdfImportProgress = nil

        do {
            let result = try await pdfImportService.importPDF(from: url) { progress in
                pdfImportProgress = progress
            }

            // Save thumbnails to disk
            for thumbnail in result.thumbnails {
                MemorizeStorage.shared.saveThumbnail(thumbnail.data, for: thumbnail.pageId)
            }

            if splitPDFBySections {
                // Use AI to detect sections, then create one parent book with child sections
                let detectedSections = try await pdfImportService.detectSections(from: result.pages)

                var childBooks: [Book] = []
                for section in detectedSections {
                    let sectionPages = section.pageIndices.compactMap { idx -> PageCapture? in
                        guard idx >= 0, idx < result.pages.count else { return nil }
                        return result.pages[idx]
                    }
                    guard !sectionPages.isEmpty else { continue }

                    var child = Book(
                        title: result.title,
                        author: result.author,
                        chapter: section.title,
                        pages: sectionPages
                    )
                    MemorizeStorage.shared.loadThumbnails(for: &child)
                    childBooks.append(child)
                }

                // Create parent book with sections (no pages of its own)
                let parentBook = Book(
                    title: result.title,
                    author: result.author,
                    sections: childBooks
                )
                MemorizeStorage.shared.saveBook(parentBook)

                isImportingPDF = false
                pdfImportProgress = nil
                showNewSessionForm = false

                // Stay on home page so user can pick from the chapters
                viewModel.loadBooks()
            } else {
                // Create a single book with all pages
                var book = Book(
                    title: result.title,
                    author: result.author,
                    pages: result.pages
                )
                MemorizeStorage.shared.saveBook(book)
                MemorizeStorage.shared.loadThumbnails(for: &book)

                isImportingPDF = false
                pdfImportProgress = nil
                showNewSessionForm = false

                selectedBook = book
                viewModel.loadBooks()
            }
        } catch {
            isImportingPDF = false
            pdfImportProgress = nil
            pdfImportError = error.localizedDescription
            print("❌ [Memorize] PDF import failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Add Book Voice Controller

@MainActor
private final class AddBookVoiceController: NSObject, ObservableObject {
    enum Command {
        case scanCover
        case addBook
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

    func stopListening() {
        shouldListen = false
        restartTask?.cancel()
        restartTask = nil
        stopListeningInternal()
    }

    func resumeListening() {
        shouldListen = true
        beginListeningIfNeeded()
    }

    private func beginListeningIfNeeded() {
        guard shouldListen else { return }
        guard !speechPermissionDenied, !micPermissionDenied else { return }
        guard recognitionTask == nil else { return }

        restartTask?.cancel()
        restartTask = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

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
        print("🎤 [AddBookVoice] Listening...")

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let text = result?.bestTranscription.formattedString.lowercased() {
                    print("🎤 [AddBookVoice] Heard: \(text)")
                    if let command = self.parseCommand(from: text) {
                        let now = Date()
                        if now.timeIntervalSince(self.lastTriggerAt) > 2.0 {
                            self.lastTriggerAt = now
                            self.onCommand?(command)
                        }
                    }
                }
                if let error {
                    print("🎤 [AddBookVoice] Error: \(error.localizedDescription)")
                    self.stopListeningInternal()
                    self.scheduleRestart()
                } else if result?.isFinal ?? false {
                    self.stopListeningInternal()
                    self.scheduleRestart()
                }
            }
        }
    }

    private func stopListeningInternal() {
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
        if normalized.contains("scan cover") ||
            normalized.contains("scan book") ||
            normalized.contains("take cover") ||
            normalized.contains("capture cover") {
            return .scanCover
        }
        if normalized.contains("add book") ||
            normalized.contains("at book") ||
            normalized.contains("start session") ||
            normalized.contains("start reading") {
            return .addBook
        }
        return nil
    }
}

// MARK: - Home Voice Controller

@MainActor
private final class HomeVoiceController: NSObject, ObservableObject {
    enum Command: Equatable {
        case addNewBook
        case scanCover
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
        restartTask?.cancel()
        restartTask = nil
        stopListeningInternal()
    }

    func resumeListening() {
        shouldListen = true
        beginListeningIfNeeded()
    }

    private func beginListeningIfNeeded() {
        guard shouldListen else { return }
        guard !speechPermissionDenied, !micPermissionDenied else { return }
        guard recognitionTask == nil else { return }

        restartTask?.cancel()
        restartTask = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

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
        print("🎤 [HomeVoice] Listening...")

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let text = result?.bestTranscription.formattedString.lowercased() {
                    let normalized = text.replacingOccurrences(of: "-", with: " ")
                    print("🎤 [HomeVoice] Heard: \(normalized)")
                    var command: Command?
                    if normalized.contains("scan cover") ||
                        normalized.contains("scan book") ||
                        normalized.contains("scanning") ||
                        normalized.contains("can cover") ||
                        normalized.contains("book cover") ||
                        normalized.contains("scan") {
                        command = .scanCover
                    } else if normalized.contains("add new book") ||
                        normalized.contains("new book") ||
                        normalized.contains("add book") {
                        command = .addNewBook
                    }
                    if let command {
                        let now = Date()
                        if now.timeIntervalSince(lastTriggerAt) > 2.0 {
                            lastTriggerAt = now
                            onCommand?(command)
                        }
                    }
                }
                if let error {
                    print("🎤 [HomeVoice] Error: \(error.localizedDescription)")
                    stopListeningInternal()
                    scheduleRestart()
                } else if result?.isFinal ?? false {
                    print("🎤 [HomeVoice] Final, restarting...")
                    stopListeningInternal()
                    scheduleRestart()
                }
            }
        }
    }

    private func stopListeningInternal() {
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
}
