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
    @State private var showPDFPicker = false
    @State private var showTextNoteEditor = false
    @State private var showCameraCapture = false
    @State private var showFilePicker = false
    @State private var pendingDeleteSource: Source?

    var body: some View {
        VStack(spacing: 0) {
            // Source list
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Text("memorize.sources".localized)
                            .font(AppTypography.headline)
                            .foregroundColor(.white)
                        Spacer()
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

                    if let error = viewModel.pdfImportError {
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
                    showCameraCapture = true
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.md))
                }

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
                onPDF: {
                    showAddSourceSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPDFPicker = true
                    }
                },
                onTextNote: {
                    showAddSourceSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showTextNoteEditor = true
                    }
                },
                onCamera: {
                    showAddSourceSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCameraCapture = true
                    }
                },
                onFile: {
                    showAddSourceSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showFilePicker = true
                    }
                }
            )
            .presentationDetents([.height(320)])
        }
        .fileImporter(isPresented: $showPDFPicker, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await viewModel.importPDF(from: url) }
                }
            case .failure(let error):
                viewModel.pdfImportError = error.localizedDescription
            }
        }
        .sheet(isPresented: $showTextNoteEditor) {
            TextNoteEditorView { title, text in
                viewModel.addTextNote(title: title, text: text)
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
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.text, .plainText, .pdf], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importFile(from: url)
                }
            case .failure(let error):
                viewModel.pdfImportError = error.localizedDescription
            }
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
        }
    }

    private func importFile(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let name = url.deletingPathExtension().lastPathComponent
            let page = PageCapture(pageNumber: 1, extractedText: text, status: .completed)
            let source = Source(name: name, sourceType: .file, pages: [page])
            viewModel.addSource(source)
        } catch {
            viewModel.pdfImportError = "Failed to read file: \(error.localizedDescription)"
        }
    }
}

// Make Source conform to Identifiable for alert binding
extension Source: Equatable {
    static func == (lhs: Source, rhs: Source) -> Bool {
        lhs.id == rhs.id
    }
}
