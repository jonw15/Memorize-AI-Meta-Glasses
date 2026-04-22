/*
 * Project Detail View
 * Container with Sources and Study bottom tabs for a single project
 */

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct ProjectDetailView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @StateObject private var viewModel: ProjectDetailViewModel
    @Environment(\.dismiss) private var dismiss
    private let onDeleteProject: (UUID) -> Void

    @State private var selectedTab: ProjectTab = .sources
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showTutor = false
    @State private var showLiveMode = false
    @State private var isDeletingProject = false
    @State private var tutorStartedAt: Date?
    private let minimumNoteGenerationDuration: TimeInterval = 10

    enum ProjectTab {
        case sources, tutor, study, notes
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
            }
            .onChange(of: viewModel.sourceAddedToken) { _, token in
                guard token != nil else { return }
                openTutorAfterSourceUpload()
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
            .overlay {
                noteGenerationOverlay
            }
            .fullScreenCover(isPresented: $showLiveMode) {
                ProjectLiveModeView(streamViewModel: streamViewModel)
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
                liveModeBanner
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
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
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
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        case .sources:
            SourcesTabView(viewModel: viewModel, streamViewModel: streamViewModel)
        case .tutor:
            SourcesTabView(viewModel: viewModel, streamViewModel: streamViewModel)
        case .study:
            StudyTabView(viewModel: viewModel) { mode in
                viewModel.generateNoteDraft(after: mode)
            }
        case .notes:
            NotesTabView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var noteGenerationOverlay: some View {
        if viewModel.isGeneratingNoteDraft {
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.15)
                    Text("memorize.notes_generating".localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(.white)
                }
                .padding(22)
                .background(AppColors.memorizeCard)
                .cornerRadius(AppCornerRadius.lg)
            }
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

    private func openTutorAfterSourceUpload() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard viewModel.hasContent else { return }
            showTutor = true
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
        HStack {
            tabButton(tab: .sources, icon: "doc.on.doc.fill", label: "memorize.sources".localized)

            // Tutor button opens fullscreen
            Button {
                selectedTab = .tutor
                showTutor = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 20))
                    Text("memorize.tutor_short".localized)
                        .font(AppTypography.caption)
                }
                .foregroundColor(selectedTab == .tutor ? AppColors.memorizeAccent : Color.white.opacity(0.5))
                .frame(maxWidth: .infinity)
            }

            tabButton(tab: .study, icon: "sparkles", label: "memorize.study".localized)
            tabButton(tab: .notes, icon: "note.text", label: "memorize.notes".localized)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(AppColors.memorizeCard)
    }

    private func tabButton(tab: ProjectTab, icon: String, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(AppTypography.caption)
            }
            .foregroundColor(selectedTab == tab ? AppColors.memorizeAccent : Color.white.opacity(0.5))
            .frame(maxWidth: .infinity)
        }
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
        ZStack {
            AppColors.memorizeBackground.ignoresSafeArea()

            if let selectedDevice {
                liveCameraView(for: selectedDevice)
            } else {
                devicePicker
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
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
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
                    .foregroundColor(.white)

                Text("memorize.live_mode_select_device_desc".localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(Color.white.opacity(0.62))
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
                    .foregroundColor(isEnabled ? .black : Color.white.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .background(isEnabled ? AppColors.memorizeAccent : Color.white.opacity(0.08))
                    .cornerRadius(AppCornerRadius.sm)

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.rawValue)
                        .font(AppTypography.headline)
                        .foregroundColor(isEnabled ? .white : Color.white.opacity(0.42))

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(isEnabled ? 0.58 : 0.34))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(isEnabled ? 0.38 : 0.18))
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .background(AppColors.memorizeCard)
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
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(AppCornerRadius.sm)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("memorize.live_mode".localized)
                    .font(AppTypography.headline)
                    .foregroundColor(.white)
                Text(device.rawValue)
                    .font(AppTypography.caption)
                    .foregroundColor(Color.white.opacity(0.5))
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
                            .foregroundColor(.white)
                        Text("memorize.live_mode_scene_prompt_desc".localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color.white.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.memorizeCard)
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
        .background(AppColors.memorizeCard)
    }

    private func liveMessageOverlay(systemImage: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.42))

            Text(message)
                .font(AppTypography.subheadline)
                .foregroundColor(Color.white.opacity(0.7))
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
            .foregroundColor(.white)
            .lineSpacing(3)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(message.role == .assistant ? AppColors.memorizeCard : AppColors.memorizeAccent.opacity(0.88))
            .cornerRadius(AppCornerRadius.md)
    }
}

private struct LiveTranscriptBubble: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(AppTypography.subheadline)
                .foregroundColor(Color.white.opacity(0.84))
                .lineSpacing(3)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.memorizeCard.opacity(0.86))
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

    private var notes: [GeneratedNote] {
        viewModel.book.notes.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if notes.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "note.text")
                            .font(.system(size: 42))
                            .foregroundColor(Color.white.opacity(0.3))
                        Text("memorize.notes_empty_title".localized)
                            .font(AppTypography.headline)
                            .foregroundColor(.white)
                        Text("memorize.notes_empty_desc".localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(Color.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 70)
                    .padding(.horizontal, AppSpacing.lg)
                } else {
                    Text("memorize.notes".localized)
                        .font(AppTypography.title2)
                        .foregroundColor(.white)
                        .padding(.top, AppSpacing.lg)

                    ForEach(notes) { note in
                        SavedNoteCard(
                            note: note,
                            onOpen: {
                                selectedNote = note
                            },
                            onDelete: {
                                notePendingDelete = note
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
        .sheet(item: $selectedNote) { note in
            SavedNoteDetailView(
                note: note,
                onDelete: {
                    viewModel.deleteNote(id: note.id)
                    selectedNote = nil
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
}

private struct SavedNoteCard: View {
    let note: GeneratedNote
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.memorizeAccent)
                    .frame(width: 34, height: 34)
                    .background(AppColors.memorizeAccent.opacity(0.15))
                    .cornerRadius(AppCornerRadius.sm)

                VStack(alignment: .leading, spacing: 5) {
                    Text(note.title)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(note.formattedDate)
                        .font(AppTypography.caption)
                        .foregroundColor(Color.white.opacity(0.48))
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.red.opacity(0.9))
                        .frame(width: 34, height: 34)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(AppCornerRadius.sm)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Text(note.mode.displayTitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.memorizeAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.memorizeAccent.opacity(0.12))
                    .cornerRadius(AppCornerRadius.sm)

                Spacer()

                Text("memorize.notes_read".localized)
                    .font(AppTypography.caption)
                    .foregroundColor(Color.white.opacity(0.55))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.35))
            }

            Text(note.previewText)
                .font(AppTypography.subheadline)
                .foregroundColor(Color.white.opacity(0.74))
                .lineSpacing(3)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.memorizeCard)
        .cornerRadius(AppCornerRadius.lg)
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
        }
    }
}

private struct SavedNoteDetailView: View {
    let note: GeneratedNote
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.mode.displayTitle)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.memorizeAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppColors.memorizeAccent.opacity(0.12))
                            .cornerRadius(AppCornerRadius.sm)

                        Text(note.title)
                            .font(AppTypography.title2)
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(note.formattedDate)
                            .font(AppTypography.caption)
                            .foregroundColor(Color.white.opacity(0.5))
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
                    .foregroundColor(Color.white.opacity(0.75))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .foregroundColor(.red.opacity(0.9))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                        .foregroundColor(.white)
                        .padding(.top, 6)
                } else if isBullet(line) {
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(AppColors.memorizeAccent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Text(cleanBullet(line))
                            .font(AppTypography.body)
                            .foregroundColor(Color.white.opacity(0.82))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(line)
                        .font(AppTypography.body)
                        .foregroundColor(Color.white.opacity(0.82))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.memorizeCard)
        .cornerRadius(AppCornerRadius.lg)
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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(AppColors.memorizeAccent)
                            .cornerRadius(AppCornerRadius.sm)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("memorize.notes_generated_title".localized)
                                .font(AppTypography.caption)
                                .foregroundColor(Color.white.opacity(0.55))
                            Text(note.mode.displayTitle)
                                .font(AppTypography.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Text(note.title)
                        .font(AppTypography.title2)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(note.body)
                        .font(AppTypography.body)
                        .foregroundColor(Color.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppSpacing.lg)
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
                    .foregroundColor(Color.white.opacity(0.75))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("memorize.notes_save".localized) {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.memorizeAccent)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
