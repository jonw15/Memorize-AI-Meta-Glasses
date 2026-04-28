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
    @State private var showLiveMode = false
    @State private var newSessionDetent: PresentationDetent = .medium
    @State private var selectedBook: Book?
    @State private var selectedParentBook: Book?
    @State private var selectedProjectBook: Book?
    @State private var lastOpenedProjectId: UUID?
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
    @State private var isSearchActive = false
    @State private var searchText = ""
    @StateObject private var addBookVoice = AddBookVoiceController()
    @StateObject private var homeVoice = HomeVoiceController()
    private let memorizeService = MemorizeService()
    private let pdfImportService = PDFImportService()

    var body: some View {
        VStack(spacing: 0) {
            projectHomeHeader
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("memorize.projects_eyebrow".localized)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundColor(projectMutedText)

                        Text("memorize.project_home_prompt".localized)
                            .font(.system(size: 34, weight: .regular, design: .serif))
                            .foregroundColor(projectInk)
                            .lineSpacing(-2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    newProjectButton

                    if isSearchActive {
                        projectSearchField
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 7) {
                            Text("memorize.recent".localized)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .foregroundColor(projectMutedText)

                            Text("·")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(projectMutedText.opacity(0.55))

                            Text("\(displayedBooks.count)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(projectMutedText)
                        }

                        if displayedBooks.isEmpty {
                            emptyProjectsCard
                        } else {
                            VStack(spacing: 10) {
                                ForEach(displayedBooks) { book in
                                    compactProjectCard(book: book)
                                        .onTapGesture {
                                            openProject(book)
                                        }
                                }
                            }
                        }
                    }

                    projectStatsBar
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 38)
            }
        }
        .background(projectPaper.ignoresSafeArea())
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.loadBooks()
        }
        .task {
            // Home voice controller disabled
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
        .onChange(of: showLiveMode) { _, isShowing in
            if isShowing {
                homeVoice.suspendListening()
            } else {
                homeVoice.resumeListening()
            }
        }
        .fullScreenCover(isPresented: $showLiveMode) {
            ProjectLiveModeView(streamViewModel: streamViewModel)
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
        .fullScreenCover(item: $selectedProjectBook, onDismiss: {
            // Clean up empty projects that user backed out of without adding anything
            // Only delete if title is also empty (brand new, never interacted with)
            if let bookId = lastOpenedProjectId {
                let books = MemorizeStorage.shared.loadBooks()
                if let latest = books.first(where: { $0.id == bookId }),
                   latest.sources.isEmpty && latest.pages.isEmpty &&
                   latest.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.deleteBook(bookId)
                }
                lastOpenedProjectId = nil
            }
            viewModel.loadBooks()
        }) { book in
            ProjectDetailView(
                book: book,
                streamViewModel: streamViewModel,
                onDeleteProject: deleteBook
            )
            .onAppear {
                lastOpenedProjectId = book.id
            }
        }
        .onChange(of: selectedProjectBook?.id) { id in
            if id != nil {
                homeVoice.suspendListening()
            } else {
                homeVoice.resumeListening()
            }
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
                    deleteBook(book.id)
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

    private var projectPaper: Color {
        Color(hex: "F8F4EE")
    }

    private var projectInk: Color {
        Color(hex: "1F2420")
    }

    private var projectMutedText: Color {
        Color(hex: "8D958E")
    }

    private var displayedBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.books }

        return viewModel.books.filter { book in
            book.title.localizedCaseInsensitiveContains(query) ||
            book.author.localizedCaseInsensitiveContains(query) ||
            book.chapter.localizedCaseInsensitiveContains(query)
        }
    }

    private var projectHomeHeader: some View {
        HStack(spacing: 12) {
            Button {
                showLiveMode = true
            } label: {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(projectPaper)
                    .frame(width: 40, height: 40)
                    .background(projectInk)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)

            Text("memorize.home_brand".localized)
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundColor(projectInk)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    isSearchActive.toggle()
                    if !isSearchActive {
                        searchText = ""
                    }
                }
            } label: {
                Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(projectInk)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.82))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "E8E0D7"), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("memorize.search".localized))
        }
    }

    private var projectSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(projectMutedText)

            TextField("memorize.search_projects".localized, text: $searchText)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(projectInk)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
        )
    }

    private var newProjectButton: some View {
        Button {
            createNewProject()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(projectInk)
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.36))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("memorize.new_project".localized)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(projectInk)

                    Text("memorize.new_project_desc".localized)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(projectInk.opacity(0.72))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(projectInk.opacity(0.64))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(Color(hex: "BFEFC8"))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color(hex: "8BD49C").opacity(0.28), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
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

    // MARK: - Compact Project Card

    private func compactProjectCard(book: Book) -> some View {
        HStack(spacing: 16) {
            projectIcon(for: book)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title.isEmpty ? "memorize.untitled".localized : book.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(projectInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text(projectSourceText(for: book))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(projectMutedText)
                    Text("·")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(projectMutedText.opacity(0.65))
                    Text(relativeDateText(for: book.updatedAt))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(projectMutedText)
                }
            }

            Spacer()

            ProjectProgressRing(
                progress: projectProgress(for: book),
                tint: projectRingColor(for: book)
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 5)
        .contextMenu {
            Button(role: .destructive) {
                pendingDeleteBook = book
            } label: {
                Label("memorize.delete_session_confirm".localized, systemImage: "trash")
            }
        }
    }

    private var emptyProjectsCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(projectInk.opacity(0.45))
                .frame(width: 56, height: 56)
                .background(Color(hex: "EEF0E7"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("memorize.no_projects".localized)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(projectInk)

            Text("memorize.new_project_desc".localized)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(projectMutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 22)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var projectStatsBar: some View {
        let sourceTotal = viewModel.books.reduce(0) { $0 + $1.sourceCount }

        return HStack(spacing: 18) {
            Label("\(viewModel.books.count)", systemImage: "folder")
            Text(viewModel.books.count == 1 ? "memorize.project_count_one".localized : "memorize.project_count_many".localized)

            Text("·")
                .foregroundColor(projectMutedText.opacity(0.45))

            Label("\(sourceTotal)", systemImage: "doc.text")
            Text(sourceTotal == 1 ? "memorize.source_label_one".localized : "memorize.source_label_many".localized)
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundColor(projectMutedText)
    }

    private func projectIcon(for book: Book) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(projectTileColor(for: book))
                .frame(width: 55, height: 55)

            if book.icon.isEmpty {
                Image(systemName: projectSystemIcon(for: book))
                    .font(.system(size: 27, weight: .medium))
                    .foregroundColor(projectRingColor(for: book))
            } else {
                Text(book.icon)
                    .font(.system(size: 28))
            }
        }
    }

    private func openProject(_ book: Book) {
        if book.hasSections {
            selectedParentBook = book
        } else {
            selectedProjectBook = book
        }
    }

    private func createNewProject() {
        selectedProjectBook = Book(title: "")
    }

    private func projectSourceText(for book: Book) -> String {
        let count = book.sourceCount
        let key = count == 1 ? "memorize.source_count_one" : "memorize.source_count_many"
        return String(format: key.localized, count)
    }

    private func relativeDateText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "memorize.today".localized
        }
        if calendar.isDateInYesterday(date) {
            return "memorize.yesterday".localized
        }
        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day,
           days > 0 && days < 7 {
            return String(format: "memorize.days_ago".localized, days)
        }
        return formatDate(date)
    }

    private func projectProgress(for book: Book) -> CGFloat {
        let completed = book.allPages.filter { $0.status == .completed }.count
        let total = max(book.allPages.count, book.sourceCount, book.sections.count)
        guard total > 0 else { return 0.18 }
        return max(0.18, min(1, CGFloat(completed) / CGFloat(total)))
    }

    private func projectSystemIcon(for book: Book) -> String {
        if book.sources.contains(where: { $0.sourceType == .pdf }) { return "doc.richtext.fill" }
        if book.hasSections { return "square.stack.3d.up.fill" }
        if book.sources.contains(where: { $0.sourceType == .youtube }) { return "play.rectangle.fill" }
        if !book.pages.isEmpty { return "camera.fill" }
        return "text.book.closed.fill"
    }

    private func projectTileColor(for book: Book) -> Color {
        let colors = [
            Color(hex: "DDF8D9"),
            Color(hex: "FFE2E5"),
            Color(hex: "D7F1FF"),
            Color(hex: "F4E5FF"),
            Color(hex: "FFF0C9")
        ]
        let index = Int(UInt(bitPattern: book.id.hashValue) % UInt(colors.count))
        return colors[index]
    }

    private func projectRingColor(for book: Book) -> Color {
        let colors = [
            Color(hex: "76C975"),
            Color(hex: "FF95A3"),
            Color(hex: "78C4E3"),
            Color(hex: "A58BEB"),
            Color(hex: "E5B84C")
        ]
        let index = Int(UInt(bitPattern: book.id.hashValue) % UInt(colors.count))
        return colors[index]
    }

    private func projectEmoji(for book: Book) -> String {
        if book.sources.contains(where: { $0.sourceType == .pdf }) { return "\u{1F4D5}" } // red book
        if book.hasSections { return "\u{1F4DA}" } // books
        if !book.pages.isEmpty { return "\u{1F4F7}" } // camera
        return "\u{1F4D3}" // notebook
    }

    private func deleteBook(_ id: UUID) {
        if selectedProjectBook?.id == id {
            selectedProjectBook = nil
        }
        if selectedParentBook?.id == id {
            selectedParentBook = nil
        }
        if selectedBook?.id == id {
            selectedBook = nil
        }
        if pendingDeleteBook?.id == id {
            pendingDeleteBook = nil
        }
        if lastOpenedProjectId == id {
            lastOpenedProjectId = nil
        }

        viewModel.deleteBook(id)
    }

    private func statusIcon(for book: Book) -> String {
        let hasContent = !book.allPages.filter({ $0.status == .completed }).isEmpty
        return hasContent ? "play.fill" : "pencil"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            // Create New
            Button {
                let newBook = Book(title: "")
                // Don't save yet — ProjectDetailViewModel will save when first source is added
                selectedProjectBook = newBook
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("memorize.create_new".localized)
                        .font(AppTypography.subheadline)
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.lg))
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
                    .foregroundColor(Color(hex: "1F2420"))
                    }
                }
                .toolbarColorScheme(.light, for: .navigationBar)
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
                        .foregroundColor(Color(hex: "1F2420"))
                    Text("memorize.cover_capture_align_hint".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(Color(hex: "6E776F"))
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
                        .foregroundColor(Color(hex: "1F2420"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.memorizeAccent)
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
                .foregroundColor(Color(hex: "6E776F"))
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
                    .foregroundColor(Color(hex: "1F2420"))
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
                    .foregroundColor(Color(hex: "1F2420"))
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
                        .foregroundColor(Color(hex: "1F2420"))
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
                    .background(Color.white.opacity(0.94))
                    .foregroundColor(Color(hex: "1F2420"))
                    .cornerRadius(AppCornerRadius.md)

                TextField("memorize.author_field".localized, text: $newSessionAuthor)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.94))
                    .foregroundColor(Color(hex: "1F2420"))
                    .cornerRadius(AppCornerRadius.md)

                TextField("memorize.chapter_field".localized, text: $newSessionChapter)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.94))
                    .foregroundColor(Color(hex: "1F2420"))
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
                    .foregroundColor(Color(hex: "1F2420"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.memorizeAccent)
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

private struct ProjectProgressRing: View {
    let progress: CGFloat
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "E7E0D7"), lineWidth: 4)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 48, height: 48)
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
        guard onCommand != nil else { return }
        shouldListen = true
        beginListeningIfNeeded()
    }

    private func beginListeningIfNeeded() {
        guard shouldListen, onCommand != nil else { return }
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
