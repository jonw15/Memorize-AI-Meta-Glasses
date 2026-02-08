/*
 * Live AI Manager
 * Background Live AI session manager - Supports Siri and Shortcuts without unlocking the phone
 * Uses Google Gemini Live for real-time conversation
 */

import Foundation
import SwiftUI
import AVFoundation

// MARK: - Live AI Manager

@MainActor
class LiveAIManager: ObservableObject {
    static let shared = LiveAIManager()

    @Published var isRunning = false
    @Published var isConnected = false
    @Published var errorMessage: String?

    // Dependencies
    private(set) var streamViewModel: StreamSessionViewModel?
    private var geminiService: GeminiLiveService?

    // Video frames
    private var currentVideoFrame: UIImage?
    private var isImageSendingEnabled = false
    private var frameUpdateTimer: Timer?
    private var imageSendTimer: Timer?

    // Conversation history
    private var conversationHistory: [ConversationMessage] = []

    // TTS
    private let tts = TTSService.shared

    private init() {
        // Listen for Intent triggers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLiveAITrigger(_:)),
            name: .liveAITriggered,
            object: nil
        )
    }

    /// Set the StreamSessionViewModel reference
    func setStreamViewModel(_ viewModel: StreamSessionViewModel) {
        self.streamViewModel = viewModel
    }

    @objc private func handleLiveAITrigger(_ notification: Notification) {
        Task { @MainActor in
            await startLiveAISession()
        }
    }

    // MARK: - Start Session

    /// Start Live AI session (background mode)
    func startLiveAISession() async {
        guard !isRunning else {
            print("⚠️ [LiveAIManager] Already running")
            return
        }

        guard let streamViewModel = streamViewModel else {
            print("❌ [LiveAIManager] StreamViewModel not set")
            tts.speak("Live AI not initialized, please open the app first")
            return
        }

        // Get API Key
        let apiKey = APIProviderManager.staticLiveAIAPIKey
        guard !apiKey.isEmpty else {
            errorMessage = "Please configure API Key in settings first"
            tts.speak("Please configure API Key in settings first")
            return
        }

        isRunning = true
        errorMessage = nil
        conversationHistory = []

        print("🚀 [LiveAIManager] Starting Live AI session...")

        do {
            // 1. Check if device is connected
            if !streamViewModel.hasActiveDevice {
                print("❌ [LiveAIManager] No active device connected")
                throw LiveAIError.noDevice
            }

            // 2. Start video stream (if not started)
            if streamViewModel.streamingStatus != .streaming {
                print("📹 [LiveAIManager] Starting stream...")
                await streamViewModel.handleStartStreaming()

                // Wait for stream to enter streaming state (max 5 seconds)
                var streamWait = 0
                while streamViewModel.streamingStatus != .streaming && streamWait < 50 {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    streamWait += 1
                }

                if streamViewModel.streamingStatus != .streaming {
                    print("❌ [LiveAIManager] Failed to start streaming")
                    throw LiveAIError.streamNotReady
                }
            }

            // 3. Pre-configure audio session (required for background mode)
            try configureAudioSessionForBackground()

            // 4. Initialize AI service
            geminiService = GeminiLiveService(apiKey: apiKey)
            setupCallbacks()

            // 5. Connect AI service
            print("🔌 [LiveAIManager] Connecting to AI service...")
            geminiService?.connect()

            // Wait for connection (max 10 seconds)
            var connectWait = 0
            while !isConnected && connectWait < 100 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                connectWait += 1
            }

            if !isConnected {
                print("❌ [LiveAIManager] Failed to connect to AI service")
                throw LiveAIError.connectionFailed
            }

            // 6. Start video frame update timer
            startFrameUpdateTimer()
            print("✅ [LiveAIManager] Frame update timer started")

            // 7. Start recording directly (skip TTS to avoid audio session conflicts)
            print("🎤 [LiveAIManager] About to start recording...")
            geminiService?.startRecording()

            print("✅ [LiveAIManager] Live AI session started, ready to talk")

        } catch let error as LiveAIError {
            errorMessage = error.localizedDescription
            print("❌ [LiveAIManager] LiveAIError: \(error)")
            await stopSession()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [LiveAIManager] Error: \(error)")
            await stopSession()
        }
    }

    // MARK: - Audio Session Configuration

    /// Pre-configure audio session (background mode requires configuration before initializing audio engine)
    private func configureAudioSessionForBackground() throws {
        let audioSession = AVAudioSession.sharedInstance()

        // Deactivate and reactivate to ensure a clean state
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ [LiveAIManager] Audio session deactivated")
        } catch {
            print("⚠️ [LiveAIManager] Failed to deactivate audio session: \(error)")
        }

        // Configure audio session
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers])
        try audioSession.setActive(true)
        print("✅ [LiveAIManager] Background audio session configured: category=\(audioSession.category.rawValue), mode=\(audioSession.mode.rawValue)")
    }

    // MARK: - Callbacks

    private func setupCallbacks() {
        guard let geminiService = geminiService else { return }

        geminiService.onConnected = { [weak self] in
            Task { @MainActor in
                self?.isConnected = true
                print("✅ [LiveAIManager] Gemini connected")
            }
        }

        geminiService.onFirstAudioSent = { [weak self] in
            Task { @MainActor in
                print("✅ [LiveAIManager] First audio send callback received, starting periodic image sending")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.isImageSendingEnabled = true
                    self?.startImageSendTimer()
                    print("📸 [LiveAIManager] Periodic image sending started")
                }
            }
        }

        geminiService.onUserTranscript = { [weak self] userText in
            Task { @MainActor in
                guard let self = self else { return }
                print("💬 [LiveAIManager] User: \(userText)")
                self.conversationHistory.append(
                    ConversationMessage(role: .user, content: userText)
                )
            }
        }

        geminiService.onTranscriptDone = { [weak self] fullText in
            Task { @MainActor in
                guard let self = self, !fullText.isEmpty else { return }
                print("💬 [LiveAIManager] AI: \(fullText)")
                self.conversationHistory.append(
                    ConversationMessage(role: .assistant, content: fullText)
                )
            }
        }

        geminiService.onError = { [weak self] error in
            Task { @MainActor in
                self?.errorMessage = error
                print("❌ [LiveAIManager] Gemini error: \(error)")
            }
        }
    }

    // MARK: - Frame Update

    private func startFrameUpdateTimer() {
        frameUpdateTimer?.invalidate()
        frameUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateVideoFrame()
            }
        }
    }

    private func updateVideoFrame() {
        if let frame = streamViewModel?.currentVideoFrame {
            currentVideoFrame = frame
        }
    }

    private var imageSendInterval: TimeInterval = 1.0

    private func startImageSendTimer() {
        stopImageSendTimer()
        imageSendTimer = Timer.scheduledTimer(withTimeInterval: imageSendInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      self.isImageSendingEnabled,
                      let frame = self.currentVideoFrame else { return }
                self.geminiService?.sendImageInput(frame)
            }
        }
    }

    private func stopImageSendTimer() {
        imageSendTimer?.invalidate()
        imageSendTimer = nil
    }

    // MARK: - Stop Session

    /// Stop Live AI session
    func stopSession() async {
        guard isRunning else { return }

        print("🛑 [LiveAIManager] Stopping session...")

        // Stop timers
        stopImageSendTimer()
        frameUpdateTimer?.invalidate()
        frameUpdateTimer = nil

        // Stop recording
        geminiService?.stopRecording()

        // Save conversation
        saveConversation()

        // Disconnect
        geminiService?.disconnect()

        // Stop video stream
        await streamViewModel?.stopSession()

        // Reset state
        geminiService = nil
        isConnected = false
        isRunning = false
        isImageSendingEnabled = false
        currentVideoFrame = nil

        print("✅ [LiveAIManager] Session stopped")
    }

    /// Save conversation to history
    private func saveConversation() {
        guard !conversationHistory.isEmpty else {
            print("💬 [LiveAIManager] No conversation content, skipping save")
            return
        }

        let record = ConversationRecord(
            messages: conversationHistory,
            aiModel: APIProviderManager.liveAIDefaultModel,
            language: "en-US"
        )

        ConversationStorage.shared.saveConversation(record)
        print("💾 [LiveAIManager] Conversation saved: \(conversationHistory.count) messages")
    }

    /// Manually trigger stop (called from UI)
    func triggerStop() {
        Task { @MainActor in
            await stopSession()
        }
    }
}

// MARK: - Live AI Error

enum LiveAIError: LocalizedError {
    case noDevice
    case streamNotReady
    case connectionFailed
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .noDevice:
            return "Glasses not connected, please pair them in Meta View first"
        case .streamNotReady:
            return "Failed to start video stream, please check glasses connection status"
        case .connectionFailed:
            return "AI service connection failed, please check network"
        case .noAPIKey:
            return "Please configure API Key in settings first"
        }
    }
}
