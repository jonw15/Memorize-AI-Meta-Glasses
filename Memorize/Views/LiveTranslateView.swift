/*
 * Live Translate View
 * Live translation main interface
 */

import SwiftUI

struct LiveTranslateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LiveTranslateViewModel()
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Video preview (if image enhancement is enabled)
            if viewModel.imageEnhanceEnabled {
                videoBackground
            }

            // Main content
            VStack(spacing: 0) {
                // Header
                headerView

                Spacer()

                // Language selection bar
                languageBar

                // Translation results area
                translationArea

                Spacer()

                // Control bar
                controlBar
            }
            .padding()
        }
        .onAppear {
            viewModel.connect()
            if viewModel.imageEnhanceEnabled {
                startVideoStream()
            }
        }
        .onDisappear {
            viewModel.disconnect()
            stopVideoStream()
        }
        .sheet(isPresented: $showSettings) {
            LiveTranslateSettingsView(viewModel: viewModel)
        }
        .alert("livetranslate.error.title".localized, isPresented: $viewModel.showError) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.imageEnhanceEnabled) { _, newValue in
            if newValue {
                startVideoStream()
            } else {
                stopVideoStream()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Title
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.title2)
                Text("livetranslate.title".localized)
                    .font(AppTypography.title2)
            }
            .foregroundColor(.white)

            Spacer()

            // Connection status
            connectionIndicator

            // Settings button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 8)

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.vertical, 8)
    }

    private var connectionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(viewModel.isConnected ? "livetranslate.connected".localized : "livetranslate.connecting".localized)
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Language Bar

    private var languageBar: some View {
        HStack(spacing: 16) {
            // Source language
            languageButton(
                language: viewModel.sourceLanguage,
                label: "livetranslate.source".localized
            ) {
                // Source language selection (via settings page)
                showSettings = true
            }

            // Swap button
            Button {
                viewModel.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }

            // Target language
            languageButton(
                language: viewModel.targetLanguage,
                label: "livetranslate.target".localized
            ) {
                showSettings = true
            }
        }
        .padding(.vertical, 16)
    }

    private func languageButton(language: TranslateLanguage, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.6))
                HStack(spacing: 6) {
                    Text(language.flag)
                        .font(.title2)
                    Text(language.displayName)
                        .font(AppTypography.body)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }

    // MARK: - Translation Area

    private var translationArea: some View {
        VStack(spacing: 16) {
            // Translation result card
            VStack(alignment: .leading, spacing: 12) {
                // Streaming translation
                if !viewModel.streamingTranslation.isEmpty {
                    Text(viewModel.streamingTranslation)
                        .font(AppTypography.body)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Final translation result
                if !viewModel.currentTranslation.isEmpty {
                    Text(viewModel.currentTranslation)
                        .font(AppTypography.title2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Placeholder text
                if viewModel.currentTranslation.isEmpty && viewModel.streamingTranslation.isEmpty {
                    Text("livetranslate.placeholder".localized)
                        .font(AppTypography.body)
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
            )

            // History (most recent entry)
            if let lastRecord = viewModel.translationHistory.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(lastRecord.sourceLanguage.flag) → \(lastRecord.targetLanguage.flag)")
                            .font(AppTypography.caption)
                        Spacer()
                        Text(lastRecord.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(AppTypography.caption)
                    }
                    .foregroundColor(.white.opacity(0.5))

                    Text(lastRecord.translatedText)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: 16) {
            // Recording status hint
            if viewModel.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("livetranslate.recording".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            // Recording button
            Button {
                viewModel.toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.isRecording ? Color.red : Color.blue)
                        .frame(width: 72, height: 72)

                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            .disabled(!viewModel.isConnected)
            .opacity(viewModel.isConnected ? 1.0 : 0.5)

            // Clear button
            if !viewModel.currentTranslation.isEmpty || !viewModel.streamingTranslation.isEmpty {
                Button {
                    viewModel.clearTranslation()
                } label: {
                    Text("livetranslate.clear".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Video Background

    private var videoBackground: some View {
        Group {
            if let frame = streamViewModel.currentVideoFrame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .opacity(0.3)
            }
        }
        .onChange(of: streamViewModel.currentVideoFrame) { _, frame in
            if let frame = frame {
                viewModel.updateVideoFrame(frame)
            }
        }
    }

    // MARK: - Video Stream

    private func startVideoStream() {
        Task {
            await streamViewModel.startSession()
        }
    }

    private func stopVideoStream() {
        Task {
            await streamViewModel.stopSession()
        }
    }
}

// Preview requires WearablesInterface - use in app context
// #Preview {
//     LiveTranslateView(streamViewModel: ...)
// }
