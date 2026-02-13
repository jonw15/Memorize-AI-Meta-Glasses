/*
 * Live AI View
 * Auto-starting real-time AI conversation interface
 */

import SwiftUI

struct LiveAIView: View {
    private enum BottomTab: String {
        case chatLog = "Chat Log"
        case guide = "Guide"
        case shop = "Shop"
    }

    @StateObject private var viewModel: OmniRealtimeViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showChatLogPanel = false
    @State private var frameTimer: Timer?
    @State private var selectedBottomTab: BottomTab = .chatLog

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        // Use the Live AI API key based on selected provider
        let liveAIApiKey = APIProviderManager.staticLiveAIAPIKey
        self._viewModel = StateObject(wrappedValue: OmniRealtimeViewModel(apiKey: liveAIApiKey.isEmpty ? apiKey : liveAIApiKey))
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()

            // Device not connected reminder
            if !streamViewModel.hasActiveDevice {
                deviceNotConnectedView
            } else {
                // Video feed (full opacity, no white mask)
                if let videoFrame = streamViewModel.currentVideoFrame {
                    GeometryReader { geometry in
                        Image(uiImage: videoFrame)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                // Header (flush with status bar)
                headerView
                    .padding(.top, 8) // Slightly below the status bar

                Spacer()

                // Status and stop button
                controlsView
                }
            }

            if showChatLogPanel && streamViewModel.hasActiveDevice {
                chatLogPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(5)
            }
        }
        .onAppear {
            // Only start features when device is connected
            guard streamViewModel.hasActiveDevice else {
                print("⚠️ LiveAIView: RayBan Meta glasses not connected, skipping startup")
                return
            }

            // Start video stream
            Task {
                print("🎥 LiveAIView: Starting video stream")
                await streamViewModel.handleStartStreaming()
            }

            // Auto-connect and start recording
            viewModel.connect()

            // Update video frames
            frameTimer?.invalidate()
            frameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if let frame = streamViewModel.currentVideoFrame {
                    viewModel.updateVideoFrame(frame)
                }
            }
        }
        .onDisappear {
            // Stop AI conversation and video stream
            print("🎥 LiveAIView: Stopping AI conversation and video stream")
            frameTimer?.invalidate()
            frameTimer = nil
            viewModel.disconnect()
            Task {
                if streamViewModel.streamingStatus != .stopped {
                    await streamViewModel.stopSession()
                }
            }
        }
        .onChange(of: viewModel.isConnected) { isConnected in
            if isConnected, !viewModel.isRecording {
                viewModel.startRecording()
            }
        }
        .alert("error".localized, isPresented: $viewModel.showError) {
            Button("ok".localized) {
                viewModel.dismissError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("liveai.title".localized)
                .font(AppTypography.headline)
                .foregroundColor(.white)

            Spacer()

            // Hide/show conversation button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showChatLogPanel.toggle()
                }
            } label: {
                Image(systemName: showChatLogPanel ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }

            // Connection status
            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.isConnected ? "liveai.connected".localized : "liveai.connecting".localized)
                    .font(AppTypography.caption)
                    .foregroundColor(.white)
            }

            // Speaking indicator
            if viewModel.isSpeaking {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                    Text("liveai.speaking".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                }
            }

            // Image send interval toggle
            Button {
                let newInterval: TimeInterval = viewModel.imageSendInterval == 1.0 ? 3.0 : 1.0
                viewModel.setImageSendInterval(newInterval)
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                    Text(viewModel.imageSendInterval == 1.0 ? "1s" : "3s")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(viewModel.imageSendInterval == 1.0 ? Color.green.opacity(0.6) : Color.orange.opacity(0.6))
                .cornerRadius(12)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: AppSpacing.md) {
            // Recording status
            HStack(spacing: AppSpacing.sm) {
                if viewModel.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("liveai.listening".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                    Text("liveai.stop".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.black.opacity(0.6))
            .cornerRadius(AppCornerRadius.xl)

            // Stop button (only button)
            Button {
                viewModel.disconnect()
                dismiss()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                    Text("liveai.stop".localized)
                        .font(AppTypography.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(AppCornerRadius.lg)
            }
            .padding(.horizontal, AppSpacing.lg)

            liquidGlassTabBar
                .padding(.horizontal, AppSpacing.lg)
        }
        .padding(.bottom, AppSpacing.lg)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var liquidGlassTabBar: some View {
        HStack(spacing: 10) {
            tabButton(icon: "text.bubble", tab: .chatLog)
            tabButton(icon: "book", tab: .guide)
            tabButton(icon: "cart", tab: .shop)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func tabButton(icon: String, tab: BottomTab) -> some View {
        let isSelected = selectedBottomTab == tab

        return Button {
            selectedBottomTab = tab
            withAnimation(.easeInOut(duration: 0.2)) {
                showChatLogPanel = (tab == .chatLog)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? .black : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private var chatLogPanel: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 44, height: 5)
                    .padding(.top, 10)

                HStack {
                    Text("Chat Log")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showChatLogPanel = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 14)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.conversationHistory) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if !viewModel.currentTranscript.isEmpty {
                                MessageBubble(
                                    message: ConversationMessage(
                                        role: .assistant,
                                        content: viewModel.currentTranscript
                                    )
                                )
                                .id("current")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                    .onChange(of: viewModel.conversationHistory.count) { _ in
                        if let lastMessage = viewModel.conversationHistory.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.currentTranscript) { _ in
                        withAnimation {
                            proxy.scrollTo("current", anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 108)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Device Not Connected View

    private var deviceNotConnectedView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.liveAI.opacity(0.6))

                Text("liveai.device.notconnected.title".localized)
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)

                Text("liveai.device.notconnected.message".localized)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()

            // Back button
            Button {
                dismiss()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "chevron.left")
                    Text("liveai.device.backtohome".localized)
                        .font(AppTypography.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.primary)
                .foregroundColor(.white)
                .cornerRadius(AppCornerRadius.lg)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
    }
}
