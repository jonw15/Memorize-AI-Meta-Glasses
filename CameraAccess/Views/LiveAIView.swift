/*
 * Live AI View
 * Auto-starting real-time AI conversation interface
 */

import SwiftUI
import AVFoundation

struct LiveAIView: View {
    private struct InstructionStep: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        var isCompleted: Bool
    }

    private enum RoomAction {
        case join
        case create
    }

    private enum BottomTab: String {
        case chatLog = "Chat Log"
        case videos = "Videos"
        case webLinks = "Web Links"
        case instructions = "Instructions"
        case collab = "Collab"
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
    @State private var instructionSteps = Self.defaultInstructionSteps
    private let feedbackSynth = AVSpeechSynthesizer()
    private static let defaultInstructionSteps: [InstructionStep] = [
        .init(
            title: "Open the vehicle hood and secure it",
            detail: "Ensure the safety latch is engaged.",
            isCompleted: false
        ),
        .init(
            title: "Identify the engine cover bolts",
            detail: "Usually 4-6 plastic or metal fasteners.",
            isCompleted: false
        ),
        .init(
            title: "Remove the ignition coil carefully",
            detail: "Disconnect the electrical harness first.",
            isCompleted: false
        ),
        .init(
            title: "Unscrew the old spark plug",
            detail: "Use a 5/8\" or 13/16\" socket wrench.",
            isCompleted: false
        ),
        .init(
            title: "Install the new spark plug by hand",
            detail: "Thread gently first to avoid cross-threading.",
            isCompleted: false
        ),
        .init(
            title: "Torque to manufacturer spec",
            detail: "Confirm exact torque value for your model.",
            isCompleted: false
        ),
        .init(
            title: "Reconnect and test engine idle",
            detail: "Verify there are no warning lights.",
            isCompleted: false
        ),
        .init(
            title: "Close hood and clean workspace",
            detail: "Remove tools and confirm all clips are secured.",
            isCompleted: false
        )
    ]

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
                    tabPlaceholderContent
                }

                // Status and stop button
                controlsView
                }
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
        HStack(spacing: 6) {
            tabButton(icon: "text.bubble", tab: .chatLog)
            tabButton(icon: "play.rectangle", tab: .videos)
            tabButton(icon: "link", tab: .webLinks)
            tabButton(icon: "list.bullet.clipboard", tab: .instructions)
            tabButton(icon: "person.2.wave.2", tab: .collab)
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
            if tab == .collab {
                // Route through home's existing Live Chat entry flow.
                viewModel.disconnect()
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NotificationCenter.default.post(name: .liveChatTriggered, object: nil)
                }
                return
            }

            selectedBottomTab = tab
            withAnimation(.easeInOut(duration: 0.2)) {
                showConnectPanel = false
                selectedRoomAction = nil
                roomCode = ""
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(isSelected ? Color(red: 60/255, green: 106/255, blue: 237/255) : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
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

    @ViewBuilder
    private var tabPlaceholderContent: some View {
        if selectedBottomTab == .instructions {
            instructionsPanel
        } else {
            VStack {
                Spacer()
                Text(selectedBottomTab.rawValue)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                Text("Coming Soon")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.top, 4)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var instructionsPanel: some View {
        VStack {
            HStack {
                Text("Steps")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(instructionSteps.filter { $0.isCompleted }.count)/\(instructionSteps.count) COMPLETED")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.47, blue: 0.14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 1.0, green: 0.47, blue: 0.14).opacity(0.12))
                    .cornerRadius(9)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    ForEach($instructionSteps) { $step in
                        instructionStepRow(step: $step)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color(red: 0.12, green: 0.08, blue: 0.04).opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func instructionStepRow(step: Binding<InstructionStep>) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                step.isCompleted.wrappedValue.toggle()
            } label: {
                Image(systemName: step.isCompleted.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(
                        step.isCompleted.wrappedValue
                            ? Color(red: 1.0, green: 0.47, blue: 0.14)
                            : Color(red: 0.40, green: 0.46, blue: 0.56)
                    )
                    .padding(.top, 1)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.wrappedValue.title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(step.isCompleted.wrappedValue ? Color.white.opacity(0.62) : .white)
                    .strikethrough(step.isCompleted.wrappedValue, color: Color.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.wrappedValue.detail)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(step.isCompleted.wrappedValue ? Color.gray.opacity(0.9) : Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(step.isCompleted.wrappedValue ? 0.04 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    step.isCompleted.wrappedValue
                        ? Color(red: 1.0, green: 0.35, blue: 0.06).opacity(0.72)
                        : Color.white.opacity(0.12),
                    lineWidth: 1.2
                )
        )
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
