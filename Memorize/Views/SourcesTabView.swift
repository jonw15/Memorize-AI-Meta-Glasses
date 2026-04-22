/*
 * Sources Tab View
 * Lists all sources in a project and allows adding new ones
 */

import SwiftUI
import UniformTypeIdentifiers

struct SourcesTabView: View {
    @ObservedObject var viewModel: ProjectDetailViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel

    @State private var showAddSourceSheet = false
    @State private var didAutoShowAddSource = false
    @State private var showTextNoteEditor = false
    @State private var showCameraCapture = false
    @State private var showYouTubeImporter = false
    @State private var pendingDeleteSource: Source?
    @State private var viewingSource: Source?
    @State private var pendingAction: PendingSourceAction?
    @State private var isVisible = false

    private enum PendingSourceAction {
        case textNote, camera, file, youtube
    }

    var body: some View {
        VStack(spacing: 0) {
            // Source list
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("memorize.sources".localized)
                            .font(AppTypography.headline)
                            .foregroundColor(.white)
                        Text("memorize.sources_desc".localized)
                            .font(AppTypography.caption)
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)

                    if viewModel.book.sources.isEmpty && viewModel.book.pages.isEmpty {
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(Color.white.opacity(0.3))
                            Text("memorize.no_sources".localized)
                                .font(AppTypography.subheadline)
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        // Legacy camera pages (if any)
                        if !viewModel.book.pages.isEmpty {
                            sourceRow(
                                icon: "camera.fill",
                                name: "Camera Pages",
                                detail: "\(viewModel.book.completedPages) pages",
                                onDelete: nil
                            )
                            .onTapGesture {
                                showCameraCapture = true
                            }
                        }

                        // New-style sources
                        ForEach(viewModel.book.sources) { source in
                            if source.sourceType == .camera {
                                sourceRow(
                                    icon: source.iconName,
                                    name: source.name,
                                    detail: sourceDetail(source),
                                    onDelete: { pendingDeleteSource = source }
                                )
                                .onTapGesture {
                                    showCameraCapture = true
                                }
                            } else {
                                sourceRow(
                                    icon: source.iconName,
                                    name: source.name,
                                    detail: sourceDetail(source),
                                    onDelete: { pendingDeleteSource = source }
                                )
                                .onTapGesture {
                                    viewingSource = source
                                }
                            }
                        }
                    }

                    // PDF import progress
                    if viewModel.isImportingPDF {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(AppColors.memorizeAccent)
                                .scaleEffect(0.8)
                            if let progress = viewModel.pdfImportProgress {
                                Text("Importing \(progress.currentPage)/\(progress.totalPages) pages...")
                                    .font(AppTypography.caption)
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }

                    if viewModel.isImportingYouTube {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(AppColors.memorizeAccent)
                                .scaleEffect(0.8)
                            Text("memorize.youtube_import_loading".localized)
                                .font(AppTypography.caption)
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }

                    if let error = viewModel.pdfImportError {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, AppSpacing.md)
                    }

                    if let error = viewModel.youtubeImportError {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, AppSpacing.md)
                    }
                }
            }

            Spacer()

            // Bottom action bar
            HStack(spacing: AppSpacing.md) {
                Button {
                    showAddSourceSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("memorize.add_source".localized)
                            .font(AppTypography.subheadline)
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.lg))
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
        }
        .sheet(isPresented: $showAddSourceSheet) {
            AddSourceSheet(
                onTextNote: {
                    showAddSourceSheet = false
                    pendingAction = .textNote
                },
                onCamera: {
                    showAddSourceSheet = false
                    pendingAction = .camera
                },
                onFile: {
                    showAddSourceSheet = false
                    pendingAction = .file
                },
                onYouTube: {
                    viewModel.youtubeImportError = nil
                    showAddSourceSheet = false
                    pendingAction = .youtube
                }
            )
            .presentationDetents([.height(380)])
        }
        .onChange(of: showAddSourceSheet) { showing in
            if !showing, let action = pendingAction {
                pendingAction = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    guard isVisible else { return }
                    switch action {
                    case .textNote: showTextNoteEditor = true
                    case .youtube: showYouTubeImporter = true
                    case .camera: showCameraCapture = true
                    case .file: viewModel.showFilePicker = true
                    }
                }
            }
        }
        .sheet(isPresented: $showTextNoteEditor) {
            TextNoteEditorView { title, text in
                viewModel.addTextNote(title: title, text: text)
            }
        }
        .sheet(isPresented: $showYouTubeImporter) {
            YouTubeLinkImportView(
                isImporting: viewModel.isImportingYouTube,
                errorMessage: viewModel.youtubeImportError
            ) { link in
                Task {
                    await viewModel.importYouTubeTranscript(from: link)
                    if viewModel.youtubeImportError == nil {
                        showYouTubeImporter = false
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCameraCapture, onDismiss: {
            viewModel.reload()
        }) {
            MemorizeCaptureView(
                streamViewModel: streamViewModel,
                book: viewModel.book
            )
        }
        .alert(item: $pendingDeleteSource) { source in
            Alert(
                title: Text("Delete Source"),
                message: Text("Delete \"\(source.name)\"?"),
                primaryButton: .destructive(Text("memorize.delete_session_confirm".localized)) {
                    viewModel.deleteSource(source.id)
                },
                secondaryButton: .cancel()
            )
        }
        .fullScreenCover(item: $viewingSource) { source in
            SourceTextView(
                source: source,
                projectTitle: viewModel.book.title,
                projectSectionTitle: viewModel.book.chapter
            )
        }
        .onAppear {
            isVisible = true
            // Auto-open add source sheet only for brand-new empty projects (no title, no sources)
            if !didAutoShowAddSource
                && viewModel.book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && viewModel.book.sources.isEmpty
                && viewModel.book.pages.isEmpty {
                didAutoShowAddSource = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    guard isVisible else { return }
                    showAddSourceSheet = true
                }
            }
        }
        .onDisappear {
            isVisible = false
            showAddSourceSheet = false
            pendingAction = nil
        }
    }

    private func sourceRow(icon: String, name: String, detail: String, onDelete: (() -> Void)?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.memorizeAccent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(AppTypography.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundColor(Color.white.opacity(0.5))
            }

            Spacer()

            if let onDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    private func sourceDetail(_ source: Source) -> String {
        let pageCount = source.completedPages
        switch source.sourceType {
        case .pdf:
            return "\(pageCount) pages"
        case .camera:
            return "\(pageCount) photos"
        case .textNote:
            return "Text note"
        case .file:
            return "Imported file"
        case .youtube:
            return "YouTube transcript"
        }
    }

}

// MARK: - Source Text View

struct SourceTextView: View {
    let source: Source
    let projectTitle: String
    let projectSectionTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var showReadAloud = false

    private var allText: String {
        source.pages
            .filter { $0.status == .completed }
            .map { $0.extractedText }
            .joined(separator: "\n\n")
    }

    private var readAloudBookTitle: String {
        let trimmedProjectTitle = projectTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedProjectTitle.isEmpty ? source.name : trimmedProjectTitle
    }

    private var readAloudSectionTitle: String {
        let trimmedProjectSection = projectSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSourceName = source.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedProjectSection.isEmpty {
            return trimmedProjectSection
        }

        if trimmedSourceName != readAloudBookTitle {
            return trimmedSourceName
        }

        return ""
    }

    private var displayText: String {
        guard source.sourceType == .youtube else { return allText }
        return paragraphizedYouTubeTranscript(allText)
    }

    private func paragraphizedYouTubeTranscript(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return "" }

        let sentencePattern = #"[^.!?]+(?:[.!?]+|$)"#
        let regex = try? NSRegularExpression(pattern: sentencePattern)
        let nsRange = NSRange(normalized.startIndex..., in: normalized)
        let sentenceMatches = regex?.matches(in: normalized, range: nsRange) ?? []

        let sentences = sentenceMatches.compactMap { match -> String? in
            guard let range = Range(match.range, in: normalized) else { return nil }
            let sentence = normalized[range].trimmingCharacters(in: .whitespacesAndNewlines)
            return sentence.isEmpty ? nil : sentence
        }

        if sentences.isEmpty {
            return normalized
        }

        var paragraphs: [String] = []
        var currentSentences: [String] = []
        var currentLength = 0

        for sentence in sentences {
            let sentenceLength = sentence.count
            let projectedLength = currentLength + (currentSentences.isEmpty ? 0 : 1) + sentenceLength
            let shouldBreak =
                !currentSentences.isEmpty &&
                (
                    currentSentences.count >= 3 ||
                    projectedLength >= 360 ||
                    (currentLength >= 180 && sentenceLength >= 120)
                )

            if shouldBreak {
                paragraphs.append(currentSentences.joined(separator: " "))
                currentSentences = [sentence]
                currentLength = sentenceLength
            } else {
                currentSentences.append(sentence)
                currentLength = projectedLength
            }
        }

        if !currentSentences.isEmpty {
            paragraphs.append(currentSentences.joined(separator: " "))
        }

        return paragraphs.joined(separator: "\n\n")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    // Source info
                    HStack(spacing: 10) {
                        Image(systemName: source.iconName)
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.memorizeAccent)
                        Text(source.sourceType == .pdf ? "\(source.pages.count) pages" : "")
                            .font(AppTypography.caption)
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, AppSpacing.xs)

                    if !allText.isEmpty {
                        Button {
                            showReadAloud = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("memorize.read_aloud".localized)
                                    .font(AppTypography.subheadline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.memorizeAccent.opacity(0.9))
                            .cornerRadius(AppCornerRadius.md)
                        }
                    }

                    if allText.isEmpty {
                        Text("No text content available")
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color.white.opacity(0.4))
                            .padding(.top, AppSpacing.xl)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(displayText)
                            .font(AppTypography.body)
                            .foregroundColor(.white)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle(source.name)
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
        .fullScreenCover(isPresented: $showReadAloud) {
            MemorizeReadAloudView(
                pages: source.pages,
                bookTitle: readAloudBookTitle,
                sectionTitle: readAloudSectionTitle
            )
        }
    }
}

// Make Source conform to Identifiable for alert binding
extension Source: Equatable {
    static func == (lhs: Source, rhs: Source) -> Bool {
        lhs.id == rhs.id
    }
}

struct YouTubeLinkImportView: View {
    let isImporting: Bool
    let errorMessage: String?
    let onImport: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var link = ""

    private var trimmedLink: String {
        link.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !trimmedLink.isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.md) {
                Text("memorize.source_youtube_desc".localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("memorize.youtube_link_placeholder".localized, text: $link)
                    .font(AppTypography.body)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .padding(AppSpacing.sm)
                    .background(AppColors.memorizeCard)
                    .cornerRadius(AppCornerRadius.md)

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(.red.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    onImport(trimmedLink)
                } label: {
                    HStack(spacing: 8) {
                        if isImporting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text("memorize.youtube_import_button".localized)
                            .font(AppTypography.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background((isValid && !isImporting) ? AppColors.memorizeAccent : Color.white.opacity(0.1))
                    .cornerRadius(AppCornerRadius.md)
                }
                .disabled(!isValid || isImporting)

                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("memorize.youtube_import_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("memorize.cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .disabled(isImporting)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
