/*
 * Live AI View
 * Auto-starting real-time AI conversation interface
 */

import SwiftUI
import AVFoundation

struct LiveAIView: View {
    private enum RoomAction {
        case join
        case create
    }

    private enum BottomTab: String {
        case chatLog = "Chat Log"
        case guide = "Guide"
        case connect = "Connect"
    }

    @StateObject private var viewModel: OmniRealtimeViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var frameTimer: Timer?
    @State private var selectedBottomTab: BottomTab = .chatLog
    @State private var isMuted = false
    @State private var showConnectPanel = false
    @State private var selectedRoomAction: RoomAction?
    @State private var roomCode = ""
    private let feedbackSynth = AVSpeechSynthesizer()

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
                VStack(spacing: 0) {
                // Header (flush with status bar)
                headerView
                    .padding(.top, 8) // Slightly below the status bar

                if selectedBottomTab == .chatLog {
                    chatLogFullPage
                } else {
                    Spacer()
                }

                // Status and stop button
                controlsView
                }
            }

            if selectedBottomTab == .guide && streamViewModel.hasActiveDevice {
                guidePanel
                    .transition(.opacity)
                    .zIndex(5)
                    .allowsHitTesting(false)
            }

            if showConnectPanel && streamViewModel.hasActiveDevice {
                connectRoomPanel
                    .transition(.opacity)
                    .zIndex(6)
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

            muteButton
                .frame(maxWidth: .infinity, alignment: .center)

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

    private var muteButton: some View {
        Button {
            if isMuted {
                viewModel.startRecording()
                isMuted = false
                playMuteToggleSound(isMuted: false)
            } else {
                viewModel.stopRecording()
                isMuted = true
                playMuteToggleSound(isMuted: true)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(isMuted ? "Unmute" : "Mute")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(Color.black.opacity(0.65))
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var liquidGlassTabBar: some View {
        HStack(spacing: 10) {
            tabButton(icon: "text.bubble", tab: .chatLog)
            tabButton(icon: "book", tab: .guide)
            tabButton(icon: "person.2.wave.2", tab: .connect)
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
                showConnectPanel = (tab == .connect)
                if tab != .connect {
                    selectedRoomAction = nil
                    roomCode = ""
                }
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

    private var chatLogFullPage: some View {
        VStack(spacing: 10) {
            Text("Put on your glasses, look at your project, and tell me what you're working on.")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 14)
                .padding(.top, 6)

            Rectangle()
                .fill(Color.white.opacity(0.22))
                .frame(height: 1)
                .padding(.horizontal, 14)
                .padding(.top, 2)

            HStack {
                Text("Chat Log")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.28))
    }

    private var connectRoomPanel: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showConnectPanel = false
                            selectedBottomTab = .chatLog
                            selectedRoomAction = nil
                            roomCode = ""
                        }
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 64, height: 64)
                            .background(Color.white.opacity(0.92))
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer()

                Text("Join a DIY Project\nWith Friends!")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 28)

                VStack(spacing: 14) {
                    Button {
                        selectedRoomAction = .join
                    } label: {
                        VStack(spacing: 4) {
                            Text("JOIN ROOM")
                                .font(.system(size: 20, weight: .bold))
                            Text("Help a Friend")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 86)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.89, green: 0.39, blue: 0.09), Color(red: 0.76, green: 0.28, blue: 0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                    }

                    Button {
                        selectedRoomAction = .create
                    } label: {
                        VStack(spacing: 4) {
                            Text("CREATE ROOM")
                                .font(.system(size: 20, weight: .bold))
                            Text("Start a Project")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 86)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.40, green: 0.62, blue: 0.19), Color(red: 0.25, green: 0.45, blue: 0.12)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)

                if let action = selectedRoomAction {
                    VStack(spacing: 10) {
                        Text(action == .join ? "Enter room code to join" : "Enter room code to create")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))

                        TextField("4-character code", text: $roomCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(Color.white.opacity(0.95))
                            .foregroundColor(.black)
                            .cornerRadius(10)
                            .onChange(of: roomCode) { value in
                                let filtered = value.uppercased().filter { $0.isLetter || $0.isNumber }
                                roomCode = String(filtered.prefix(4))
                            }

                        Button(action == .join ? "Join" : "Create") {
                            roomCode = String(roomCode.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4))
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .cornerRadius(10)
                        .disabled(roomCode.count != 4)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(14)
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
    }

    private var guidePanel: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.96, green: 0.45, blue: 0.12).opacity(0.16))
                        .frame(width: 108, height: 108)
                    Circle()
                        .fill(Color(red: 0.96, green: 0.45, blue: 0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                }

                Text("Waiting for more details")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("More context from your conversation is needed to build your custom guide. Keep talking to Aria.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 18)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
            .background(Color(red: 0.16, green: 0.08, blue: 0.05).opacity(0.86))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(red: 0.96, green: 0.45, blue: 0.12).opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 24)
        }
    }

    private func playMuteToggleSound(isMuted: Bool) {
        // Use a short spoken earcon so feedback still works under the app's audio session.
        if feedbackSynth.isSpeaking {
            feedbackSynth.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: isMuted ? "Muted" : "Unmuted")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        feedbackSynth.speak(utterance)
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
