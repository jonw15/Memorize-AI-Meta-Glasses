/*
 * Project Detail View
 * Container with Sources and Study bottom tabs for a single project
 */

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import Speech

struct ProjectDetailView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @StateObject private var viewModel: ProjectDetailViewModel
    @Environment(\.dismiss) private var dismiss
    private let onDeleteProject: (UUID) -> Void

    @State private var selectedTab: ProjectTab = .study
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showTutor = false
    @State private var showLiveMode = false
    @State private var showSourcesPanel = false
    @State private var isDeletingProject = false
    @State private var tutorStartedAt: Date?
    @State private var hasAutoOpenedSources = false
    private let minimumNoteGenerationDuration: TimeInterval = 10

    enum ProjectTab {
        case study, notes, create
    }

    init(
        book: Book,
        streamViewModel: StreamSessionViewModel,
        onDeleteProject: @escaping (UUID) -> Void = { _ in }
    ) {
        self.streamViewModel = streamViewModel
        self._viewModel = StateObject(wrappedValue: ProjectDetailViewModel(book: book))
        self.onDeleteProject = onDeleteProject
    }

    var body: some View {
        navigationContainer
            .onAppear {
                viewModel.reload()
                autoOpenSourcesIfEmpty()
            }
            .fileImporter(
                isPresented: $viewModel.showFilePicker,
                allowedContentTypes: [.pdf, .text, .plainText, UTType(filenameExtension: "docx")].compactMap { $0 },
                allowsMultipleSelection: false,
                onCompletion: handleFileImport
            )
            .alert("Rename Project", isPresented: $showRenameAlert) {
                TextField("Project name", text: $renameText)
                Button("Save") {
                    viewModel.renameProject(to: renameText)
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("memorize.notes_error_title".localized, isPresented: noteErrorPresented) {
                Button("OK", role: .cancel) {
                    viewModel.noteGenerationError = nil
                }
            } message: {
                Text(viewModel.noteGenerationError ?? "")
            }
            .alert("Slide Deck Error", isPresented: slideDeckErrorPresented) {
                Button("OK", role: .cancel) {
                    viewModel.slideDeckGenerationError = nil
                }
            } message: {
                Text(viewModel.slideDeckGenerationError ?? "")
            }
            .alert("Paper Error", isPresented: paperErrorPresented) {
                Button("OK", role: .cancel) {
                    viewModel.paperGenerationError = nil
                }
            } message: {
                Text(viewModel.paperGenerationError ?? "")
            }
            .sheet(item: $viewModel.generatedNoteDraft) { note in
                GeneratedNoteDraftView(
                    note: note,
                    onClose: {
                        viewModel.discardGeneratedNote()
                    },
                    onSave: {
                        viewModel.saveGeneratedNote(note)
                        selectedTab = .notes
                    }
                )
            }
            .sheet(item: $viewModel.generatedSlideDeckDraft) { deck in
                GeneratedSlideDeckDraftView(
                    deck: deck,
                    onClose: {
                        viewModel.discardGeneratedSlideDeck()
                    }
                )
            }
            .sheet(item: $viewModel.generatedPaperDraft) { paper in
                GeneratedPaperDraftView(
                    paper: paper,
                    onClose: {
                        viewModel.discardGeneratedPaper()
                    }
                )
            }
            .overlay {
                noteGenerationOverlay
            }
            .fullScreenCover(isPresented: $showLiveMode) {
                ProjectLiveModeView(streamViewModel: streamViewModel)
            }
            .sheet(isPresented: $showSourcesPanel) {
                SourcesTabView(viewModel: viewModel, streamViewModel: streamViewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(34)
            }
            .fullScreenCover(isPresented: $showTutor, onDismiss: {
                finishTutorSessionForNotes()
            }) {
                TutorTabView(viewModel: viewModel) { messages in
                    viewModel.captureSessionMessages(messages, for: .tutor)
                }
                .onAppear {
                    tutorStartedAt = Date()
                }
            }
    }

    private var navigationContainer: some View {
        NavigationView {
            VStack(spacing: 0) {
                tabContent
                bottomTabBar
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle(viewModel.book.title.isEmpty ? "memorize.untitled".localized : viewModel.book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "1F2420"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            renameText = viewModel.book.title
                            showRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteProject()
                        } label: {
                            Label("memorize.delete_session_confirm".localized, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(Color(hex: "1F2420"))
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    private var liveModeBanner: some View {
        Button {
            showLiveMode = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 42, height: 42)
                    .background(AppColors.memorizeAccent)
                    .cornerRadius(AppCornerRadius.sm)

                VStack(alignment: .leading, spacing: 3) {
                    Text("memorize.live_mode".localized)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                    Text("memorize.live_mode_desc".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.35))
            }
            .padding(AppSpacing.md)
            .background(AppColors.memorizeCard)
            .cornerRadius(AppCornerRadius.lg)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .study:
            StudyTabView(
                viewModel: viewModel,
                onShowSources: { showSourcesPanel = true },
                onShowLive: { showLiveMode = true },
                onShowTutor: {
                    showTutor = true
                }
            ) { mode in
                viewModel.generateNoteDraft(after: mode)
            }
        case .notes:
            NotesTabView(viewModel: viewModel)
        case .create:
            CreateTabView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var noteGenerationOverlay: some View {
        if viewModel.isGeneratingNoteDraft || viewModel.isGeneratingSlideDeck || viewModel.isGeneratingPaper || viewModel.isGeneratingBulletPoints {
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                    Text(generationStatusText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "1F2420"))
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
                .padding(.bottom, 96)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
        }
    }

    private var noteErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.noteGenerationError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.noteGenerationError = nil
                }
            }
        )
    }

    private var generationStatusText: String {
        if viewModel.isGeneratingSlideDeck {
            return "Generating slide deck..."
        }
        if viewModel.isGeneratingBulletPoints {
            return "Generating bullet points..."
        }
        if viewModel.isGeneratingPaper {
            return "Generating paper..."
        }
        return "memorize.notes_generating".localized
    }

    private var slideDeckErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.slideDeckGenerationError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.slideDeckGenerationError = nil
                }
            }
        )
    }

    private var paperErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.paperGenerationError != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.paperGenerationError = nil
                }
            }
        )
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            if url.pathExtension.lowercased() == "pdf" {
                Task { await viewModel.importPDF(from: url) }
            } else {
                importFile(from: url)
            }
        case .failure(let error):
            viewModel.pdfImportError = error.localizedDescription
        }
    }

    private func autoOpenSourcesIfEmpty() {
        guard !hasAutoOpenedSources else { return }
        let hasAnySources = !viewModel.book.sources.isEmpty || !viewModel.book.pages.isEmpty
        guard !hasAnySources else { return }
        hasAutoOpenedSources = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            showSourcesPanel = true
        }
    }

    private func finishTutorSessionForNotes() {
        defer { tutorStartedAt = nil }

        guard let start = tutorStartedAt,
              Date().timeIntervalSince(start) >= minimumNoteGenerationDuration else {
            viewModel.clearSessionCapture(for: .tutor)
            return
        }

        viewModel.generateNoteDraft(after: .tutor)
    }

    private func deleteProject() {
        guard !isDeletingProject else { return }
        isDeletingProject = true
        let bookID = viewModel.book.id
        dismiss()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            onDeleteProject(bookID)
        }
    }

    private func importFile(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        print("📂 [Import] URL: \(url.lastPathComponent), ext: \(url.pathExtension), securityAccess: \(accessed)")

        let ext = url.pathExtension.lowercased()
        let name = url.deletingPathExtension().lastPathComponent

        do {
            // Copy to temp location first
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
            try FileManager.default.copyItem(at: url, to: tempURL)
            if accessed { url.stopAccessingSecurityScopedResource() }
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let tempSize = (try? Data(contentsOf: tempURL).count) ?? 0
            print("📂 [Import] Copied to temp: \(tempURL.lastPathComponent), size: \(tempSize)")

            let text: String
            if ext == "docx" {
                text = try extractTextFromDocx(url: tempURL)
                print("📂 [Import] DOCX extracted \(text.count) chars")
            } else {
                text = try String(contentsOf: tempURL, encoding: .utf8)
                print("📂 [Import] Text file read \(text.count) chars")
            }

            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                viewModel.pdfImportError = "No text content found in the file."
                return
            }

            let page = PageCapture(pageNumber: 1, extractedText: text, status: .completed)
            let source = Source(name: name, sourceType: .file, pages: [page])
            viewModel.addSource(source)
        } catch {
            if accessed { url.stopAccessingSecurityScopedResource() }
            print("❌ [Import] Failed: \(error)")
            viewModel.pdfImportError = "Failed to read file: \(error.localizedDescription)"
        }
    }

    /// Extract plain text from a .docx file by parsing the XML inside the ZIP
    private func extractTextFromDocx(url: URL) throws -> String {
        let data = try Data(contentsOf: url)

        // docx is a ZIP; find "word/document.xml" entry and extract text from <w:t> tags
        guard let xmlString = findDocumentXML(in: data) else {
            throw NSError(domain: "DocxImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read .docx content"])
        }

        // Simple regex extraction of text between <w:t ...> and </w:t>
        var paragraphs: [String] = []
        var currentParagraph = ""

        // Split on paragraph markers <w:p ...> ... </w:p>
        let pPattern = try NSRegularExpression(pattern: "<w:p[ >].*?</w:p>", options: .dotMatchesLineSeparators)
        let pMatches = pPattern.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))

        if pMatches.isEmpty {
            // Fallback: just extract all <w:t> content
            let tPattern = try NSRegularExpression(pattern: "<w:t[^>]*>([^<]*)</w:t>")
            let tMatches = tPattern.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
            let texts = tMatches.compactMap { Range($0.range(at: 1), in: xmlString).map { String(xmlString[$0]) } }
            return texts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for pMatch in pMatches {
            guard let pRange = Range(pMatch.range, in: xmlString) else { continue }
            let pContent = String(xmlString[pRange])

            let tPattern = try NSRegularExpression(pattern: "<w:t[^>]*>([^<]*)</w:t>")
            let tMatches = tPattern.matches(in: pContent, range: NSRange(pContent.startIndex..., in: pContent))
            currentParagraph = tMatches.compactMap { Range($0.range(at: 1), in: pContent).map { String(pContent[$0]) } }.joined()

            if !currentParagraph.trimmingCharacters(in: .whitespaces).isEmpty {
                paragraphs.append(currentParagraph)
            }
        }

        let text = paragraphs.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw NSError(domain: "DocxImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "No text content found in .docx file"])
        }
        return text
    }

    /// Locate and decompress word/document.xml from a ZIP (docx) data blob
    private func findDocumentXML(in data: Data) -> String? {
        let target = "word/document.xml"

        // Use the Central Directory (at end of ZIP) which always has correct sizes
        // Find End of Central Directory record: signature PK\x05\x06
        var eocdPos = data.count - 22
        while eocdPos >= 0 {
            if data[eocdPos] == 0x50, data[eocdPos+1] == 0x4B,
               data[eocdPos+2] == 0x05, data[eocdPos+3] == 0x06 {
                break
            }
            eocdPos -= 1
        }
        guard eocdPos >= 0, eocdPos + 22 <= data.count else {
            print("📂 [DOCX] No EOCD found")
            return nil
        }

        let cdOffset = Int(UInt32(data[eocdPos+16]) | (UInt32(data[eocdPos+17]) << 8) |
                            (UInt32(data[eocdPos+18]) << 16) | (UInt32(data[eocdPos+19]) << 24))
        let cdSize = Int(UInt32(data[eocdPos+12]) | (UInt32(data[eocdPos+13]) << 8) |
                          (UInt32(data[eocdPos+14]) << 16) | (UInt32(data[eocdPos+15]) << 24))

        // Walk central directory entries (PK\x01\x02)
        var pos = cdOffset
        let cdEnd = cdOffset + cdSize
        while pos + 46 < cdEnd, pos + 46 < data.count {
            guard data[pos] == 0x50, data[pos+1] == 0x4B,
                  data[pos+2] == 0x01, data[pos+3] == 0x02 else { break }

            let method = UInt16(data[pos+10]) | (UInt16(data[pos+11]) << 8)
            let compSize = Int(UInt32(data[pos+20]) | (UInt32(data[pos+21]) << 8) | (UInt32(data[pos+22]) << 16) | (UInt32(data[pos+23]) << 24))
            let nameLen = Int(UInt16(data[pos+28]) | (UInt16(data[pos+29]) << 8))
            let extraLen = Int(UInt16(data[pos+30]) | (UInt16(data[pos+31]) << 8))
            let commentLen = Int(UInt16(data[pos+32]) | (UInt16(data[pos+33]) << 8))
            let localHeaderOffset = Int(UInt32(data[pos+42]) | (UInt32(data[pos+43]) << 8) | (UInt32(data[pos+44]) << 16) | (UInt32(data[pos+45]) << 24))

            let nameStart = pos + 46
            let nameEnd = nameStart + nameLen
            guard nameEnd <= data.count else { break }
            let fileName = String(data: data[nameStart..<nameEnd], encoding: .utf8) ?? ""

            if fileName == target {
                // Read from local file header to get the actual data
                let lh = localHeaderOffset
                guard lh + 30 <= data.count else { return nil }
                let lhNameLen = Int(UInt16(data[lh+26]) | (UInt16(data[lh+27]) << 8))
                let lhExtraLen = Int(UInt16(data[lh+28]) | (UInt16(data[lh+29]) << 8))
                let dataStart = lh + 30 + lhNameLen + lhExtraLen
                let dataEnd = dataStart + compSize
                guard dataEnd <= data.count else { return nil }

                let payload = data[dataStart..<dataEnd]
                print("📂 [DOCX] Found \(target), method=\(method), compSize=\(compSize), payload=\(payload.count) bytes")

                if method == 0 {
                    return String(data: payload, encoding: .utf8)
                } else if method == 8 {
                    if let decompressed = try? (payload as NSData).decompressed(using: .zlib) as Data {
                        return String(data: decompressed, encoding: .utf8)
                    }
                    return nil
                }
                return nil
            }

            pos = nameEnd + extraLen + commentLen
        }

        print("📂 [DOCX] word/document.xml not found in central directory")
        return nil
    }

    private var bottomTabBar: some View {
        HStack(spacing: 10) {
            tabButton(tab: .study, icon: "leaf", label: "Learn")
            tabButton(tab: .notes, icon: "textformat", label: "memorize.notes".localized)
            tabButton(tab: .create, icon: "pencil", label: "Create")
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(
            LinearGradient(
                colors: [Color(hex: "F9CED6"), Color(hex: "D8F1E9")],
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(tab: ProjectTab, icon: String, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                Text(label)
                    .font(AppTypography.caption)
            }
            .foregroundColor(selectedTab == tab ? Color(hex: "2F6A3F") : Color(hex: "8D958E"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(selectedTab == tab ? Color(hex: "D8F7D8") : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Create Tab

private struct CreateTabView: View {
    @ObservedObject var viewModel: ProjectDetailViewModel
    @State private var showInfographics = false
    @State private var customizationKind: CreateOutputKind?
    @State private var infographicBundlesOverride: [InfographicSourceBundle]?
    @State private var promptIdea: String = CreateTabView.promptIdeas.randomElement() ?? "Make a 10-slide deck on photosynthesis from my notes."

    static let promptIdeas: [String] = [
        "Make a 10-slide deck on photosynthesis from my notes.",
        "Turn chapter 3 into a one-page study guide I can review tonight.",
        "Write a 3-page paper that explains the main argument in plain English.",
        "Build an infographic that maps the key terms to real-world examples.",
        "Quiz me on the trickiest ideas from this week's reading.",
        "Summarize this in two paragraphs a curious friend would actually read.",
        "Draft a teaching script I can read aloud in five minutes.",
        "Pull out the five questions a professor would ask on the final.",
        "Show me a story that illustrates the cause-and-effect chain in this chapter.",
        "Make flashcards for the terms I'm most likely to forget.",
        "Sketch a slide deck my study group can use next session.",
        "Give me an analogy for the hardest concept in here."
    ]

    private var completedPages: [PageCapture] {
        viewModel.allCompletedPages
    }

    private var bookTitle: String {
        viewModel.book.title.isEmpty ? "memorize.untitled".localized : viewModel.book.title
    }

    private var projectEyebrow: String {
        bookTitle.uppercased()
    }

    private var hasContent: Bool {
        !completedPages.isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                createHeader
                promptCard
                makeSection
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(Color(hex: "FCF7EF"))
        .fullScreenCover(isPresented: $viewModel.showQuiz, onDismiss: {
            viewModel.recordQuizCompletion()
        }) {
            MemorizeQuizView(questions: $viewModel.quizQuestions)
        }
        .fullScreenCover(isPresented: $showInfographics) {
            let bundles = infographicBundlesOverride ?? infographicSourceBundles
            MemorizeInfographicsView(
                pages: bundles.flatMap(\.pages),
                bookTitle: bookTitle,
                sectionTitle: viewModel.book.chapter,
                sourceBundles: bundles
            )
        }
        .sheet(item: $customizationKind) { kind in
            CreateCustomizationSheet(
                kind: kind,
                sourceBundles: infographicSourceBundles,
                savedNotes: viewModel.book.notes,
                onGenerate: handleCustomization
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(32)
        }
    }

    private var createHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(projectEyebrow)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .tracking(0.2)
                .foregroundColor(Color(hex: "8D958E"))
                .lineLimit(2)

            Text("Create")
                .font(.system(size: 36, weight: .regular, design: .serif))
                .foregroundColor(Color(hex: "1F2420"))
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                Text("TURN YOUR LEARNING INTO...")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(0.4)
            }
            .foregroundColor(Color(hex: "943C4A"))

            Text(promptIdea)
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundColor(Color(hex: "1F2420"))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        var next = CreateTabView.promptIdeas.randomElement() ?? promptIdea
                        if CreateTabView.promptIdeas.count > 1 {
                            while next == promptIdea {
                                next = CreateTabView.promptIdeas.randomElement() ?? promptIdea
                            }
                        }
                        promptIdea = next
                    }
                }

            FlowLayout(spacing: 8, lineSpacing: 8) {
                promptChip("8-slide deck", action: { customizationKind = .slideDeck })
                promptChip("Study guide", action: { customizationKind = .studyGuide })
                promptChip("Infographic", action: {
                    infographicBundlesOverride = nil
                    showInfographics = true
                })
                promptChip("Paper", action: { customizationKind = .paper })
                promptChip("Bullet points", action: { customizationKind = .bulletPoints })
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FFE3E7"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "FF98A6"), lineWidth: 1)
        )
    }

    private func promptChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "943C4A"))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.74))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "FF98A6"), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!hasContent)
        .opacity(hasContent ? 1 : 0.55)
    }

    private var makeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHAT DO YOU WANT TO MAKE?")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundColor(Color(hex: "535B54"))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                createCard(
                    title: "Slide deck",
                    subtitle: "Presentation-ready",
                    icon: "display",
                    tint: Color(hex: "FFE1E5"),
                    foreground: Color(hex: "943C4A"),
                    action: { customizationKind = .slideDeck }
                )

                createCard(
                    title: "Infographic",
                    subtitle: "One-page visual",
                    icon: "photo",
                    tint: Color(hex: "CFEFFF"),
                    foreground: Color(hex: "20657E"),
                    action: {
                        infographicBundlesOverride = nil
                        showInfographics = true
                    }
                )

                createCard(
                    title: "Study guide",
                    subtitle: "Outlined & structured",
                    icon: "book.closed",
                    tint: Color(hex: "D6F4D8"),
                    foreground: Color(hex: "276B32"),
                    action: { customizationKind = .studyGuide }
                )

                createCard(
                    title: "Paper",
                    subtitle: "Essay or research write-up",
                    icon: "pencil",
                    tint: Color(hex: "CFEFFF"),
                    foreground: Color(hex: "20657E"),
                    action: { customizationKind = .paper }
                )

                createCard(
                    title: "Bullet points",
                    subtitle: "Key takeaways as a list",
                    icon: "list.bullet",
                    tint: Color(hex: "FFE9B8"),
                    foreground: Color(hex: "8A641F"),
                    action: { customizationKind = .bulletPoints }
                )
            }
        }
    }

    private func createCard(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(foreground)
                    .frame(width: 50, height: 50)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(subtitle)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "8D958E"))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
            .padding(18)
            .background(Color.white.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!hasContent || viewModel.isGeneratingQuiz || viewModel.isGeneratingNoteDraft || viewModel.isGeneratingSlideDeck || viewModel.isGeneratingPaper || viewModel.isGeneratingBulletPoints)
        .opacity(hasContent ? 1 : 0.45)
    }

    private func handleCustomization(_ config: CreateCustomization) {
        customizationKind = nil
        let selectedBundles = config.selectedBundles
        let instructions = config.instructions

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            switch config.kind {
            case .infographic:
                infographicBundlesOverride = selectedBundles
                showInfographics = true
            case .slideDeck:
                viewModel.generateSlideDeck(
                    from: selectedBundles.flatMap(\.pages),
                    customInstructions: instructions
                )
            case .paper:
                viewModel.generatePaper(
                    from: selectedBundles.flatMap(\.pages),
                    customInstructions: instructions
                )
            case .studyGuide:
                viewModel.generateNoteDraft(
                    after: config.kind.noteMode,
                    from: selectedBundles.flatMap(\.pages),
                    customInstructions: instructions
                )
            case .bulletPoints:
                viewModel.generateBulletPoints(
                    from: selectedBundles.flatMap(\.pages),
                    customInstructions: instructions
                )
            }
        }
    }

    private var infographicSourceBundles: [InfographicSourceBundle] {
        var bundles: [InfographicSourceBundle] = []

        let legacyPages = viewModel.book.pages.filter { $0.status == .completed }
        if !legacyPages.isEmpty {
            bundles.append(
                InfographicSourceBundle(
                    title: "memorize.source_camera".localized,
                    pages: legacyPages
                )
            )
        }

        for source in viewModel.book.sources {
            let completed = source.pages.filter { $0.status == .completed }
            guard !completed.isEmpty else { continue }
            bundles.append(InfographicSourceBundle(title: source.name, pages: completed))
        }

        if bundles.isEmpty && !completedPages.isEmpty {
            bundles.append(
                InfographicSourceBundle(
                    title: "memorize.sources".localized,
                    pages: completedPages
                )
            )
        }

        return bundles
    }
}

private enum CreateOutputKind: String, Identifiable {
    case slideDeck
    case studyGuide
    case paper
    case infographic
    case bulletPoints

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slideDeck: return "Slide deck"
        case .studyGuide: return "Study guide"
        case .paper: return "Paper"
        case .infographic: return "Infographic"
        case .bulletPoints: return "Bullet points"
        }
    }

    var subtitle: String {
        switch self {
        case .slideDeck: return "Set the slide count, source mix, and focus."
        case .studyGuide: return "Choose how deep the outline should go."
        case .paper: return "Tune the length and research angle."
        case .infographic: return "Pick the scope before opening the visual builder."
        case .bulletPoints: return "Pick the depth and angle before generating."
        }
    }

    var icon: String {
        switch self {
        case .slideDeck: return "display"
        case .studyGuide: return "book.closed"
        case .paper: return "pencil"
        case .infographic: return "photo"
        case .bulletPoints: return "list.bullet"
        }
    }

    var tint: Color {
        switch self {
        case .slideDeck, .paper: return Color(hex: "FFE1E5")
        case .studyGuide: return Color(hex: "D6F4D8")
        case .infographic: return Color(hex: "CFEFFF")
        case .bulletPoints: return Color(hex: "FFE9B8")
        }
    }

    var foreground: Color {
        switch self {
        case .slideDeck, .paper: return Color(hex: "943C4A")
        case .studyGuide: return Color(hex: "276B32")
        case .infographic: return Color(hex: "20657E")
        case .bulletPoints: return Color(hex: "8A641F")
        }
    }

    var noteMode: GeneratedNoteKind {
        switch self {
        case .slideDeck, .infographic:
            return .infographics
        case .studyGuide:
            return .studyGuide
        case .paper, .bulletPoints:
            return .voiceSummary
        }
    }

    var lengthOptions: [String] {
        switch self {
        case .slideDeck:
            return ["6 slides", "10 slides", "14 slides"]
        case .studyGuide:
            return ["Quick", "Standard", "Detailed"]
        case .paper:
            return ["1 page", "3 pages", "5 pages"]
        case .infographic:
            return ["Simple", "Standard", "Detailed"]
        case .bulletPoints:
            return ["Tight (5-7)", "Standard (8-12)", "Detailed (13-18)"]
        }
    }

    var defaultLength: String {
        switch self {
        case .slideDeck:
            return "10 slides"
        case .studyGuide, .infographic:
            return "Standard"
        case .paper:
            return "3 pages"
        case .bulletPoints:
            return "Standard (8-12)"
        }
    }
}

private struct CreateCustomization {
    let kind: CreateOutputKind
    let length: String
    let selectedBundles: [InfographicSourceBundle]
    let selectedNotes: [GeneratedNote]
    let focusNotes: String

    var instructions: String {
        let sourceNames = selectedBundles.map(\.title).joined(separator: ", ")
        let trimmedNotes = focusNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = [
            "Output type: \(kind.title)",
            "Target length: \(length)",
            "Use these selected sources or notes: \(sourceNames.isEmpty ? "selected project sources" : sourceNames)"
        ]

        if !selectedNotes.isEmpty {
            let noteBlock = selectedNotes.map { note in
                "[\(note.mode.displayTitle)] \(note.title)\n\(note.body)"
            }.joined(separator: "\n\n---\n\n")
            lines.append("Reference these previously saved notes:\n\(noteBlock)")
        }

        if !trimmedNotes.isEmpty {
            lines.append("Learner focus notes: \(trimmedNotes)")
        }

        switch kind {
        case .slideDeck:
            lines.append("Format the body as a presentation-ready slide outline with slide titles, bullets, and speaker notes.")
        case .studyGuide:
            lines.append("Format the body as a structured study guide with sections, key ideas, review prompts, and next steps.")
        case .paper:
            lines.append("Format the body as an essay or research write-up outline with a thesis, evidence, and a clear conclusion.")
        case .infographic:
            lines.append("Use the selected scope to set up the visual infographic generator.")
        case .bulletPoints:
            lines.append("Format the body as a clean bulleted list (no prose paragraphs). Each bullet starts with '- ' and is one tight sentence. Group with short headings only when the source naturally divides into sections. No filler bullets, no rephrasing the same idea twice.")
        }

        return lines.joined(separator: "\n")
    }
}

private struct CreateCustomizationSheet: View {
    let kind: CreateOutputKind
    let sourceBundles: [InfographicSourceBundle]
    let savedNotes: [GeneratedNote]
    let onGenerate: (CreateCustomization) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedLength: String
    @State private var selectedSourceIDs: Set<UUID>
    @State private var selectedNoteIDs: Set<UUID> = []
    @State private var focusNotes = ""

    init(
        kind: CreateOutputKind,
        sourceBundles: [InfographicSourceBundle],
        savedNotes: [GeneratedNote] = [],
        onGenerate: @escaping (CreateCustomization) -> Void
    ) {
        self.kind = kind
        self.sourceBundles = sourceBundles
        self.savedNotes = savedNotes
        self.onGenerate = onGenerate
        _selectedLength = State(initialValue: kind.defaultLength)
        _selectedSourceIDs = State(initialValue: Set(sourceBundles.map(\.id)))
    }

    private var selectedBundles: [InfographicSourceBundle] {
        sourceBundles.filter { selectedSourceIDs.contains($0.id) }
    }

    private var selectedSavedNotes: [GeneratedNote] {
        savedNotes.filter { selectedNoteIDs.contains($0.id) }
    }

    private var canGenerate: Bool {
        !selectedBundles.isEmpty || !selectedSavedNotes.isEmpty
    }

    var body: some View {
        ZStack {
            Color(hex: "FCF7EF").ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color(hex: "DED8CF"))
                    .frame(width: 54, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 18)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        lengthSection
                        sourcesSection
                        if !savedNotes.isEmpty {
                            notesPickerSection
                        }
                        notesSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120)
                }
            }

            VStack {
                Spacer()
                generateBar
            }
        }
    }

    private var notesPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Saved notes to reference")
                Spacer()
                Text("\(selectedSavedNotes.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "7F877F"))
            }

            VStack(spacing: 10) {
                ForEach(savedNotes) { note in
                    savedNoteRow(note)
                }
            }
        }
    }

    private func savedNoteRow(_ note: GeneratedNote) -> some View {
        let isSelected = selectedNoteIDs.contains(note.id)
        return Button {
            if isSelected {
                selectedNoteIDs.remove(note.id)
            } else {
                selectedNoteIDs.insert(note.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "6FC985") : Color(hex: "A5AAA4"))

                VStack(alignment: .leading, spacing: 3) {
                    Text(note.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))
                        .lineLimit(2)

                    Text(note.formattedDate)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "8D958E"))
                }

                Spacer()
            }
            .padding(15)
            .background(Color.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color(hex: "6FC985").opacity(0.55) : Color(hex: "E8E1D8"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: kind.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(kind.foreground)
                .frame(width: 52, height: 52)
                .background(kind.tint)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Customize \(kind.title)")
                    .font(.system(size: 31, weight: .regular, design: .serif))
                    .foregroundColor(Color(hex: "1F2420"))
                    .fixedSize(horizontal: false, vertical: true)

                Text(kind.subtitle)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "7F877F"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "535B54"))
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(hex: "E8E1D8"), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Length")

            HStack(spacing: 8) {
                ForEach(kind.lengthOptions, id: \.self) { option in
                    Button {
                        selectedLength = option
                    } label: {
                        Text(option)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(selectedLength == option ? Color(hex: "1F2420") : Color(hex: "7F877F"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedLength == option ? kind.tint : Color.white.opacity(0.9))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedLength == option ? kind.foreground.opacity(0.35) : Color(hex: "E8E1D8"), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Sources or notes to use")
                Spacer()
                Text("\(selectedBundles.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "7F877F"))
            }

            VStack(spacing: 10) {
                ForEach(sourceBundles) { source in
                    sourceRow(source)
                }
            }
        }
    }

    private func sourceRow(_ source: InfographicSourceBundle) -> some View {
        let isSelected = selectedSourceIDs.contains(source.id)

        return Button {
            if isSelected {
                selectedSourceIDs.remove(source.id)
            } else {
                selectedSourceIDs.insert(source.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "6FC985") : Color(hex: "A5AAA4"))

                VStack(alignment: .leading, spacing: 3) {
                    Text(source.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))
                        .lineLimit(2)

                    Text("\(source.pages.count) page\(source.pages.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "8D958E"))
                }

                Spacer()
            }
            .padding(15)
            .background(Color.white.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color(hex: "6FC985").opacity(0.55) : Color(hex: "E8E1D8"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Notes")

            TextEditor(text: $focusNotes)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(Color(hex: "1F2420"))
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 116)
                .background(Color.white.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: "E8E1D8"), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if focusNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Add what to emphasize, avoid, or include.")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: "A5AAA4"))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .tracking(0.7)
            .foregroundColor(Color(hex: "535B54"))
    }

    private var generateBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(hex: "E8E1D8"))

            Button {
                guard canGenerate else { return }
                let config = CreateCustomization(
                    kind: kind,
                    length: selectedLength,
                    selectedBundles: selectedBundles,
                    selectedNotes: selectedSavedNotes,
                    focusNotes: focusNotes
                )
                onGenerate(config)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: kind == .infographic ? "arrow.right" : "sparkles")
                        .font(.system(size: 17, weight: .bold))
                    Text(kind == .infographic ? "Continue" : "Generate")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color(hex: "1F2420"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(canGenerate ? Color(hex: "BFEFC8") : Color(hex: "DAD7D1"))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canGenerate)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 24)
            .background(.ultraThinMaterial)
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height
        } + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var currentItems: [RowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if nextWidth > maxWidth && !currentItems.isEmpty {
                rows.append(Row(items: currentItems, height: currentHeight))
                currentItems = []
                currentWidth = 0
                currentHeight = 0
            }

            currentItems.append(RowItem(subview: subview, size: size))
            currentWidth = currentItems.count == 1 ? size.width : currentWidth + spacing + size.width
            currentHeight = max(currentHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(Row(items: currentItems, height: currentHeight))
        }

        return rows
    }

    private struct Row {
        let items: [RowItem]
        let height: CGFloat
    }

    private struct RowItem {
        let subview: LayoutSubview
        let size: CGSize
    }
}

// MARK: - Project Live Mode

struct ProjectLiveModeView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @StateObject private var aiViewModel: OmniRealtimeViewModel
    @StateObject private var phoneCamera = ProjectLivePhoneCameraModel()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDevice: CaptureDevice?
    @State private var frameTimer: Timer?

    init(streamViewModel: StreamSessionViewModel) {
        self.streamViewModel = streamViewModel
        let apiKey = APIProviderManager.staticLiveAIAPIKey
        _aiViewModel = StateObject(
            wrappedValue: OmniRealtimeViewModel(
                apiKey: apiKey,
                systemPrompt: """
You are Aria, a concise live visual assistant. The user is sharing a live camera view from either Ray-Ban Meta glasses or an iPhone camera.
Answer questions about what is visible in the scene. Be brief, practical, and conversational.
If the user asks about something you cannot see clearly, say what is unclear and ask them to point the camera closer or from another angle.
""",
                includeTools: false,
                initialGreetingPrompt: "Greet the user briefly and tell them they can ask about what the camera sees. Keep it to one short sentence."
            )
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppColors.memorizeBackground.ignoresSafeArea()

            if let selectedDevice {
                liveCameraView(for: selectedDevice)
            } else {
                devicePicker
            }

            // Floating dismiss — kept above the camera tree so 30fps frame
            // rebuilds don't flake the button's hit-test region.
            if selectedDevice != nil {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .zIndex(2)
            }
        }
        .onChange(of: aiViewModel.isConnected) { _, isConnected in
            guard isConnected, !aiViewModel.isRecording else { return }
            aiViewModel.startRecording()
        }
        .alert("error".localized, isPresented: liveErrorPresented) {
            Button("ok".localized, role: .cancel) {
                aiViewModel.dismissError()
                phoneCamera.errorMessage = nil
            }
        } message: {
            Text(aiViewModel.errorMessage ?? phoneCamera.errorMessage ?? "")
        }
        .onDisappear {
            stopLiveMode()
        }
    }

    private var devicePicker: some View {
        VStack(spacing: AppSpacing.lg) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "1F2420"))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.88))
                        .cornerRadius(AppCornerRadius.sm)
                }

                Spacer()
            }

            Spacer()

            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(AppColors.memorizeAccent)

                Text("memorize.live_mode_select_device".localized)
                    .font(AppTypography.title2)
                    .foregroundColor(Color(hex: "1F2420"))

                Text("memorize.live_mode_select_device_desc".localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color(hex: "6E776F"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, AppSpacing.lg)
            }

            VStack(spacing: AppSpacing.md) {
                liveDeviceButton(
                    device: .glasses,
                    subtitle: streamViewModel.hasActiveDevice
                        ? "memorize.live_mode_glasses_desc".localized
                        : "memorize.live_mode_glasses_unavailable".localized,
                    isEnabled: streamViewModel.hasActiveDevice
                )

                liveDeviceButton(
                    device: .phone,
                    subtitle: "memorize.live_mode_phone_desc".localized,
                    isEnabled: true
                )
            }

            Spacer()
        }
        .padding(AppSpacing.lg)
    }

    private func liveDeviceButton(device: CaptureDevice, subtitle: String, isEnabled: Bool) -> some View {
        Button {
            startLiveMode(with: device)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: device.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isEnabled ? Color(hex: "1F2420") : Color(hex: "1F2420").opacity(0.35))
                    .frame(width: 44, height: 44)
                    .background(isEnabled ? AppColors.memorizeAccent : Color(hex: "F4EFE6"))
                    .cornerRadius(AppCornerRadius.sm)

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.rawValue)
                        .font(AppTypography.headline)
                        .foregroundColor(isEnabled ? Color(hex: "1F2420") : Color(hex: "1F2420").opacity(0.42))

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(Color(hex: "1F2420").opacity(isEnabled ? 0.58 : 0.34))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "1F2420").opacity(isEnabled ? 0.38 : 0.18))
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(AppCornerRadius.lg)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func liveCameraView(for device: CaptureDevice) -> some View {
        VStack(spacing: 0) {
            liveHeader(for: device)

            ZStack {
                livePreview(for: device)

                VStack {
                    Spacer()
                    liveStatusPill
                }
                .padding(.bottom, AppSpacing.md)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .clipped()

            conversationPanel

            liveControls
        }
    }

    private func liveHeader(for device: CaptureDevice) -> some View {
        HStack(spacing: 12) {
            // Spacer so the title doesn't collide with the floating X button overlay.
            Color.clear.frame(width: 48, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("memorize.live_mode".localized)
                    .font(AppTypography.headline)
                    .foregroundColor(Color(hex: "1F2420"))
                Text(device.rawValue)
                    .font(AppTypography.caption)
                    .foregroundColor(Color(hex: "1F2420").opacity(0.5))
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.memorizeBackground)
    }

    @ViewBuilder
    private func livePreview(for device: CaptureDevice) -> some View {
        switch device {
        case .phone:
            PhoneCameraPreviewView(session: phoneCamera.session)
                .ignoresSafeArea(edges: .horizontal)
                .overlay {
                    if let error = phoneCamera.errorMessage {
                        liveMessageOverlay(systemImage: "camera.fill", message: error)
                    }
                }
        case .glasses:
            if let frame = streamViewModel.currentVideoFrame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                liveMessageOverlay(
                    systemImage: "eyeglasses",
                    message: streamViewModel.streamingStatus == .streaming
                        ? "stream.waiting".localized
                        : "stream.connecting".localized
                )
            }
        }
    }

    private var liveStatusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(aiViewModel.isRecording ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(AppTypography.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.58))
        .cornerRadius(AppCornerRadius.sm)
    }

    private var statusText: String {
        if aiViewModel.isRecording {
            return "memorize.live_mode_listening".localized
        }
        if aiViewModel.isConnected {
            return "memorize.live_mode_ready".localized
        }
        return "memorize.live_mode_connecting_ai".localized
    }

    private var conversationPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if aiViewModel.conversationHistory.isEmpty && aiViewModel.currentTranscript.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("memorize.live_mode_scene_prompt".localized)
                            .font(AppTypography.headline)
                            .foregroundColor(Color(hex: "1F2420"))
                        Text("memorize.live_mode_scene_prompt_desc".localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color(hex: "1F2420").opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(AppCornerRadius.lg)
                } else {
                    ForEach(aiViewModel.conversationHistory.suffix(8)) { message in
                        LiveConversationBubble(message: message)
                    }

                    if !aiViewModel.currentTranscript.isEmpty {
                        LiveTranscriptBubble(text: aiViewModel.currentTranscript)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var liveControls: some View {
        HStack {
            Button {
                if aiViewModel.isRecording {
                    aiViewModel.stopRecording()
                } else {
                    aiViewModel.startRecording()
                }
            } label: {
                Image(systemName: aiViewModel.isRecording ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 56, height: 56)
                    .background(aiViewModel.isRecording ? AppColors.memorizeAccent : Color.white.opacity(0.82))
                    .clipShape(Circle())
            }
            .disabled(!aiViewModel.isConnected)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
        .background(Color.white)
    }

    private func liveMessageOverlay(systemImage: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.white.opacity(0.42))

            Text(message)
                .font(AppTypography.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var liveErrorPresented: Binding<Bool> {
        Binding(
            get: { aiViewModel.showError || phoneCamera.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    aiViewModel.dismissError()
                    phoneCamera.errorMessage = nil
                }
            }
        )
    }

    private func startLiveMode(with device: CaptureDevice) {
        selectedDevice = device
        aiViewModel.setImageSendInterval(1.5)
        aiViewModel.connect()
        startFrameForwarding()

        switch device {
        case .phone:
            phoneCamera.start()
        case .glasses:
            Task {
                await streamViewModel.handleStartStreaming()
            }
        }
    }

    private func startFrameForwarding() {
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in
                if selectedDevice == .phone, let frame = phoneCamera.currentFrame {
                    aiViewModel.updateVideoFrame(frame)
                } else if selectedDevice == .glasses, let frame = streamViewModel.currentVideoFrame {
                    aiViewModel.updateVideoFrame(frame)
                }
            }
        }
    }

    private func stopLiveMode() {
        frameTimer?.invalidate()
        frameTimer = nil
        aiViewModel.disconnect()
        phoneCamera.stop()

        if selectedDevice == .glasses, streamViewModel.isStreaming {
            Task {
                await streamViewModel.stopSession()
            }
        }
    }
}

private struct LiveConversationBubble: View {
    let message: ConversationMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 44)
            } else {
                Spacer(minLength: 44)
                bubble
            }
        }
    }

    private var bubble: some View {
        Text(message.content)
            .font(AppTypography.subheadline)
            .foregroundColor(Color(hex: "1F2420"))
            .lineSpacing(3)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(message.role == .assistant ? Color(hex: "F4EFE6") : AppColors.memorizeAccent.opacity(0.88))
            .cornerRadius(AppCornerRadius.md)
    }
}

private struct LiveTranscriptBubble: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(AppTypography.subheadline)
                .foregroundColor(Color(hex: "1F2420").opacity(0.84))
                .lineSpacing(3)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.86))
                .cornerRadius(AppCornerRadius.md)
            Spacer(minLength: 44)
        }
    }
}

private final class ProjectLivePhoneCameraModel: NSObject, @unchecked Sendable, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var currentFrame: UIImage?
    @Published var errorMessage: String?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.ariaspark.memorize.livephone.session")
    private let outputQueue = DispatchQueue(label: "com.ariaspark.memorize.livephone.output")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext()
    private var isConfigured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configureAndStart()
                } else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "memorize.live_mode_camera_denied".localized
                    }
                }
            }
        default:
            errorMessage = "memorize.live_mode_camera_denied".localized
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .medium

                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: camera) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.errorMessage = "memorize.live_mode_camera_unavailable".localized
                    }
                    return
                }

                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                self.videoOutput.setSampleBufferDelegate(self, queue: self.outputQueue)

                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }

                self.session.commitConfiguration()
                self.isConfigured = true
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)

        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = image
        }
    }
}

// MARK: - Notes Tab

private struct NotesTabView: View {
    @ObservedObject var viewModel: ProjectDetailViewModel
    @State private var selectedNote: GeneratedNote?
    @State private var notePendingDelete: GeneratedNote?
    @State private var quickNote: String = ""
    @State private var notesQuery: String = ""
    @State private var selectedQueryNoteIDs: Set<UUID> = []
    @State private var showCompose = false

    private var notes: [GeneratedNote] {
        viewModel.book.notes.sorted { $0.createdAt > $1.createdAt }
    }

    private var matchingNotes: [GeneratedNote] {
        let trimmed = notesQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return notes }
        let terms = trimmed
            .lowercased()
            .split { $0.isWhitespace || $0.isNewline }
            .map(String.init)

        return notes.filter { note in
            let searchable = "\(note.title) \(note.mode.displayTitle) \(note.body)".lowercased()
            return terms.allSatisfy { searchable.contains($0) }
        }
    }

    private var selectedQueryNotes: [GeneratedNote] {
        notes.filter { selectedQueryNoteIDs.contains($0.id) }
    }

    private var notesForGeneration: [GeneratedNote] {
        if !selectedQueryNotes.isEmpty {
            return selectedQueryNotes
        }
        return notes
    }

    private var canGenerateFromNotes: Bool {
        !notesQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !notesForGeneration.isEmpty &&
            !viewModel.isGeneratingFromNotes
    }

    private var notesQueryScopeText: String {
        if !selectedQueryNotes.isEmpty {
            return "Using \(selectedQueryNotes.count) selected note\(selectedQueryNotes.count == 1 ? "" : "s")"
        }
        return "Using all \(notes.count) note\(notes.count == 1 ? "" : "s")"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("memorize.notes".localized)
                    .font(AppTypography.title2)
                    .foregroundColor(Color(hex: "1F2420"))
                    .padding(.top, AppSpacing.lg)

                Text("Auto-generated from your Learn sessions — plus anything you write yourself.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "6E776F"))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                quickNoteBar

                weakTopicsCard

                if !notes.isEmpty {
                    notesQueryBox
                }

                if notes.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "note.text")
                            .font(.system(size: 42))
                            .foregroundColor(Color(hex: "8D958E"))
                        Text("memorize.notes_empty_title".localized)
                            .font(AppTypography.headline)
                            .foregroundColor(Color(hex: "1F2420"))
                        Text("memorize.notes_empty_desc".localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color(hex: "6E776F"))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                    .padding(.horizontal, AppSpacing.lg)
                } else {
                    HStack {
                        Text(notesQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ALL NOTES" : "MATCHING NOTES")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundColor(Color(hex: "8D958E"))

                        Spacer()

                        Text("\(matchingNotes.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "8D958E"))
                    }
                    .padding(.top, AppSpacing.sm)

                    if matchingNotes.isEmpty {
                        Text("No notes match this filter.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: "8D958E"))
                            .padding(.vertical, 10)
                    } else {
                        ForEach(matchingNotes) { note in
                            SavedNoteCard(
                                note: note,
                                isSelectionVisible: true,
                                isSelected: selectedQueryNoteIDs.contains(note.id),
                                onOpen: {
                                    selectedNote = note
                                },
                                onDelete: {
                                    notePendingDelete = note
                                },
                                onToggleSelection: {
                                    toggleQueryNoteSelection(note.id)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
        .sheet(isPresented: $showCompose) {
            NewNoteComposeSheet(
                initialBody: quickNote
            ) { title, body in
                viewModel.addUserNote(title: title, body: body)
                quickNote = ""
            }
            .presentationDetents([.large])
        }
        .sheet(item: $selectedNote) { note in
            SavedNoteDetailView(
                note: note,
                onDelete: {
                    viewModel.deleteNote(id: note.id)
                    selectedNote = nil
                },
                onRename: { newTitle in
                    viewModel.renameNote(id: note.id, to: newTitle)
                    if let updated = viewModel.book.notes.first(where: { $0.id == note.id }) {
                        selectedNote = updated
                    }
                }
            )
        }
        .alert("memorize.notes_delete_title".localized, isPresented: deleteAlertPresented) {
            Button("memorize.notes_delete".localized, role: .destructive) {
                if let notePendingDelete {
                    viewModel.deleteNote(id: notePendingDelete.id)
                }
                notePendingDelete = nil
            }
            Button("memorize.notes_cancel".localized, role: .cancel) {
                notePendingDelete = nil
            }
        } message: {
            Text("memorize.notes_delete_message".localized)
        }
    }

    private var notesQueryBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "276B32"))

                ZStack(alignment: .leading) {
                    if notesQuery.isEmpty {
                        Text("Filter notes or ask AI…")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: "8D958E"))
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $notesQuery)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))
                        .tint(Color(hex: "276B32"))
                        .submitLabel(.done)
                }

                if !notesQuery.isEmpty {
                    Button {
                        notesQuery = ""
                        selectedQueryNoteIDs = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(hex: "A5AAA4"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: "D7E6D4"), lineWidth: 1))

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(notesQueryScopeText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "535B54"))
                    Text("Generate summaries, answers, flashcards, outlines, or quiz prompts from notes.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "8D958E"))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Button {
                    guard canGenerateFromNotes else { return }
                    viewModel.generateFromSavedNotes(prompt: notesQuery, notes: notesForGeneration) { note in
                        selectedNote = note
                    }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isGeneratingFromNotes {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(viewModel.isGeneratingFromNotes ? "Generating" : "Generate")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(canGenerateFromNotes ? Color(hex: "276B32") : Color(hex: "A5AAA4"))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canGenerateFromNotes)
            }

            if let error = viewModel.notesQueryError, !error.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "B0444C"))
            }
        }
        .padding(14)
        .background(Color(hex: "EFF8EC"))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(hex: "C8DFC6"), lineWidth: 1))
    }

    private var deleteAlertPresented: Binding<Bool> {
        Binding(
            get: { notePendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    notePendingDelete = nil
                }
            }
        )
    }

    @ViewBuilder
    private var weakTopicsCard: some View {
        let weak = viewModel.book.weakTopics
            .filter { $0.attemptCount > 0 && $0.missCount > 0 }
            .sorted { $0.missRate > $1.missRate }
            .prefix(3)
        if !weak.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "B0444C"))
                    Text("TOPICS TO REVISIT")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundColor(Color(hex: "B0444C"))
                    Spacer()
                }

                VStack(spacing: 8) {
                    ForEach(Array(weak), id: \.id) { record in
                        weakTopicRow(record)
                    }
                }
            }
            .padding(14)
            .background(Color(hex: "FCEDEE"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: "F2C9CD"), lineWidth: 1)
            )
        }
    }

    private func weakTopicRow(_ record: WeakTopicRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.topicTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "1F2420"))
                    .lineLimit(1)
                Text("\(record.missCount) of \(record.attemptCount) missed · \(Int((record.missRate * 100).rounded()))%")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "8D958E"))
                    .lineLimit(1)
            }
            Spacer()
            Button {
                viewModel.dismissWeakTopic(record.topicID)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "8D958E"))
                    .frame(width: 26, height: 26)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "F2C9CD"), lineWidth: 1)
        )
    }

    private var quickNoteBar: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                if quickNote.isEmpty {
                    Text("Jot a quick note…")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "8D958E"))
                        .padding(.horizontal, 16)
                        .allowsHitTesting(false)
                }
                TextField("", text: $quickNote)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "1F2420"))
                    .tint(Color(hex: "276B32"))
                    .padding(.horizontal, 16)
                    .submitLabel(.done)
                    .onSubmit { saveQuickNoteIfReady() }
            }
            .frame(height: 44)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: "EAE4DC"), lineWidth: 1))

            Button {
                showCompose = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(hex: "1F2420"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func saveQuickNoteIfReady() {
        let trimmed = quickNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.addUserNote(title: "", body: trimmed)
        quickNote = ""
    }

    private func toggleQueryNoteSelection(_ id: UUID) {
        if selectedQueryNoteIDs.contains(id) {
            selectedQueryNoteIDs.remove(id)
        } else {
            selectedQueryNoteIDs.insert(id)
        }
    }
}

private enum NoteComposeMode {
    case voice
    case type
}

private struct NewNoteComposeSheet: View {
    let initialBody: String
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText: String = ""
    @State private var mode: NoteComposeMode = .type
    @StateObject private var voice = NoteVoiceRecorder()
    @State private var voiceError: String?

    private var canSave: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                modeToggle
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if mode == .voice {
                            voiceSection
                        } else {
                            typeSection
                        }
                    }
                    .padding(20)
                }
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("New note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        voice.stopListening()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "6E776F"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        voice.stopListening()
                        let finalBody = mode == .voice ? voice.transcript : bodyText
                        onSave(title, finalBody)
                        dismiss()
                    } label: {
                        Text("Save note")
                            .fontWeight(.semibold)
                    }
                    .disabled(!effectiveCanSave)
                    .foregroundColor(effectiveCanSave ? Color(hex: "276B32") : Color(hex: "A5AAA4"))
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
        }
        .onAppear { bodyText = initialBody }
        .onDisappear { voice.stopListening() }
    }

    private var effectiveCanSave: Bool {
        if mode == .voice {
            return !voice.isListening && !voice.isTranscribing &&
                (!voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        return canSave
    }

    private var modeToggle: some View {
        HStack(spacing: 6) {
            modeTab(label: "Voice", system: "mic.fill", value: .voice)
            modeTab(label: "Type", system: "keyboard", value: .type)
        }
        .padding(4)
        .background(Color(hex: "EFE9DF"))
        .clipShape(Capsule())
    }

    private func modeTab(label: String, system: String, value: NoteComposeMode) -> some View {
        let selected = mode == value
        return Button {
            if value == .type {
                voice.stopListening()
            }
            withAnimation(.easeInOut(duration: 0.18)) { mode = value }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundColor(selected ? Color(hex: "1F2420") : Color(hex: "8D958E"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(selected ? Color.white : Color.clear)
            .clipShape(Capsule())
            .shadow(color: selected ? Color.black.opacity(0.06) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TITLE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(Color(hex: "8D958E"))
                ZStack(alignment: .leading) {
                    if title.isEmpty {
                        Text("Give it a title…")
                            .font(.system(size: 17, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: "8D958E"))
                            .padding(.horizontal, 14)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $title)
                        .font(.system(size: 17, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))
                        .tint(Color(hex: "276B32"))
                        .padding(14)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NOTE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(Color(hex: "8D958E"))
                ZStack(alignment: .topLeading) {
                    if bodyText.isEmpty {
                        Text("Start typing…")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: "A5AAA4"))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 18)
                    }
                    TextEditor(text: $bodyText)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "1F2420"))
                        .tint(Color(hex: "276B32"))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(minHeight: 280)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }
        }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            listeningCard
            transcriptCard
            if let voiceError, !voiceError.isEmpty {
                Text(voiceError)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "B0444C"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            voiceControls
        }
    }

    private var listeningCard: some View {
        let active = voice.isListening
        return HStack(spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(active ? Color(hex: "276B32") : Color(hex: "8D958E"))
                    .frame(width: 8, height: 8)
                    .opacity(active ? 1 : 0.5)
                    .scaleEffect(active ? 1.0 : 0.85)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: active)
                Text(voice.statusText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(active ? Color(hex: "276B32") : Color(hex: "6E776F"))
            }
            Spacer()
            MicWaveformView(level: voice.audioLevel, accent: Color(hex: "276B32"))
                .opacity(active ? 1 : 0.35)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hex: "DCEFDC"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "B6D9B7"), lineWidth: 1))
    }

    private var transcriptCard: some View {
        let active = voice.isListening
        return VStack(alignment: .leading, spacing: 6) {
            Text("TRANSCRIPT")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundColor(Color(hex: "8D958E"))
            ZStack {
                VoiceTranscriptWaveformBackground(
                    level: voice.audioLevel,
                    isActive: active,
                    accent: Color(hex: "276B32")
                )

                ScrollView {
                    if !active {
                        Text(voice.transcriptPlaceholder)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(voice.transcript.isEmpty ? Color(hex: "6E776F") : Color(hex: "1F2420"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
            }
            .frame(minHeight: 180, maxHeight: 320)
            .background(active ? Color(hex: "F4FFF2") : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(active ? Color(hex: "9ED4A1") : Color(hex: "EAE4DC"), lineWidth: active ? 1.4 : 1)
            )
        }
    }

    private var voiceControls: some View {
        HStack(spacing: 12) {
            Button {
                if voice.isListening {
                    voice.stopListening()
                } else if !voice.isTranscribing {
                    Task {
                        await voice.requestPermissionsIfNeeded()
                        if voice.speechPermissionDenied || voice.micPermissionDenied {
                            voiceError = "Microphone and speech permissions are required."
                            return
                        }
                        do {
                            voiceError = nil
                            try voice.startListening()
                        } catch {
                            voiceError = error.localizedDescription
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: voice.isListening ? "pause.fill" : "mic.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(voice.primaryButtonTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundColor(Color(hex: "1F2420"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "EAE4DC"), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(voice.isTranscribing)

            Button {
                voice.stopListening()
                onSave(title, voice.transcript)
                dismiss()
            } label: {
                Text("Save note")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(effectiveCanSave ? Color(hex: "276B32") : Color(hex: "A5AAA4"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!effectiveCanSave)
        }
    }
}

private struct VoiceTranscriptWaveformBackground: View {
    let level: Float
    let isActive: Bool
    let accent: Color

    private let spacing: CGFloat = 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let barCount = max(20, Int(width / 12))
                let barWidth = max(3, (width - CGFloat(barCount - 1) * spacing) / CGFloat(barCount))
                let time = timeline.date.timeIntervalSinceReferenceDate
                let normalizedLevel = max(0.08, CGFloat(level))

                HStack(alignment: .center, spacing: spacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        let progress = CGFloat(index) / CGFloat(max(1, barCount - 1))
                        let centerBias = 1 - abs(progress - 0.5) * 0.9
                        let wave = (sin(time * 4.8 + Double(index) * 0.58) + 1) / 2
                        let pulse = CGFloat(wave) * 0.45 + normalizedLevel * 0.75
                        let barHeight = isActive
                            ? max(4, height * min(0.34, pulse * centerBias * 0.48))
                            : 6

                        Capsule()
                            .fill(accent.opacity(isActive ? 0.16 + Double(normalizedLevel) * 0.12 : 0.025))
                            .frame(width: barWidth, height: barHeight)
                            .animation(.easeOut(duration: 0.08), value: level)
                    }
                }
                .frame(width: width, height: height)
                .opacity(isActive ? 1 : 0.45)
            }
        }
        .allowsHitTesting(false)
    }
}

@MainActor
private final class NoteVoiceRecorder: NSObject, ObservableObject {
    @Published var transcript: String = ""
    @Published var isListening: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var speechPermissionDenied: Bool = false
    @Published var micPermissionDenied: Bool = false
    @Published var permissionsResolved: Bool = false
    @Published var audioLevel: Float = 0
    @Published var elapsedSeconds: Int = 0

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.preferredLanguages.first ?? "en-US"))
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var durationTimer: Timer?
    private var meteringTimer: Timer?
    private var sessionBaseLength: Int = 0
    private var sessionStart: Date?

    var formattedDuration: String {
        let total = elapsedSeconds
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    var statusText: String {
        if isListening {
            return "RECORDING · \(formattedDuration)"
        }
        if isTranscribing {
            return "TRANSCRIBING · \(formattedDuration)"
        }
        return "PAUSED · \(formattedDuration)"
    }

    var transcriptPlaceholder: String {
        if !transcript.isEmpty {
            return transcript
        }
        if isListening {
            return "Recording audio. Pause when you’re ready to turn it into text."
        }
        if isTranscribing {
            return "Turning your recording into text…"
        }
        return "Tap Start, speak naturally, then pause to create your note transcript."
    }

    var primaryButtonTitle: String {
        if isListening {
            return "Pause"
        }
        if isTranscribing {
            return "Transcribing"
        }
        return transcript.isEmpty ? "Start" : "Resume"
    }

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
        permissionsResolved = true
    }

    func startListening() throws {
        guard !isListening else { return }
        guard !isTranscribing else { return }
        guard permissionsResolved, !speechPermissionDenied, !micPermissionDenied else {
            throw NSError(domain: "NoteVoiceRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Microphone and speech permissions are required."])
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default, options: [.allowBluetoothHFP, .duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("note-voice-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw NSError(domain: "NoteVoiceRecorder", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to start audio recording."])
        }

        audioRecorder = recorder
        recordingURL = fileURL
        sessionStart = Date()
        isListening = true

        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.sessionStart else { return }
                let delta = Int(Date().timeIntervalSince(start))
                self.elapsedSeconds = self.sessionBaseLength + delta
            }
        }
        meteringTimer?.invalidate()
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                recorder.updateMeters()
                let averagePower = recorder.averagePower(forChannel: 0)
                self.audioLevel = min(1.0, max(0.0, (averagePower + 55.0) / 55.0))
            }
        }
    }

    func stopListening() {
        guard isListening else { return }

        audioRecorder?.stop()
        audioRecorder = nil
        isListening = false
        audioLevel = 0
        if let start = sessionStart {
            sessionBaseLength += Int(Date().timeIntervalSince(start))
            sessionStart = nil
        }
        durationTimer?.invalidate()
        durationTimer = nil
        meteringTimer?.invalidate()
        meteringTimer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if let recordingURL {
            transcribeRecording(at: recordingURL)
        }
    }

    private func transcribeRecording(at url: URL) {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            isTranscribing = false
            return
        }

        isTranscribing = true
        let existingTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    let newText = result.bestTranscription.formattedString
                    self.transcript = existingTranscript.isEmpty ? newText : existingTranscript + " " + newText
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.isTranscribing = false
                    self.recognitionTask = nil
                    self.recordingURL = nil
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }
}

private struct SavedNoteCard: View {
    let note: GeneratedNote
    var isSelectionVisible: Bool = false
    var isSelected: Bool = false
    let onOpen: () -> Void
    let onDelete: () -> Void
    var onToggleSelection: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                if isSelectionVisible {
                    Button(action: onToggleSelection) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isSelected ? Color(hex: "6FC985") : Color(hex: "A5AAA4"))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "276B32"))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: "D6F4D8"))
                    .cornerRadius(AppCornerRadius.sm)

                VStack(alignment: .leading, spacing: 5) {
                    Text(note.title)
                        .font(AppTypography.headline)
                        .foregroundColor(Color(hex: "1F2420"))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(note.formattedDate)
                        .font(AppTypography.caption)
                        .foregroundColor(Color(hex: "8D958E"))
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "B0444C"))
                        .frame(width: 34, height: 34)
                        .background(Color(hex: "FCE3E3"))
                        .cornerRadius(AppCornerRadius.sm)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Text(note.mode.displayTitle)
                    .font(AppTypography.caption)
                    .foregroundColor(Color(hex: "276B32"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "D6F4D8"))
                    .cornerRadius(AppCornerRadius.sm)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "8D958E"))
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(AppCornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                .stroke(isSelected ? Color(hex: "6FC985").opacity(0.65) : Color(hex: "EAE4DC"), lineWidth: isSelected ? 1.3 : 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    private var iconName: String {
        switch note.mode {
        case .tutor:
            return "graduationcap.fill"
        case .interact:
            return "bubble.left.and.bubble.right.fill"
        case .explain:
            return "lightbulb.fill"
        case .podcast:
            return "waveform"
        case .infographics:
            return "chart.bar.doc.horizontal.fill"
        case .quiz:
            return "questionmark.circle.fill"
        case .voiceSummary:
            return "mic.fill"
        case .studyGuide:
            return "book.closed.fill"
        case .userNote:
            return "pencil.line"
        }
    }
}

private struct SavedNoteDetailView: View {
    let note: GeneratedNote
    let onDelete: () -> Void
    var onRename: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var showRenameAlert = false
    @State private var renameDraft: String = ""

    private var shareText: String {
        "\(note.title)\n\n\(note.body)"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.mode.displayTitle)
                            .font(AppTypography.caption)
                            .foregroundColor(Color(hex: "276B32"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "D6F4D8"))
                            .cornerRadius(AppCornerRadius.sm)

                        Button {
                            renameDraft = note.title
                            showRenameAlert = true
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Text(note.title)
                                    .font(AppTypography.title2)
                                    .foregroundColor(Color(hex: "1F2420"))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(hex: "8D958E"))
                                    .padding(.top, 6)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)

                        Text(note.formattedDate)
                            .font(AppTypography.caption)
                            .foregroundColor(Color(hex: "8D958E"))
                    }

                    ReadableNoteBody(text: note.body)
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("memorize.notes".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("memorize.notes_close".localized) {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "1F2420"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(Color(hex: "1F2420"))
                        }
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .foregroundColor(Color(hex: "B0444C"))
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
            .alert("Rename note", isPresented: $showRenameAlert) {
                TextField("Note title", text: $renameDraft)
                Button("Save") {
                    let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { onRename(trimmed) }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

private struct ReadableNoteBody: View {
    let text: String

    private var lines: [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if isHeading(line) {
                    Text(cleanHeading(line))
                        .font(AppTypography.headline)
                        .foregroundColor(Color(hex: "1F2420"))
                        .padding(.top, 6)
                } else if isBullet(line) {
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color(hex: "276B32"))
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Text(cleanBullet(line))
                            .font(AppTypography.body)
                            .foregroundColor(Color(hex: "1F2420").opacity(0.82))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(line)
                        .font(AppTypography.body)
                        .foregroundColor(Color(hex: "1F2420").opacity(0.82))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(AppCornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                .stroke(Color(hex: "EAE4DC"), lineWidth: 1)
        )
    }

    private func isHeading(_ line: String) -> Bool {
        let normalized = line
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "#: "))
            .lowercased()

        return [
            "summary",
            "key ideas",
            "important details",
            "what you said and ai feedback",
            "what to review",
            "next steps",
            "details",
            "one-sentence takeaway",
            "one sentence takeaway"
        ].contains(normalized) || isPlainTopicHeading(line)
    }

    private func isBullet(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("• ") || line.hasPrefix("* ") || line.hasPrefix("[")
    }

    private func cleanHeading(_ line: String) -> String {
        line
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "#: "))
    }

    private func isPlainTopicHeading(_ line: String) -> Bool {
        let cleaned = cleanHeading(line)
        guard !cleaned.isEmpty, cleaned.count <= 72 else { return false }
        guard !cleaned.contains("."),
              !cleaned.contains("?"),
              !cleaned.contains("!"),
              !cleaned.contains(":") else { return false }

        let words = cleaned.split(separator: " ")
        guard words.count >= 2, words.count <= 8 else { return false }
        guard let first = cleaned.first, first.isUppercase else { return false }
        return true
    }

    private func cleanBullet(_ line: String) -> String {
        if line.hasPrefix("[") {
            return line.replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return String(line.dropFirst(2))
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct GeneratedNoteDraftView: View {
    let note: GeneratedNote
    let onClose: () -> Void
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var shareText: String {
        "\(note.title)\n\n\(note.body)"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "2F6A3F"))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "D8F7D8"))
                            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("memorize.notes_generated_title".localized)
                                .font(AppTypography.caption)
                                .foregroundColor(Color(hex: "8D958E"))
                            Text(note.mode.displayTitle)
                                .font(AppTypography.subheadline)
                                .foregroundColor(Color(hex: "535B54"))
                        }
                    }

                    Text(note.title)
                        .font(AppTypography.title2)
                        .foregroundColor(Color(hex: "1F2420"))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(note.body)
                        .font(AppTypography.body)
                        .foregroundColor(Color(hex: "343A35"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppSpacing.lg)
                .background(Color.white.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(hex: "E8E1D8"), lineWidth: 1)
                )
                .padding(22)
            }
            .background(AppColors.memorizeBackground.ignoresSafeArea())
            .navigationTitle("memorize.notes_review_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("memorize.notes_close".localized) {
                        onClose()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "6E776F"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(Color(hex: "1F2420"))
                        }
                        Button("memorize.notes_save".localized) {
                            onSave()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "2F6A3F"))
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}

private struct GeneratedSlideDeckDraftView: View {
    let deck: GeneratedSlideDeck
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var shareText: String {
        var lines: [String] = [deck.title, ""]
        for (i, slide) in deck.slides.enumerated() {
            lines.append("Slide \(i + 1) — \(slide.title)")
            for bullet in slide.bullets {
                lines.append("• \(bullet)")
            }
            if !slide.speakerNotes.isEmpty {
                lines.append("Speaker notes: \(slide.speakerNotes)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SLIDE DECK")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundColor(Color(hex: "8D958E"))

                        Text(deck.title)
                            .font(.system(size: 36, weight: .regular, design: .serif))
                            .foregroundColor(Color(hex: "1F2420"))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(deck.slides.count) slides")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: "7F877F"))
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    VStack(spacing: 14) {
                        ForEach(Array(deck.slides.enumerated()), id: \.element.id) { index, slide in
                            slideCard(slide, index: index + 1)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)
                }
            }
            .background(Color(hex: "FCF7EF").ignoresSafeArea())
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(Color(hex: "1F2420"))
                        }
                        Button("Done") {
                            onClose()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "2F6A3F"))
                    }
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    private func slideCard(_ slide: GeneratedSlide, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(index)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "943C4A"))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: "FFE1E5"))
                    .clipShape(Circle())

                Text(slide.title)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundColor(Color(hex: "1F2420"))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            if !slide.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(slide.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color(hex: "6FC985"))
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)

                            Text(bullet)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(Color(hex: "343A35"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !slide.speakerNotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Speaker notes")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundColor(Color(hex: "8D958E"))

                    Text(slide.speakerNotes)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "6E776F"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "F6F0E7"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: "E8E1D8"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

private struct BulletListBody: View {
    let text: String

    private struct ParsedLine: Identifiable {
        let id = UUID()
        let kind: Kind
        let text: String

        enum Kind { case heading, bullet, subBullet }
    }

    private var lines: [ParsedLine] {
        var result: [ParsedLine] = []
        for raw in text.components(separatedBy: "\n") {
            let original = raw
            let trimmed = original.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if original.hasPrefix("  - ") || original.hasPrefix("    - ") {
                let body = trimmed.replacingOccurrences(of: "- ", with: "", options: .anchored)
                result.append(ParsedLine(kind: .subBullet, text: body))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
                let body = trimmed
                    .replacingOccurrences(of: "- ", with: "", options: .anchored)
                    .replacingOccurrences(of: "• ", with: "", options: .anchored)
                result.append(ParsedLine(kind: .bullet, text: body))
            } else {
                result.append(ParsedLine(kind: .heading, text: trimmed))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { idx, line in
                switch line.kind {
                case .heading:
                    Text(line.text)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(0.4)
                        .foregroundColor(Color(hex: "8A641F"))
                        .padding(.top, idx == 0 ? 0 : 14)
                        .padding(.bottom, 2)
                case .bullet:
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color(hex: "8A641F"))
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Text(line.text)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: "1F2420"))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .subBullet:
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(Color(hex: "8A641F").opacity(0.6))
                            .frame(width: 5, height: 1.5)
                            .padding(.top, 11)
                        Text(line.text)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: "3F4642"))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GeneratedPaperDraftView: View {
    let paper: GeneratedPaper
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var shareText: String {
        "\(paper.title)\n\n\(paper.body)"
    }

    private var isBulletList: Bool {
        let lines = paper.body
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }
        let bulletLines = lines.filter { $0.hasPrefix("- ") || $0.hasPrefix("• ") }
        return Double(bulletLines.count) / Double(lines.count) >= 0.5
    }

    private var eyebrowText: String {
        isBulletList ? "BULLET POINTS" : "PAPER"
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(eyebrowText)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundColor(Color(hex: "8D958E"))

                        Text(paper.title)
                            .font(.system(size: 36, weight: .regular, design: .serif))
                            .foregroundColor(Color(hex: "1F2420"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    Group {
                        if isBulletList {
                            BulletListBody(text: paper.body)
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.96))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color(hex: "E8E1D8"), lineWidth: 1)
                                )
                        } else {
                            Text(paper.body)
                                .font(.system(size: 17, weight: .regular, design: .serif))
                                .lineSpacing(6)
                                .foregroundColor(Color(hex: "343A35"))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.96))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(Color(hex: "E8E1D8"), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)
                }
            }
            .background(Color(hex: "FCF7EF").ignoresSafeArea())
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Color(hex: "1F2420"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onClose()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "2F6A3F"))
                }
            }
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}
