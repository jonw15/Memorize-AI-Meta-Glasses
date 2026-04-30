/*
 * Sources Tab View
 * Lists all sources in a project and allows adding new ones
 */

import SwiftUI
import UniformTypeIdentifiers

struct SourcesTabView: View {
    @ObservedObject var viewModel: ProjectDetailViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel

    @Environment(\.dismiss) private var dismiss
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
            Capsule()
                .fill(Color(hex: "E2DDD4"))
                .frame(width: 64, height: 5)
                .padding(.top, 22)
                .padding(.bottom, 24)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    sourcesHeader
                    actionTiles
                    projectSourcesSection
                    progressAndErrors
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 36)
            }
        }
        .background(Color(hex: "FCF7EF").ignoresSafeArea())
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
        }
        .onDisappear {
            isVisible = false
            showAddSourceSheet = false
            pendingAction = nil
        }
    }

    private var sourcesHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("memorize.sources".localized)
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundColor(Color(hex: "1F2420"))

                Text("memorize.sources_sheet_desc".localized)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "8D958E"))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "1F2420"))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "E8E0D7"), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var actionTiles: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            sourceActionTile(
                icon: "arrow.up.to.line",
                title: "memorize.upload_pdf".localized,
                tint: Color(hex: "CFEFFF"),
                foreground: Color(hex: "20657E")
            ) {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    viewModel.showFilePicker = true
                }
            }

            sourceActionTile(
                icon: "camera",
                title: "memorize.source_camera".localized,
                tint: Color(hex: "D6F4D8"),
                foreground: Color(hex: "276B32")
            ) {
                showCameraCapture = true
            }

            sourceActionTile(
                icon: "eyeglasses",
                title: "memorize.source_glasses".localized,
                tint: Color(hex: "FFE1E5"),
                foreground: Color(hex: "9A3B4B")
            ) {
                showCameraCapture = true
            }

            sourceActionTile(
                icon: "play.rectangle.fill",
                title: "YouTube",
                tint: Color(hex: "FCE3E3"),
                foreground: Color(hex: "B0444C")
            ) {
                viewModel.youtubeImportError = nil
                showYouTubeImporter = true
            }
        }
    }

    private func sourceActionTile(
        icon: String,
        title: String,
        tint: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(foreground)
                    .frame(width: 40, height: 40)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "1F2420"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var projectSourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("memorize.in_this_project".localized)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(Color(hex: "8D958E"))

                Text("·")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "8D958E").opacity(0.7))

                Text("\(projectSourceCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "8D958E"))
            }

            if viewModel.book.sources.isEmpty && viewModel.book.pages.isEmpty {
                emptySourceCard
            } else {
                VStack(spacing: 14) {
                    if !viewModel.book.pages.isEmpty {
                        sourceCard(
                            icon: "camera.fill",
                            title: "Camera Pages",
                            category: "PHOTO",
                            detail: "\(viewModel.book.completedPages) pages",
                            tint: Color(hex: "FFE9B8"),
                            foreground: Color(hex: "8A641F"),
                            onDelete: nil
                        ) {
                            showCameraCapture = true
                        }
                    }

                    ForEach(viewModel.book.sources) { source in
                        sourceCard(for: source)
                    }
                }
            }
        }
    }

    private var projectSourceCount: Int {
        viewModel.book.sources.count + (viewModel.book.pages.isEmpty ? 0 : 1)
    }

    private var emptySourceCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(Color(hex: "8D958E"))
            Text("memorize.no_sources".localized)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "6E776F"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
        )
    }

    private var progressAndErrors: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isImportingPDF {
                progressRow(text: viewModel.pdfImportProgress.map { "Importing \($0.currentPage)/\($0.totalPages) pages..." } ?? "Loading...")
            }

            if viewModel.isImportingYouTube {
                progressRow(text: "memorize.youtube_import_loading".localized)
            }

            if let error = viewModel.pdfImportError {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundColor(.red.opacity(0.8))
            }

            if let error = viewModel.youtubeImportError {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundColor(.red.opacity(0.8))
            }
        }
    }

    private func progressRow(text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(Color(hex: "2F6A3F"))
                .scaleEffect(0.8)
            Text(text)
                .font(AppTypography.caption)
                .foregroundColor(Color(hex: "6E776F"))
        }
    }

    private func sourceCard(for source: Source) -> some View {
        let style = sourceStyle(for: source)
        return sourceCard(
            icon: source.iconName,
            title: source.name,
            category: sourceCategory(source),
            detail: sourceDetail(source),
            tint: style.tint,
            foreground: style.foreground,
            onDelete: { pendingDeleteSource = source }
        ) {
            if source.sourceType == .camera {
                showCameraCapture = true
            } else {
                viewingSource = source
            }
        }
    }

    private func sourceCard(
        icon: String,
        title: String,
        category: String,
        detail: String,
        tint: Color,
        foreground: Color,
        onDelete: (() -> Void)?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(foreground)
                    .frame(width: 40, height: 40)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(category)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundColor(Color(hex: "A0A49D"))

                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(detail)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "8D958E"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 6)

                if let onDelete {
                    Menu {
                        Button(role: .destructive, action: onDelete) {
                            Label("memorize.delete_session_confirm".localized, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "9DA49D"))
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "9DA49D"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
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
        .background(AppColors.memorizeCard)
        .cornerRadius(AppCornerRadius.md)
        .padding(.horizontal, AppSpacing.md)
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

    private func sourceCategory(_ source: Source) -> String {
        switch source.sourceType {
        case .pdf: return "PDF"
        case .camera: return "CAPTURE"
        case .textNote: return "LECTURE"
        case .file: return "FILE"
        case .youtube: return "VIDEO"
        }
    }

    private func sourceStyle(for source: Source) -> (tint: Color, foreground: Color) {
        switch source.sourceType {
        case .pdf:
            return (Color(hex: "CFEFFF"), Color(hex: "20657E"))
        case .camera:
            return (Color(hex: "FFE9B8"), Color(hex: "8A641F"))
        case .textNote:
            return (Color(hex: "D6F4D8"), Color(hex: "276B32"))
        case .file:
            return (Color(hex: "E5E3FF"), Color(hex: "524A98"))
        case .youtube:
            return (Color(hex: "FFE1E5"), Color(hex: "9A3B4B"))
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
                            .foregroundColor(Color(hex: "8D958E"))
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
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(Color(hex: "1F2420"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.memorizeAccent)
                            .cornerRadius(AppCornerRadius.md)
                        }
                    }

                    if allText.isEmpty {
                        Text("No text content available")
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color(hex: "8D958E"))
                            .padding(.top, AppSpacing.xl)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(displayText)
                            .font(AppTypography.body)
                            .foregroundColor(Color(hex: "1F2420"))
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
                            .foregroundColor(Color(hex: "1F2420"))
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
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
                    .foregroundColor(Color(hex: "6E776F"))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack(alignment: .leading) {
                    if link.isEmpty {
                        Text("memorize.youtube_link_placeholder".localized)
                            .font(AppTypography.body)
                            .foregroundColor(Color(hex: "8D958E"))
                            .padding(.horizontal, AppSpacing.sm)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $link)
                        .font(AppTypography.body)
                        .foregroundColor(Color(hex: "1F2420"))
                        .tint(Color(hex: "276B32"))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .padding(AppSpacing.sm)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                        .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
                )

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
                    .foregroundColor(Color(hex: "1F2420"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background((isValid && !isImporting) ? AppColors.memorizeAccent : Color(hex: "EAE4DC"))
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
                    .foregroundColor(Color(hex: "1F2420"))
                    .disabled(isImporting)
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}
