/*
 * Memorize Capture View
 * Page capture screen with countdown, camera button, and session timeline
 */

import SwiftUI

struct MemorizeCaptureView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    let book: Book?

    @StateObject private var viewModel = MemorizeCaptureViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedThumbnail: TimelineThumbnailPreview?

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

                // Pop Quiz button
                if viewModel.pages.contains(where: { $0.status == .completed }) {
                    popQuizButton
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
                .tint(AppColors.memorizeAccent)
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
