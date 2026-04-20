/*
 * Project Detail View
 * Container with Sources and Study bottom tabs for a single project
 */

import SwiftUI
import UniformTypeIdentifiers

struct ProjectDetailView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @StateObject private var viewModel: ProjectDetailViewModel
    @Environment(\.dismiss) private var dismiss
    private let onDeleteProject: (UUID) -> Void

    @State private var selectedTab: ProjectTab = .sources
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showTutor = false

    enum ProjectTab {
        case sources, tutor, study
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
        NavigationView {
            VStack(spacing: 0) {
                // Content
                switch selectedTab {
                case .sources:
                    SourcesTabView(viewModel: viewModel, streamViewModel: streamViewModel)
                case .tutor:
                    // Handled by fullScreenCover below
                    SourcesTabView(viewModel: viewModel, streamViewModel: streamViewModel)
                case .study:
                    StudyTabView(viewModel: viewModel)
                }

                // Bottom tab bar
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
                            onDeleteProject(viewModel.book.id)
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
        .onAppear {
            viewModel.reload()
        }
        .fileImporter(
            isPresented: $viewModel.showFilePicker,
            allowedContentTypes: [.pdf, .text, .plainText, UTType(filenameExtension: "docx")].compactMap { $0 },
            allowsMultipleSelection: false
        ) { result in
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
        .alert("Rename Project", isPresented: $showRenameAlert) {
            TextField("Project name", text: $renameText)
            Button("Save") {
                viewModel.renameProject(to: renameText)
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showTutor) {
            TutorTabView(viewModel: viewModel)
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

            print("📂 [Import] Copied to temp: \(tempURL.lastPathComponent), size: \(try? Data(contentsOf: tempURL).count ?? 0)")

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
                showTutor = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 20))
                    Text("Tutor")
                        .font(AppTypography.caption)
                }
                .foregroundColor(Color.white.opacity(0.5))
                .frame(maxWidth: .infinity)
            }

            tabButton(tab: .study, icon: "sparkles", label: "memorize.study".localized)
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
