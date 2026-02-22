/*
 * Live AI View
 * Auto-starting real-time AI conversation interface
 */

import SwiftUI
import AVFoundation
import AVKit
import WebKit

struct LiveAIView: View {
    private struct InstructionStep: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        var isCompleted: Bool
    }

    private struct ShopItem: Identifiable {
        let id = UUID()
        let section: String
        let name: String
        let quantity: String
        let amazonQuery: String
        var hasItem: Bool
    }

    private struct TutorialVideo: Identifiable {
        let id = UUID()
        let title: String
        let duration: String
    }

    private enum RoomAction {
        case join
        case create
    }

    private enum BottomTab: String {
        case chatLog = "Chat Log"
        case videos = "Videos"
        case shop = "Shop"
        case instructions = "Instructions"
        case collab = "Collab"
    }

    @StateObject private var viewModel: OmniRealtimeViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var frameTimer: Timer?
    @State private var selectedBottomTab: BottomTab = .chatLog
    @State private var previousBottomTab: BottomTab = .chatLog
    @State private var isMuted = false
    @State private var savedMutedStateForChatLog: Bool?
    @State private var showConnectPanel = false
    @State private var selectedRoomAction: RoomAction?
    @State private var roomCode = ""
    @State private var instructionSteps = Self.defaultInstructionSteps
    @State private var shopItems = Self.defaultShopItems
    @State private var lastLoggedShopItemsSignature = ""
    @State private var streamSuspendedForNonChatTab = false
    @State private var fullscreenYouTubeVideo: OmniRealtimeViewModel.YouTubeVideoItem?
    @State private var savedMutedStateForFullscreen: Bool?
    private let feedbackSynth = AVSpeechSynthesizer()
    private static let defaultInstructionSteps: [InstructionStep] = []
    private static let shopSections: [String] = ["LUMBER", "HARDWARE", "PAINT & FINISH"]
    private static let defaultShopItems: [ShopItem] = [
        .init(section: "LUMBER", name: "2x4 Studs", quantity: "12", amazonQuery: "2x4 wood studs", hasItem: false),
        .init(section: "LUMBER", name: "3/4\" Plywood Sheets", quantity: "4", amazonQuery: "3/4 plywood sheets", hasItem: false),
        .init(section: "LUMBER", name: "Pine Trim", quantity: "20ft", amazonQuery: "pine trim boards", hasItem: false),
        .init(section: "HARDWARE", name: "Wood Screws (Box)", quantity: "1", amazonQuery: "wood screws box", hasItem: false),
        .init(section: "HARDWARE", name: "Pocket Hole Screws", quantity: "50ct", amazonQuery: "pocket hole screws", hasItem: false),
        .init(section: "HARDWARE", name: "Shelf Pins", quantity: "24", amazonQuery: "shelf pins", hasItem: false),
        .init(section: "PAINT & FINISH", name: "Primer", quantity: "1 gallon", amazonQuery: "interior wood primer", hasItem: false),
        .init(section: "PAINT & FINISH", name: "Matte Paint", quantity: "2 gallons", amazonQuery: "matte interior paint", hasItem: false),
        .init(section: "PAINT & FINISH", name: "Foam Rollers", quantity: "6", amazonQuery: "foam paint rollers", hasItem: false)
    ]
    private static let tutorialVideos: [TutorialVideo] = [
        .init(title: "Proper Ignition Coil Removal Techniques", duration: "4:20"),
        .init(title: "How to Gap Your Spark Plugs", duration: "6:05")
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
                if streamViewModel.hasReceivedFirstFrame, let frame = streamViewModel.currentVideoFrame {
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
            let liveAITabs: Set<BottomTab> = [.chatLog, .videos]
            if isConnected, liveAITabs.contains(selectedBottomTab), fullscreenYouTubeVideo == nil, !isMuted, !viewModel.isRecording {
                viewModel.startRecording()
            }
        }
        .onChange(of: selectedBottomTab) { tab in
            let lastTab = previousBottomTab
            previousBottomTab = tab

            let liveAITabs: Set<BottomTab> = [.chatLog, .videos]
            let wasCompatible = liveAITabs.contains(lastTab)
            let isCompatible = liveAITabs.contains(tab)

            // Switching between two compatible tabs (chatLog ↔ videos) — do nothing.
            if wasCompatible && isCompatible { return }

            // Leaving a compatible tab for a non-compatible one: suspend Live AI.
            if wasCompatible && !isCompatible {
                savedMutedStateForChatLog = isMuted
                viewModel.suspendAudioForEmbeddedVideo()
                isMuted = true
                activateVideoPlaybackAudioSession()
                if streamViewModel.streamingStatus != .stopped {
                    streamSuspendedForNonChatTab = true
                    Task {
                        await streamViewModel.stopSession()
                    }
                }
                return
            }

            // Returning from a non-compatible tab to a compatible one: resume Live AI.
            if !wasCompatible && isCompatible, let savedMuted = savedMutedStateForChatLog {
                deactivateVideoPlaybackAudioSessionOverride()
                viewModel.resumeAudioAfterEmbeddedVideo()
                isMuted = savedMuted
                if savedMuted {
                    viewModel.stopRecording()
                } else {
                    if streamSuspendedForNonChatTab, streamViewModel.hasActiveDevice {
                        streamSuspendedForNonChatTab = false
                        Task {
                            await streamViewModel.handleStartStreaming()
                            await MainActor.run {
                                restartChatAudioCaptureWithRetry()
                            }
                        }
                    } else {
                        restartChatAudioCaptureWithRetry()
                    }
                }
                savedMutedStateForChatLog = nil
            }
        }
        .onChange(of: viewModel.toolCallInstructions) { instructions in
            applyToolCallInstructions(instructions)
        }
        .onChange(of: viewModel.toolCallTools) { _ in
            applyToolCallShopItemsIfNeeded()
        }
        .onChange(of: viewModel.toolCallParts) { _ in
            applyToolCallShopItemsIfNeeded()
        }
        .onChange(of: viewModel.youtubeVideos) { videos in
            if !videos.isEmpty {
                selectedBottomTab = .videos
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
        .fullScreenCover(item: $fullscreenYouTubeVideo) { video in
            FullscreenYouTubePlayerView(video: video)
        }
        .onChange(of: fullscreenYouTubeVideo) { video in
            let liveAITabs: Set<BottomTab> = [.chatLog, .videos]
            if video != nil {
                // Opening fullscreen: suspend Live AI
                savedMutedStateForFullscreen = isMuted
                viewModel.suspendAudioForEmbeddedVideo()
                isMuted = true
                activateVideoPlaybackAudioSession()
                if streamViewModel.streamingStatus != .stopped {
                    streamSuspendedForNonChatTab = true
                    Task { await streamViewModel.stopSession() }
                }
            } else {
                // Closing fullscreen: resume Live AI (only if on a compatible tab)
                guard liveAITabs.contains(selectedBottomTab) else { return }
                deactivateVideoPlaybackAudioSessionOverride()
                viewModel.resumeAudioAfterEmbeddedVideo()
                let savedMuted = savedMutedStateForFullscreen ?? false
                isMuted = savedMuted
                if savedMuted {
                    viewModel.stopRecording()
                } else {
                    if streamSuspendedForNonChatTab, streamViewModel.hasActiveDevice {
                        streamSuspendedForNonChatTab = false
                        Task {
                            await streamViewModel.handleStartStreaming()
                            await MainActor.run { restartChatAudioCaptureWithRetry() }
                        }
                    } else {
                        restartChatAudioCaptureWithRetry()
                    }
                }
                savedMutedStateForFullscreen = nil
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
            if selectedBottomTab == .chatLog || selectedBottomTab == .videos {
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
            }

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
            tabButton(icon: "cart", tab: .shop)
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
            livePreviewCard
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

    private var livePreviewCard: some View {
        Group {
            if let frame = streamViewModel.currentVideoFrame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black.opacity(0.75)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var tabPlaceholderContent: some View {
        if selectedBottomTab == .instructions {
            instructionsPanel
        } else if selectedBottomTab == .videos {
            videosPanel
        } else if selectedBottomTab == .shop {
            shopPanel
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

            if !viewModel.toolCallTools.isEmpty || !viewModel.toolCallParts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if !viewModel.toolCallTools.isEmpty {
                        Text("Tools: \(viewModel.toolCallTools.joined(separator: ", "))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                    if !viewModel.toolCallParts.isEmpty {
                        Text("Parts: \(viewModel.toolCallParts.joined(separator: ", "))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }

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

                if !step.wrappedValue.detail.isEmpty {
                    Text(step.wrappedValue.detail)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(step.isCompleted.wrappedValue ? Color.gray.opacity(0.9) : Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
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

    private var videosPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tutorial Videos")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                if !viewModel.youtubeVideos.isEmpty {
                    ForEach(viewModel.youtubeVideos) { video in
                        youtubeVideoCard(video: video)
                    }
                } else {
                    ForEach(Self.tutorialVideos) { video in
                        tutorialVideoCard(video: video)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .background(Color.black.opacity(0.28))
    }

    private func applyToolCallInstructions(_ instructions: [String]) {
        let normalized = instructions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !normalized.isEmpty else { return }

        instructionSteps = normalized.map { text in
            InstructionStep(title: text, detail: "", isCompleted: false)
        }
    }

    private func applyToolCallShopItemsIfNeeded() {
        let tools = normalizedToolCallItems(viewModel.toolCallTools)
        let parts = normalizedToolCallItems(viewModel.toolCallParts)

        guard !tools.isEmpty || !parts.isEmpty else { return }

        var updatedItems: [ShopItem] = []
        updatedItems.append(contentsOf: tools.map {
            ShopItem(
                section: "TOOLS",
                name: $0,
                quantity: "1",
                amazonQuery: "\($0) diy tool",
                hasItem: false
            )
        })
        updatedItems.append(contentsOf: parts.map {
            ShopItem(
                section: "PARTS",
                name: $0,
                quantity: "1",
                amazonQuery: "\($0) replacement part",
                hasItem: false
            )
        })

        let signature = updatedItems
            .map { "\($0.section)|\($0.name.lowercased())|\($0.quantity)|\($0.amazonQuery.lowercased())" }
            .joined(separator: "||")

        if signature != lastLoggedShopItemsSignature {
            for item in updatedItems {
                print("[ShopItem] section=\(item.section), name=\(item.name), quantity=\(item.quantity), query=\(item.amazonQuery)")
            }
            lastLoggedShopItemsSignature = signature
        }

        shopItems = updatedItems
    }

    private func normalizedToolCallItems(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        for raw in items {
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, cleaned.lowercased() != "none" else { continue }
            let key = cleaned.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            normalized.append(cleaned)
        }
        return normalized
    }

    private func tutorialVideoCard(video: TutorialVideo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)

                Circle()
                    .fill(Color(red: 0.24, green: 0.42, blue: 0.93))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    )

                Text(video.duration)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .padding(8)
            }

            Text(video.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func youtubeVideoCard(video: OmniRealtimeViewModel.YouTubeVideoItem) -> some View {
        let thumbnailURL: URL? = {
            if !video.thumbnail.isEmpty, let url = URL(string: video.thumbnail) {
                return url
            }
            if let videoID = extractYouTubeVideoId(from: video.url) {
                return URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")
            }
            return nil
        }()

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                fullscreenYouTubeVideo = video
            } label: {
                ZStack {
                    if let thumbnailURL {
                        AsyncImage(url: thumbnailURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                thumbnailPlaceholder
                            case .empty:
                                thumbnailPlaceholder
                                    .overlay(ProgressView().tint(.white))
                            @unknown default:
                                thumbnailPlaceholder
                            }
                        }
                    } else {
                        thumbnailPlaceholder
                    }

                    // Play button overlay
                    Circle()
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: 2)
                        )
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(video.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.14), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(16/9, contentMode: .fit)
    }

    private func extractYouTubeVideoId(from url: String) -> String? {
        let pattern = #"embed/([a-zA-Z0-9_-]{11})(?:\?|/|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(url.startIndex..<url.endIndex, in: url)
        guard
            let match = regex.firstMatch(in: url, options: [], range: range),
            match.numberOfRanges > 1,
            let idRange = Range(match.range(at: 1), in: url)
        else {
            return nil
        }
        return String(url[idRange])
    }

    private var shopPanel: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(shopSectionsForDisplay, id: \.self) { section in
                    sectionHeader(title: section)
                    ForEach(shopItemIndices(for: section), id: \.self) { index in
                        shopItemRow(item: $shopItems[index])
                        Divider()
                            .background(Color.white.opacity(0.08))
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color.black.opacity(0.28))
    }

    private func sectionHeader(title: String) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.white.opacity(0.65))
                .tracking(1.2)
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private func shopItemRow(item: Binding<ShopItem>) -> some View {
        HStack(spacing: 14) {
            Button {
                item.hasItem.wrappedValue.toggle()
            } label: {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(item.hasItem.wrappedValue ? Color(red: 0.24, green: 0.42, blue: 0.93) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                item.hasItem.wrappedValue ? Color(red: 0.24, green: 0.42, blue: 0.93) : Color.white.opacity(0.45),
                                lineWidth: 1.6
                            )
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(item.hasItem.wrappedValue ? 1 : 0)
                    )
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.wrappedValue.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("Quantity: \(item.wrappedValue.quantity)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.65))
            }

            Spacer(minLength: 10)

            Button {
                openAmazon(query: item.wrappedValue.amazonQuery)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Shop")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 106, height: 44)
                .background(Color(red: 0.24, green: 0.42, blue: 0.93))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.clear)
    }

    private func shopItemIndices(for section: String) -> [Int] {
        shopItems.indices.filter { shopItems[$0].section == section }
    }

    private var shopSectionsForDisplay: [String] {
        var seen = Set<String>()
        var sections: [String] = []
        for item in shopItems {
            if !seen.contains(item.section) {
                seen.insert(item.section)
                sections.append(item.section)
            }
        }
        return sections
    }

    private func openAmazon(query: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let amazonAppURL = URL(string: "amazon://search?k=\(encoded)"),
              let amazonWebURL = URL(string: "https://www.amazon.com/s?k=\(encoded)") else { return }

        openURL(amazonAppURL) { accepted in
            if !accepted {
                openURL(amazonWebURL)
            }
        }
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

    private func activateVideoPlaybackAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
            print("🔊 [LiveAIView] Video playback audio session activated")
        } catch {
            print("⚠️ [LiveAIView] Failed to activate video playback audio session: \(error)")
        }
    }

    private func deactivateVideoPlaybackAudioSessionOverride() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Reset category to .playAndRecord BEFORE deactivating so the Bluetooth HFP
            // route is available immediately when the session is reactivated for Live AI.
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP])
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
            print("🔉 [LiveAIView] Video playback audio session override deactivated")
        } catch {
            print("⚠️ [LiveAIView] Failed to deactivate video playback audio session override: \(error)")
        }
    }

    private func restartChatAudioCaptureWithRetry() {
        let liveAITabs: Set<BottomTab> = [.chatLog, .videos]
        guard liveAITabs.contains(selectedBottomTab), fullscreenYouTubeVideo == nil, !isMuted, viewModel.isConnected else { return }

        viewModel.stopRecording()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if liveAITabs.contains(selectedBottomTab), fullscreenYouTubeVideo == nil, !isMuted, viewModel.isConnected, !viewModel.isRecording {
                viewModel.startRecording()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if liveAITabs.contains(selectedBottomTab), fullscreenYouTubeVideo == nil, !isMuted, viewModel.isConnected, !viewModel.isRecording {
                viewModel.startRecording()
            }
        }
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
                NotificationCenter.default.post(name: .returnToNewProjectIntro, object: nil)
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

private struct YouTubeCardWebPreview: UIViewRepresentable {
    let urlString: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isUserInteractionEnabled = true
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else { return }
        if context.coordinator.loadedURLString != urlString {
            context.coordinator.loadedURLString = urlString
            uiView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        }
    }

    /// Stop all media playback when SwiftUI removes the WebView (e.g. tab switch).
    /// This prevents the YouTube iframe from holding the audio session and blocking
    /// the Live AI .playAndRecord category from restoring Bluetooth HFP output.
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.evaluateJavaScript(
            "document.querySelectorAll('video,audio').forEach(function(e){e.pause()})",
            completionHandler: nil
        )
        uiView.loadHTMLString("", baseURL: nil)
    }

    final class Coordinator {
        var loadedURLString: String?
    }
}

private struct FullscreenYouTubePlayerView: View {
    let video: OmniRealtimeViewModel.YouTubeVideoItem
    @Environment(\.dismiss) private var dismiss

    private var playerURLString: String? {
        let pattern = #"embed/([a-zA-Z0-9_-]{11})(?:\?|/|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(video.url.startIndex..<video.url.endIndex, in: video.url)
        guard
            let match = regex.firstMatch(in: video.url, options: [], range: range),
            match.numberOfRanges > 1,
            let idRange = Range(match.range(at: 1), in: video.url)
        else { return nil }
        let videoID = String(video.url[idRange])
        return "https://app.ariaspark.com/yt/?v=\(videoID)"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let urlString = playerURLString {
                YouTubeCardWebPreview(urlString: urlString)
                    .ignoresSafeArea()
            }

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(.top, 8)
            .padding(.leading, 16)
        }
    }
}
