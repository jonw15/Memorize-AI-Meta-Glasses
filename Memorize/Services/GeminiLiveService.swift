/*
 * Gemini Live WebSocket Service
 * Provides real-time audio chat with Google Gemini AI
 * Uses Gemini Live model for real-time audio conversation
 */

import Foundation
import UIKit
import AVFoundation

// MARK: - Gemini Live Service

final class GeminiLiveService: NSObject, @unchecked Sendable {
    struct MultipleStepInstructionsPayload {
        let problem: String
        let brand: String
        let model: String
        let tools: [String]
        let parts: [String]
        let instructions: [String]
    }

    struct YouTubeVideo {
        let videoId: String
        let url: String
        let title: String
        let thumbnail: String
    }

    // WebSocket
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // Configuration
    private let apiKey: String
    private let model: String
    private let customSystemPrompt: String?
    private let includeTools: Bool

    // Audio Engine (for recording)
    private var audioEngine: AVAudioEngine?

    // Audio Playback Engine (separate engine for playback)
    private var playbackEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let playbackAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)
    private let recordTargetFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)
    private var recordConverter: AVAudioConverter?

    // Audio buffer management
    private var audioBuffer = Data()
    private var isCollectingAudio = false
    private var audioChunkCount = 0
    private let minChunksBeforePlay: Int
    private let streamingBatchSize: Int
    private let streamingFlushDelay: TimeInterval
    private var hasStartedPlaying = false
    private var isPlaybackEngineRunning = false
    private var dropIncomingAudioUntilInterrupted = false
    private var pendingPlaybackBufferCount = 0
    private var hasReceivedPlaybackTurnDone = false

    // Streaming batch buffer — accumulates small chunks into larger ones for smooth playback
    private var streamingBuffer = Data()
    private var streamingFlushTimer: Timer?
    /// Response timing instrumentation to help tune perceived latency.
    private var responseTimingStart: Date?
    private var responseTimingReason: String?
    private var hasLoggedFirstTranscriptDelta = false
    private var hasLoggedFirstAudioDelta = false

    // Callbacks
    var onTranscriptDelta: ((String) -> Void)?
    var onTranscriptDone: ((String) -> Void)?
    var onUserTranscript: ((String) -> Void)?
    var onAudioDelta: ((Data) -> Void)?
    var onAudioDone: (() -> Void)?
    var onSpeechStarted: (() -> Void)?
    var onSpeechStopped: (() -> Void)?
    var onInterrupted: (() -> Void)?
    var onError: ((String) -> Void)?
    var onConnected: (() -> Void)?
    var onFirstAudioSent: (() -> Void)?
    /// Called with mic input audio level (0.0 = silence, 1.0 = max). Updated ~every buffer (~50ms).
    var onMicLevel: ((Float) -> Void)?
    var onMultipleStepInstructions: ((MultipleStepInstructionsPayload) -> Void)?
    var onYouTubeResults: (([YouTubeVideo], Bool) -> Void)?

    // State
    private var isRecording = false
    private var hasAudioBeenSent = false
    private var isSessionConfigured = false
    private var isDisconnecting = false
    private var isPlaybackEnabled = true
    private var connectWaitTask: Task<Void, Never>?
    /// When true, recording stays active (audio session alive) but audio is not sent to Gemini.
    var isMicMuted = false
    /// When true, use `.playback` audio session instead of `.playAndRecord` + `.voiceChat`.
    /// Avoids Voice Processing I/O overhead. Call `startRecording()` to switch to full mode.
    var playbackOnly = false
    /// When true, voice-chat mode prefers the loud speaker on phone-only routes.
    /// Use carefully with a mic-suppression guard to avoid feedback loops.
    var preferSpeakerInConversation = false
    /// Gemini voice name used in session config. Set before calling connect().
    var voiceName: String = "Aoede"

    init(
        apiKey: String,
        model: String? = nil,
        systemPrompt: String? = nil,
        includeTools: Bool = true,
        minChunksBeforePlay: Int = 1,
        streamingBatchSize: Int = 4800,
        streamingFlushDelay: TimeInterval = 0.04
    ) {
        self.apiKey = apiKey
        self.model = model ?? APIProviderManager.staticLiveAIDefaultModel
        self.customSystemPrompt = systemPrompt
        self.includeTools = includeTools
        self.minChunksBeforePlay = max(1, minChunksBeforePlay)
        self.streamingBatchSize = max(2400, streamingBatchSize)
        self.streamingFlushDelay = max(0.02, streamingFlushDelay)
        super.init()
        setupAudioEngine()
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        setupPlaybackEngine()
    }

    private func setupPlaybackEngine() {
        playbackEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()

        guard let playbackEngine = playbackEngine,
              let playerNode = playerNode else {
            print("❌ [Gemini] Failed to initialize playback engine")
            return
        }

        playbackEngine.attach(playerNode)
        playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: playbackAudioFormat)
        playbackEngine.prepare()
        print("✅ [Gemini] Playback engine initialized")
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            if playbackOnly {
                try audioSession.setCategory(.playback, mode: .spokenAudio, options: [])
                print("🔊 [Gemini] Media playback mode active")
            } else {
                let hasBluetoothHFP = audioSession.availableInputs?.contains { $0.portType == .bluetoothHFP } ?? false
                if hasBluetoothHFP {
                    // Glasses/HFP headset connected — use .voiceChat for echo cancellation
                    try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP])
                    _ = selectBluetoothRouteIfAvailable()
                    print("🎧 [Gemini] Conversation mode with Bluetooth HFP")
                } else {
                    // No HFP device — use .default mode to avoid Voice Isolation blocking mic
                    try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
                    try? audioSession.setPreferredInput(nil)
                    try? audioSession.overrideOutputAudioPort(.speaker)
                    print("📱 [Gemini] Conversation mode using built-in mic + speaker")
                }
            }
            try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])

            // Keep conversation audio configured without forcing the system microphone-modes UI,
            // which can interrupt the experience with a popup route/noise-cancellation chooser.
            if AVCaptureDevice.preferredMicrophoneMode == .voiceIsolation {
                print("🎤 [Gemini] Voice Isolation already active")
            } else {
                print("🎤 [Gemini] Voice Isolation not active (current: \(AVCaptureDevice.preferredMicrophoneMode.rawValue)); skipping system prompt")
            }
        } catch {
            print("⚠️ [Gemini] Audio session configuration failed: \(error)")
        }
    }

    func activatePlaybackOnlyMode() {
        playbackOnly = true
        if isRecording {
            stopRecording()
        }
        setupPlaybackEngine()
        startPlaybackEngine()
    }

    func activateConversationMode(startRecordingIfNeeded: Bool = true) {
        playbackOnly = false
        setupPlaybackEngine()
        startPlaybackEngine()
        if startRecordingIfNeeded {
            startRecording()
        }
    }

    func supportsHandsFreeMicRoute() -> Bool {
        let session = AVAudioSession.sharedInstance()
        let safePorts: Set<AVAudioSession.Port> = [
            .bluetoothHFP,
            .bluetoothA2DP,
            .bluetoothLE,
            .headphones,
            .usbAudio
        ]

        let outputPorts = session.currentRoute.outputs.map(\.portType)
        let inputPorts = session.currentRoute.inputs.map(\.portType)
        let availableInputPorts = session.availableInputs?.map(\.portType) ?? []

        let hasSafeRoute = outputPorts.contains(where: safePorts.contains) ||
            inputPorts.contains(where: safePorts.contains) ||
            availableInputPorts.contains(where: safePorts.contains)

        let outputs = session.currentRoute.outputs.map { "\($0.portType.rawValue)(\($0.portName))" }
        let inputs = session.currentRoute.inputs.map { "\($0.portType.rawValue)(\($0.portName))" }
        print("🎧 [Gemini] Hands-free mic route check outputs=\(outputs) inputs=\(inputs) supported=\(hasSafeRoute)")

        return hasSafeRoute
    }

    @discardableResult
    private func selectBluetoothRouteIfAvailable() -> Bool {
        let session = AVAudioSession.sharedInstance()
        guard let inputs = session.availableInputs else {
            print("🎧 [Gemini] No available inputs")
            return false
        }
        print("🎧 [Gemini] Available inputs: \(inputs.map { "\($0.portName) (\($0.portType.rawValue))" })")
        for input in inputs where input.portType == .bluetoothHFP {
            do {
                try session.setPreferredInput(input)
                print("🎧 [Gemini] Preferred Bluetooth HFP input selected: \(input.portName)")
            } catch {
                print("⚠️ [Gemini] Failed to set preferred Bluetooth input: \(error)")
            }
            return true
        }
        print("🎧 [Gemini] No Bluetooth HFP input found, using default")
        return false
    }

    private func deactivateAudioSessionIfIdle() {
        guard !isRecording, !isPlaybackEngineRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            print("🔇 [Gemini] Audio session deactivated (idle)")
        } catch {
            print("⚠️ [Gemini] Failed to deactivate audio session: \(error)")
        }
    }

    private func startPlaybackEngine() {
        guard let playbackEngine = playbackEngine else { return }

        // If engine is already running, just sync the flag
        if playbackEngine.isRunning {
            isPlaybackEngineRunning = true
            return
        }

        do {
            configureAudioSession()
            try playbackEngine.start()
            isPlaybackEngineRunning = true
            print("▶️ [Gemini] Playback engine started")
        } catch {
            print("❌ [Gemini] Failed to start playback engine: \(error)")
            isPlaybackEngineRunning = false
        }
    }

    private func stopPlaybackEngine() {
        guard let playbackEngine = playbackEngine, isPlaybackEngineRunning else { return }

        playerNode?.stop()
        playerNode?.reset()
        pendingPlaybackBufferCount = 0
        hasReceivedPlaybackTurnDone = false
        playbackEngine.stop()
        isPlaybackEngineRunning = false
        print("⏹️ [Gemini] Playback engine stopped and queue cleared")
        deactivateAudioSessionIfIdle()
    }

    // MARK: - WebSocket Connection

    func connect() {
        connectWaitTask?.cancel()
        connectWaitTask = nil
        isDisconnecting = false
        // Gemini Live WebSocket URL with API key (dynamic from server config)
        let baseURL = APIProviderManager.staticLiveAIWebsocketURL
        // Re-read the latest key in case the config fetch completed after init
        var trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            trimmedKey = APIProviderManager.staticLiveAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !trimmedKey.isEmpty else {
            // Config server fetch may still be in progress (serverless cold start).
            // Poll until the key becomes available.
            print("⏳ [Gemini] API key not available yet, waiting for config fetch...")
            connectWaitTask = Task { [weak self] in
                var waited = 0.0
                while waited < 10.0 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    if Task.isCancelled { return }
                    waited += 0.5
                    let key = APIProviderManager.staticLiveAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !key.isEmpty {
                        print("✅ [Gemini] API key became available after \(waited)s, connecting")
                        self?.connect()
                        return
                    }
                }
                if Task.isCancelled { return }
                // Still no key — re-trigger the config fetch and keep trying
                print("⏳ [Gemini] API key still missing after 10s, re-fetching config...")
                try? await AIConfigService.fetchConfig()
                if Task.isCancelled { return }
                self?.connect()
            }
            return
        }
        connectWaitTask = nil

        print("🔌 [Gemini] Preparing to connect WebSocket")

        guard var components = URLComponents(string: baseURL) else {
            print("❌ [Gemini] Invalid base URL: \(baseURL)")
            onError?("Invalid URL")
            return
        }

        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name.lowercased() == "key" }) {
            queryItems.append(URLQueryItem(name: "key", value: trimmedKey))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            print("❌ [Gemini] Failed to build URL from components")
            onError?("Invalid URL")
            return
        }

        print("🔌 [Gemini] WebSocket host: \(url.host ?? "unknown"), keyLength: \(trimmedKey.count)")

        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())

        webSocket = urlSession?.webSocketTask(with: url)
        webSocket?.resume()

        print("🔌 [Gemini] WebSocket task started")
        receiveMessage()
    }

    func disconnect() {
        print("🔌 [Gemini] Disconnecting WebSocket")
        isDisconnecting = true
        streamingFlushTimer?.invalidate()
        streamingFlushTimer = nil
        streamingBuffer = Data()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        stopRecording()
        stopPlaybackEngine()
        isSessionConfigured = false
    }

    // MARK: - Session Configuration

    private func configureSession() {
        guard !isSessionConfigured else { return }

        let instructions: String
        if let customSystemPrompt {
            instructions = customSystemPrompt
        } else {
            // Default Live AI system prompt
            instructions = LiveAIModeManager.staticSystemPrompt + """


<system_instructions>
<role>
You are Aria — a concise, friendly DIY voice assistant on the Meta Quest.
Speak clearly, focus on one step at a time, and keep answers brief unless the user asks for more detail.
Always refer to what you see in the image to understand the user’s context.
Your primary role is to interpret the user’s request and format it into the correct tool call.
</role>

<guardrails>
Do not apologize.
</guardrails>
</system_instructions>
"""
        }

        // Gemini Live API setup message
        var setupConfig: [String: Any] = [
            "model": model.hasPrefix("models/") ? model : "models/\(model)",
            "generation_config": [
                "response_modalities": ["AUDIO"],
                "speech_config": [
                    "voice_config": [
                        "prebuilt_voice_config": [
                            "voice_name": voiceName  // Gemini voice options: Aoede, Charon, Fenrir, Kore, Puck
                        ]
                    ]
                ]
            ],
            "system_instruction": [
                "parts": [
                    ["text": instructions]
                ]
            ],
            // Request both user and assistant speech transcripts from Gemini Live.
            "input_audio_transcription": [:],
            "output_audio_transcription": [:]
        ]

        if includeTools {
            setupConfig["tools"] = [
                [
                    "functionDeclarations": [
                        multipleStepsInstructionDeclaration,
                        youtubeDeclaration
                    ]
                ]
            ]
        }

        let setupMessage: [String: Any] = ["setup": setupConfig]

        sendJSON(setupMessage)
        print("⚙️ [Gemini] Sending session configuration")
    }

    // MARK: - Audio Recording

    func startRecording() {
        guard !isRecording else { return }

        do {
            print("🎤 [Gemini] Starting recording")

            let audioSession = AVAudioSession.sharedInstance()
            switch audioSession.recordPermission {
            case .undetermined:
                audioSession.requestRecordPermission { [weak self] granted in
                    if granted {
                        self?.startRecording()
                    } else {
                        self?.onError?("Microphone permission denied")
                    }
                }
                return
            case .denied:
                onError?("Microphone permission denied")
                return
            case .granted:
                break
            @unknown default:
                break
            }

            if let engine = audioEngine, engine.isRunning {
                engine.stop()
                engine.inputNode.removeTap(onBus: 0)
            }

            configureAudioSession()

            guard let engine = audioEngine else {
                print("❌ [Gemini] Audio engine not initialized")
                return
            }

            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            if let recordTargetFormat {
                recordConverter = AVAudioConverter(from: inputFormat, to: recordTargetFormat)
            } else {
                recordConverter = nil
            }

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer, inputFormat: inputFormat)
            }

            engine.prepare()
            try engine.start()

            isRecording = true
            print("✅ [Gemini] Recording started")

        } catch {
            print("❌ [Gemini] Failed to start recording: \(error.localizedDescription)")
            onError?("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        print("🛑 [Gemini] Stopping recording")
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        isRecording = false
        hasAudioBeenSent = false
        deactivateAudioSessionIfIdle()
    }

    /// Interrupt AI speech by clearing the playback buffer and resetting the player node.
    /// Recording continues so the user can speak immediately.
    func interruptPlayback(expectServerInterruption: Bool = false) {
        if expectServerInterruption, (isCollectingAudio || hasStartedPlaying || !audioBuffer.isEmpty) {
            dropIncomingAudioUntilInterrupted = true
        }
        guard isPlaybackEngineRunning else { return }
        print("🤚 [Gemini] Interrupting AI playback")
        streamingFlushTimer?.invalidate()
        streamingFlushTimer = nil
        streamingBuffer = Data()
        playerNode?.stop()
        playerNode?.reset()
        audioBuffer = Data()
        isCollectingAudio = false
        audioChunkCount = 0
        hasStartedPlaying = false
        pendingPlaybackBufferCount = 0
        hasReceivedPlaybackTurnDone = false
        // Re-prime the player node so new audio can be scheduled immediately
        playerNode?.play()
    }

    // MARK: - Playback Controls (for Read Aloud / offline playback)

    /// When true, playAudio will still buffer but won't call playerNode.play()
    private var isPlaybackPaused = false

    /// Pause playback without clearing buffers — incoming chunks still accumulate
    func pausePlayback() {
        isPlaybackPaused = true
        playerNode?.pause()
    }

    /// Resume paused playback
    func resumePlayback() {
        isPlaybackPaused = false
        if let playbackEngine = playbackEngine, !playbackEngine.isRunning {
            startPlaybackEngine()
        }
        playerNode?.play()
    }

    /// Stop streaming playback and play accumulated audio from a byte offset.
    /// `audioData` is the full accumulated PCM buffer; `fromByteOffset` is where to start.
    func seekAndPlay(audioData: Data, fromByteOffset: Int) {
        guard let playerNode = playerNode,
              let playbackEngine = playbackEngine,
              let playbackAudioFormat = playbackAudioFormat else { return }

        isPlaybackPaused = false

        // Stop current playback
        playerNode.stop()
        playerNode.reset()
        pendingPlaybackBufferCount = 0
        hasReceivedPlaybackTurnDone = false
        streamingFlushTimer?.invalidate()
        streamingFlushTimer = nil
        streamingBuffer = Data()

        let clampedOffset = max(0, min(fromByteOffset, audioData.count))
        guard clampedOffset < audioData.count else { return }

        let remaining = audioData.subdata(in: clampedOffset..<audioData.count)
        guard !remaining.isEmpty else { return }

        if !playbackEngine.isRunning {
            startPlaybackEngine()
        }

        if let pcmBuffer = createPCMBuffer(from: remaining, format: playbackAudioFormat) {
            playerNode.scheduleBuffer(pcmBuffer)
            playerNode.play()
        }
    }

    func suspendAudioForExternalPlayback() {
        print("🔇 [Gemini] Suspending audio I/O for external playback")
        if isRecording {
            stopRecording()
        }
        stopPlaybackEngine()
        isPlaybackEnabled = false
        deactivateAudioSessionIfIdle()
    }

    func resumeAudioForConversation() {
        isPlaybackEnabled = true
        // Reinitialize the playback engine — the audio-session category switch
        // (.playAndRecord → .playback → .playAndRecord) invalidates the engine's
        // internal format chain, causing silence even though start() succeeds.
        // A fresh setup guarantees the node graph matches the current session.
        setupPlaybackEngine()
        startPlaybackEngine()
        // Bluetooth route discovery can lag after an audio-session category switch
        // (e.g. returning from .playback used by YouTube video).  Retry several
        // times so the HFP route is selected as soon as Core Audio exposes it.
        for delay in [0.3, 0.8, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.selectBluetoothRouteIfAvailable()
            }
        }
        print("🔊 [Gemini] Resumed audio I/O for conversation")
    }

    /// Suspend audio engines and release Voice Processing I/O so the WKWebView
    /// WebContent process can play YouTube audio.
    ///
    /// Root cause: `.voiceChat` mode activates Apple's Voice Processing I/O
    /// audio unit which takes exclusive control of the audio hardware route.
    /// The WebContent process's FigXPC negotiation for an audio output context
    /// fails (err=-16155) because Voice Processing I/O has locked the route.
    ///
    /// Fix: switch mode from `.voiceChat` → `.default`, deactivate to release
    /// Voice Processing I/O, then reactivate with `.mixWithOthers` so the
    /// WebContent process can share the audio output.
    /// WebSocket and camera stream stay alive.
    func muteForOverlayPlayback() {
        print("🔇 [Gemini] Muting for overlay video")
        // 1. Stop recording engine
        if isRecording {
            audioEngine?.inputNode.removeTap(onBus: 0)
            audioEngine?.stop()
            isRecording = false
            hasAudioBeenSent = false
        }
        // 2. Prevent incoming Gemini audio from restarting the playback engine
        isPlaybackEnabled = false
        // 3. Stop playback engine (inline — don't call stopPlaybackEngine()
        //    which triggers deactivateAudioSessionIfIdle prematurely)
        if let playbackEngine = playbackEngine, isPlaybackEngineRunning {
            playerNode?.stop()
            playerNode?.reset()
            playbackEngine.stop()
            isPlaybackEngineRunning = false
            print("⏹️ [Gemini] Playback engine stopped for overlay")
        }
        // 4. Release Voice Processing I/O and route audio to phone speaker.
        //    BluetoothHFP is voice-only — WKWebView can't play media through it.
        //    BluetoothA2DP on Meta glasses drops after a few frames.
        //    Force speaker output for reliable YouTube playback.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
            try session.setCategory(
                .playback, mode: .default,
                options: []
            )
            try session.setActive(true)
            print("🔊 [Gemini] Audio session switched to .playback (A2DP enabled, camera stream paused)")
        } catch {
            print("⚠️ [Gemini] Failed to switch audio session for YouTube: \(error)")
        }
    }

    /// Restore `.voiceChat` mode and restart audio engines after YouTube
    /// overlay is dismissed.
    func unmuteAfterOverlayPlayback() {
        isPlaybackEnabled = true
        // Full reinitialisation — the mode switch invalidates the engine's
        // internal format chain. setupPlaybackEngine rebuilds the node graph
        // and startPlaybackEngine calls configureAudioSession() which restores
        // .playAndRecord + .voiceChat + .allowBluetoothHFP.
        setupPlaybackEngine()
        startPlaybackEngine()
        // Bluetooth route discovery can lag after a mode switch.
        for delay in [0.3, 0.8, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.selectBluetoothRouteIfAvailable()
            }
        }
        print("🔊 [Gemini] Restored .voiceChat mode after overlay video")
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) {
        guard !isMicMuted else { return }
        guard let recordConverter, let recordTargetFormat else { return }

        let ratio = recordTargetFormat.sampleRate / inputFormat.sampleRate
        let targetFrameCapacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))

        guard let converted = AVAudioPCMBuffer(pcmFormat: recordTargetFormat, frameCapacity: max(1, targetFrameCapacity)) else {
            return
        }

        var hasProvidedInput = false
        var error: NSError?

        let status = recordConverter.convert(to: converted, error: &error) { _, outStatus in
            if hasProvidedInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasProvidedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard error == nil, status != .error else { return }
        guard let floatChannelData = converted.floatChannelData else { return }

        let frameLength = Int(converted.frameLength)
        let channel = floatChannelData.pointee

        var int16Data = [Int16](repeating: 0, count: frameLength)
        for i in 0..<frameLength {
            let sample = channel[i]
            let clampedSample = max(-1.0, min(1.0, sample))
            int16Data[i] = Int16(clampedSample * 32767.0)
        }

        // Calculate RMS audio level for waveform visualization
        if let onMicLevel {
            var sumOfSquares: Float = 0
            for i in 0..<frameLength {
                let sample = channel[i]
                sumOfSquares += sample * sample
            }
            let rms = sqrt(sumOfSquares / Float(max(frameLength, 1)))
            let normalized = min(rms * 3.0, 1.0)  // Amplify for better visual response
            DispatchQueue.main.async {
                onMicLevel(normalized)
            }
        }

        let data = Data(bytes: int16Data, count: frameLength * MemoryLayout<Int16>.size)
        let base64Audio = data.base64EncodedString()

        sendRealtimeInput(audioData: base64Audio)

        if !hasAudioBeenSent {
            hasAudioBeenSent = true
            print("✅ [Gemini] First audio sent")
            DispatchQueue.main.async { [weak self] in
                self?.onFirstAudioSent?()
            }
        }
    }

    // MARK: - Send Events

    private var multipleStepsInstructionDeclaration: [String: Any] {
        [
            "name": "multiple_step_instructions",
            "description": "REQUIRED for any task involving 2 or more steps. STRICTLY SILENT ACTION: Do NOT output conversational filler like 'Sure', 'Okay', or 'Here are the steps'. Do NOT list the steps in the text response. Output ONLY the function call json. The application will read the first step automatically.",
            "parameters": [
                "type": "object",
                "properties": [
                    "problem": ["type": "string"],
                    "brand": ["type": "string"],
                    "model": ["type": "string"],
                    "tools": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Required tools. Use ['none'] if not applicable."
                    ],
                    "parts": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Required parts. Use ['none'] if not applicable."
                    ],
                    "instructions": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "The list of steps. IMPORTANT: Keep each step extremely concise (max 5-7 words). Focus ONLY on the core action (e.g., 'Step 1: Open Settings', 'Step 2: Tap General'). Remove all fluff."
                    ]
                ],
                "required": ["problem", "brand", "model", "instructions", "tools", "parts"]
            ]
        ]
    }

    private var youtubeDeclaration: [String: Any] {
        [
            "name": "youtube",
            "description": "Opens the YouTube player or searches for videos. Use this for any requests related to YouTube, such as 'Open YouTube', 'Search YouTube for videos about...', or 'Find a video on how to fix a leaky faucet.'",
            "parameters": [
                "type": "object",
                "properties": [
                    "search_string": [
                        "type": "string",
                        "description": "The topic or video the user wants to search for. This is optional; omit it if the user only asks to open YouTube without specifying what to search for."
                    ]
                ]
            ]
        ]
    }

    private func sendJSON(_ json: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [Gemini] Failed to serialize JSON")
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(message) { error in
            if let error = error {
                if self.shouldSuppressSocketError(error) {
                    return
                }
                print("❌ [Gemini] Failed to send: \(error.localizedDescription)")
                self.onError?("Send error: \(error.localizedDescription)")
            }
        }
    }

    /// Ensure the playback engine is running so new AI audio can be heard.
    func startPlaybackEngineIfNeeded() {
        if !isPlaybackEngineRunning {
            setupPlaybackEngine()
            startPlaybackEngine()
        }
    }

    /// Send a burst of silent audio to force the server to interrupt its current turn.
    func sendSilentAudioToInterrupt() {
        let silentBytes = Data(count: 6400)
        let base64 = silentBytes.base64EncodedString()
        print("🤫 [Gemini] Sending silent audio burst to trigger server interruption")
        sendRealtimeInput(audioData: base64)
    }

    private func sendRealtimeInput(audioData: String) {
        // Gemini Live realtime input format
        let message: [String: Any] = [
            "realtime_input": [
                "media_chunks": [
                    [
                        "mime_type": "audio/pcm;rate=16000",
                        "data": audioData
                    ]
                ]
            ]
        ]
        sendJSON(message)
    }

    func sendImageInput(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            print("❌ [Gemini] Failed to compress image")
            return
        }
        let base64Image = imageData.base64EncodedString()

        //print("📸 [Gemini] Sending image: \(imageData.count) bytes")

        let message: [String: Any] = [
            "realtime_input": [
                "media_chunks": [
                    [
                        "mime_type": "image/jpeg",
                        "data": base64Image
                    ]
                ]
            ]
        ]
        sendJSON(message)
    }

    func sendTextInput(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        beginResponseTiming(reason: "text_prompt")

        let message: [String: Any] = [
            "client_content": [
                "turns": [
                    [
                        "role": "user",
                        "parts": [
                            ["text": trimmed]
                        ]
                    ]
                ],
                "turn_complete": true
            ]
        ]
        print("🧭 [Gemini] Sending text input prompt")
        sendJSON(message)
    }

    private func sendFunctionResponse(id: String, functionName: String, result: [String: Any], isSilent: Bool = false) {
        var functionResponseItem: [String: Any] = [
            "id": id,
            "name": functionName,
            "response": result
        ]
        if isSilent {
            functionResponseItem["scheduling"] = "SILENT"
        }

        let payload: [String: Any] = [
            "toolResponse": [
                "functionResponses": [functionResponseItem]
            ]
        ]
        print("🛠️ [Gemini] Sending tool response for \(functionName), silent=\(isSilent)")
        sendJSON(payload)
    }

    // MARK: - Receive Messages

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage()

            case .failure(let error):
                if self?.shouldSuppressSocketError(error) == true {
                    return
                }
                print("❌ [Gemini] Failed to receive message: \(error.localizedDescription)")
                self?.onError?("Receive error: \(error.localizedDescription)")
            }
        }
    }

    private func shouldSuppressSocketError(_ error: Error) -> Bool {
        if isDisconnecting {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }

        let normalized = error.localizedDescription.lowercased()
        return normalized.contains("cancelled") || normalized.contains("socket is not connected")
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleServerEvent(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleServerEvent(text)
            }
        @unknown default:
            break
        }
    }

    private func handleServerEvent(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        DispatchQueue.main.async {
            // Handle setup complete
            if json["setupComplete"] != nil {
                print("✅ [Gemini] Session configuration complete")
                self.isSessionConfigured = true
                self.onConnected?()
                return
            }

            // Some backends emit transcript events at the top level.
            // Preserve raw text (including leading spaces for word boundaries).
            for key in ["inputTranscription", "input_transcription", "inputAudioTranscription", "input_audio_transcription"] {
                if let container = json[key] as? [String: Any] {
                    for textKey in ["text", "transcript"] {
                        if let raw = container[textKey] as? String, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            print("👤 [Gemini] User said (top-level): \(raw)")
                            self.onUserTranscript?(raw)
                            break
                        }
                    }
                    break
                }
            }
            if let text = self.extractTranscript(from: json, containerKeys: ["outputTranscription", "output_transcription", "outputAudioTranscription", "output_audio_transcription"]) {
                print("💬 [Gemini] AI text (top-level): \(text)")
                self.onTranscriptDelta?(text)
            }

            // Handle server content (audio/text responses)
            if let serverContent = json["serverContent"] as? [String: Any] {
                self.handleServerContent(serverContent)
                return
            }

            // Handle tool calls (if any)
            if let toolCall = json["toolCall"] as? [String: Any] {
                self.handleToolCall(toolCall)
                return
            }
            if let toolCall = json["tool_call"] as? [String: Any] {
                self.handleToolCall(toolCall)
                return
            }

            // Handle errors
            if let error = json["error"] as? [String: Any] {
                let message = error["message"] as? String ?? "Unknown error"
                print("❌ [Gemini] Server error: \(message)")
                self.onError?(message)
                return
            }
        }
    }

    private func handleServerContent(_ content: [String: Any]) {
        var hasOutputTranscription = false

        // Prefer explicit speech transcription when available.
        if let text = extractTranscript(from: content, containerKeys: ["outputTranscription", "output_transcription", "outputAudioTranscription", "output_audio_transcription"]) {
            noteFirstAssistantTranscriptDelta()
            print("💬 [Gemini] AI text: \(text)")
            onTranscriptDelta?(text)
            hasOutputTranscription = true
        }

        // Check for model turn
        if let modelTurn = content["modelTurn"] as? [String: Any],
           let parts = modelTurn["parts"] as? [[String: Any]] {

            for part in parts {
                // Skip thinking/reasoning parts — only show the final spoken response.
                if part["thought"] as? Bool == true { continue }

                // Fallback text path: some model variants emit assistant text only here.
                if !hasOutputTranscription, let text = part["text"] as? String {
                    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty, !isLikelyInternalObservationText(cleaned) {
                        noteFirstAssistantTranscriptDelta()
                        print("💬 [Gemini] AI response fallback text: \(cleaned)")
                        onTranscriptDelta?(cleaned)
                    }
                }

                // Handle inline audio data
                if let inlineData = part["inlineData"] as? [String: Any],
                   let mimeType = inlineData["mimeType"] as? String,
                   mimeType.contains("audio"),
                   let base64Audio = inlineData["data"] as? String,
                   let audioData = Data(base64Encoded: base64Audio) {
                    if dropIncomingAudioUntilInterrupted {
                        continue
                    }
                    noteFirstAssistantAudioDelta()
                    onAudioDelta?(audioData)
                    handleAudioChunk(audioData)
                }
            }
        }

        // Check if turn is complete
        if let turnComplete = content["turnComplete"] as? Bool, turnComplete {
            print("✅ [Gemini] AI response complete")
            dropIncomingAudioUntilInterrupted = false
            finishAudioPlayback()
            onTranscriptDone?("")
            finishResponseTiming(status: "turn_complete")
        }

        // Check for interrupted flag
        if let interrupted = content["interrupted"] as? Bool, interrupted {
            print("⚠️ [Gemini] Response interrupted")
            dropIncomingAudioUntilInterrupted = false
            stopPlaybackEngine()
            setupPlaybackEngine()
            onInterrupted?()
            finishResponseTiming(status: "interrupted")
        }

        // Handle input transcription (user speech)
        // Preserve raw text (including leading spaces that indicate word boundaries).
        for key in ["inputTranscription", "input_transcription", "inputAudioTranscription", "input_audio_transcription"] {
            if let container = content[key] as? [String: Any] {
                for textKey in ["text", "transcript"] {
                    if let raw = container[textKey] as? String, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        beginResponseTiming(reason: "voice_input")
                        print("👤 [Gemini] User said: \(raw)")
                        onUserTranscript?(raw)
                        break
                    }
                }
                break
            }
        }
    }

    private func isLikelyInternalObservationText(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("observing the current scene")
            || normalized.contains("focused on the visual input")
            || normalized.contains("processing this visual information")
            || normalized.contains("analyze the prompt")
    }

    private func extractTranscript(from object: [String: Any], containerKeys: [String]) -> String? {
        for key in containerKeys {
            if let container = object[key] as? [String: Any] {
                for textKey in ["text", "transcript"] {
                    if let raw = container[textKey] as? String {
                        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleaned.isEmpty { return cleaned }
                    }
                }
            }
        }
        return nil
    }

    private func beginResponseTiming(reason: String) {
        if reason == "voice_input", !hasLoggedFirstTranscriptDelta, !hasLoggedFirstAudioDelta {
            responseTimingStart = Date()
            responseTimingReason = reason
            return
        }

        guard responseTimingStart == nil else { return }
        responseTimingStart = Date()
        responseTimingReason = reason
        hasLoggedFirstTranscriptDelta = false
        hasLoggedFirstAudioDelta = false
    }

    private func noteFirstAssistantTranscriptDelta() {
        guard let start = responseTimingStart, !hasLoggedFirstTranscriptDelta else { return }
        hasLoggedFirstTranscriptDelta = true
        let elapsed = Date().timeIntervalSince(start)
        let reason = responseTimingReason ?? "unknown"
        print("⏱️ [Gemini] First assistant transcript delta after \(String(format: "%.2f", elapsed))s (\(reason))")
    }

    private func noteFirstAssistantAudioDelta() {
        guard let start = responseTimingStart, !hasLoggedFirstAudioDelta else { return }
        hasLoggedFirstAudioDelta = true
        let elapsed = Date().timeIntervalSince(start)
        let reason = responseTimingReason ?? "unknown"
        print("⏱️ [Gemini] First assistant audio chunk after \(String(format: "%.2f", elapsed))s (\(reason))")
    }

    private func finishResponseTiming(status: String) {
        guard let start = responseTimingStart else { return }
        let elapsed = Date().timeIntervalSince(start)
        let reason = responseTimingReason ?? "unknown"
        print("⏱️ [Gemini] Response timing finished in \(String(format: "%.2f", elapsed))s (\(reason), \(status))")
        responseTimingStart = nil
        responseTimingReason = nil
        hasLoggedFirstTranscriptDelta = false
        hasLoggedFirstAudioDelta = false
    }

    // MARK: - Tool Calls

    private func handleToolCall(_ toolCall: [String: Any]) {
        print("🔧 [Gemini] Tool call payload: \(toolCall)")

        let calls = (toolCall["functionCalls"] as? [[String: Any]])
            ?? (toolCall["function_calls"] as? [[String: Any]])
            ?? []

        for call in calls {
            if (call["name"] as? String) == "multiple_step_instructions" {
                print("🧩 [MultipleStepInstructions] Tool call received: \(call)")
            }
            dispatchToolCall(call)
        }
    }

    private func dispatchToolCall(_ functionCall: [String: Any]) {
        let id = functionCall["id"] as? String ?? UUID().uuidString
        let name = functionCall["name"] as? String ?? ""

        let rawArgs = functionCall["args"] ?? functionCall["arguments"] ?? [:]
        let args: [String: Any]
        if let dictArgs = rawArgs as? [String: Any] {
            args = dictArgs
        } else if let rawString = rawArgs as? String,
                  let data = rawString.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            args = parsed
        } else {
            args = [:]
        }

        switch name {
        case "multiple_step_instructions":
            print("🧩 [MultipleStepInstructions] Dispatching multiple_step_instructions")

            let rawProblem = (args["problem"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let rawBrand = (args["brand"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let rawModel = (args["model"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let problem = rawProblem.lowercased() == "unknown" ? "" : rawProblem
            let brand = rawBrand.lowercased() == "unknown" ? "" : rawBrand
            let model = rawModel.lowercased() == "unknown" ? "" : rawModel
            let tools = (args["tools"] as? [Any])?.compactMap { $0 as? String } ?? []
            let parts = (args["parts"] as? [Any])?.compactMap { $0 as? String } ?? []
            let instructions = (args["instructions"] as? [Any])?.compactMap { $0 as? String } ?? []

            onMultipleStepInstructions?(
                MultipleStepInstructionsPayload(
                    problem: problem,
                    brand: brand,
                    model: model,
                    tools: tools,
                    parts: parts,
                    instructions: instructions
                )
            )
            print("🧩 [MultipleStepInstructions] Parsed payload: problem='\(problem)', brand='\(brand)', model='\(model)', tools=\(tools.count), parts=\(parts.count), steps=\(instructions.count)")

            let youtubeSearchQuery = [problem, brand, model]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.lowercased() != "none" }
                .joined(separator: " ")
            print("[Youtube] Auto search from multiple_step_instructions query='\(youtubeSearchQuery)'")
            searchYouTube(youtubeSearchQuery, autoOpenVideos: false)

            if !instructions.isEmpty {
                print("🛠️ [Gemini] multiple_step_instructions first step: \(instructions[0])")
                sendFunctionResponse(
                    id: id,
                    functionName: name,
                    result: ["success": true, "info": "System is handling step guidance. Do not list steps."],
                    isSilent: true
                )
            } else {
                sendFunctionResponse(
                    id: id,
                    functionName: name,
                    result: ["success": true]
                )
            }

        case "youtube":
            let youtubeSearch = (args["search_string"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            print("[Youtube] DispatchToolCall youtube search_string='\(youtubeSearch)'")
            searchYouTube(youtubeSearch, autoOpenVideos: true)
            sendFunctionResponse(
                id: id,
                functionName: name,
                result: ["success": true]
            )

        default:
            print("⚠️ [Gemini] Unknown tool call: \(name)")
            sendFunctionResponse(
                id: id,
                functionName: name,
                result: ["success": false, "error": "Unknown function name: \(name)"]
            )
        }
    }

    private func searchYouTube(_ searchString: String, autoOpenVideos: Bool = true) {
        guard let url = URL(string: "https://app.ariaspark.com/ai/json/youtube/search") else {
            print("[Youtube] Invalid endpoint URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "query": searchString.isEmpty ? "DIY project tutorial" : searchString,
            "maxResults": 4
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            print("[Youtube] Failed to serialize request body")
            return
        }
        request.httpBody = bodyData

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                print("[Youtube] Request error: \(error.localizedDescription)")
                return
            }

            guard let data else {
                print("[Youtube] Empty response body")
                return
            }

            if let rawJSON = String(data: data, encoding: .utf8) {
                print("[Youtube] Response JSON: \(rawJSON)")
            } else {
                print("[Youtube] Response received (\(data.count) bytes)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[Youtube] Failed to parse response JSON")
                return
            }

            let dataArray = json["data"] as? [[String: Any]] ?? []
            let videos: [YouTubeVideo] = dataArray.compactMap { item in
                guard let videoId = item["videoId"] as? String,
                      let url = item["url"] as? String,
                      let title = item["title"] as? String,
                      let thumbnail = item["thumbnail"] as? String else {
                    return nil
                }
                return YouTubeVideo(videoId: videoId, url: url, title: title, thumbnail: thumbnail)
            }

            print("[Youtube] Parsed \(videos.count) videos")
            DispatchQueue.main.async {
                self?.onYouTubeResults?(videos, autoOpenVideos)
            }
        }.resume()
    }

    // MARK: - Audio Playback

    private func handleAudioChunk(_ audioData: Data) {
        guard isPlaybackEnabled else { return }

        if !isCollectingAudio {
            isCollectingAudio = true
            hasReceivedPlaybackTurnDone = false
            DispatchQueue.main.async { [weak self] in
                self?.onSpeechStarted?()
            }
            audioBuffer = Data()
            streamingBuffer = Data()
            audioChunkCount = 0
            hasStartedPlaying = false

            if isPlaybackEngineRunning || (playbackEngine?.isRunning ?? false) {
                stopPlaybackEngine()
                setupPlaybackEngine()
                // Don't start engine yet — playAudio() will start it when data is ready
            }
        }

        audioChunkCount += 1

        if !hasStartedPlaying {
            // Initial buffering — wait for minChunksBeforePlay before starting
            audioBuffer.append(audioData)

            if audioChunkCount >= minChunksBeforePlay {
                hasStartedPlaying = true
                playAudio(audioBuffer)
                audioBuffer = Data()
            }
        } else {
            // Streaming mode — batch small chunks into larger buffers for smooth playback
            streamingBuffer.append(audioData)

            if streamingBuffer.count >= streamingBatchSize {
                flushStreamingBuffer()
            } else {
                scheduleStreamingFlush()
            }
        }
    }

    /// Flush accumulated streaming buffer to the player
    private func flushStreamingBuffer() {
        streamingFlushTimer?.invalidate()
        streamingFlushTimer = nil

        guard !streamingBuffer.isEmpty else { return }
        let data = streamingBuffer
        streamingBuffer = Data()
        playAudio(data)
    }

    /// Schedule a timer to flush the streaming buffer if no more chunks arrive soon
    private func scheduleStreamingFlush() {
        streamingFlushTimer?.invalidate()
        streamingFlushTimer = Timer.scheduledTimer(withTimeInterval: streamingFlushDelay, repeats: false) { [weak self] _ in
            self?.flushStreamingBuffer()
        }
    }

    private func finishAudioPlayback() {
        isCollectingAudio = false

        // Flush any remaining buffered audio
        flushStreamingBuffer()

        if !audioBuffer.isEmpty {
            playAudio(audioBuffer)
            audioBuffer = Data()
        }

        audioChunkCount = 0
        hasStartedPlaying = false
        hasReceivedPlaybackTurnDone = true
        notifyPlaybackFinishedIfDrained()
    }

    private func playAudio(_ audioData: Data) {
        guard isPlaybackEnabled,
              !audioData.isEmpty,
              let playerNode = playerNode,
              let playbackEngine = playbackEngine,
              let playbackAudioFormat else {
            return
        }

        // Check actual engine state — it may have auto-stopped due to idle/interruption
        if !playbackEngine.isRunning {
            startPlaybackEngine()
            guard playbackEngine.isRunning else { return }
        }
        isPlaybackEngineRunning = true

        guard let pcmBuffer = createPCMBuffer(from: audioData, format: playbackAudioFormat) else {
            return
        }

        pendingPlaybackBufferCount += 1
        playerNode.scheduleBuffer(pcmBuffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.pendingPlaybackBufferCount = max(0, self.pendingPlaybackBufferCount - 1)
                self.notifyPlaybackFinishedIfDrained()
            }
        }

        // Don't call play() if paused — buffers accumulate and will play on resume
        guard !isPlaybackPaused else { return }

        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    private func notifyPlaybackFinishedIfDrained() {
        guard hasReceivedPlaybackTurnDone, pendingPlaybackBufferCount == 0 else { return }
        hasReceivedPlaybackTurnDone = false
        DispatchQueue.main.async { [weak self] in
            self?.onSpeechStopped?()
            self?.onAudioDone?()
        }
    }

    private func createPCMBuffer(from data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = data.count / 2

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channelData = buffer.floatChannelData else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let baseAddress = bytes.baseAddress else { return }
            let int16Pointer = baseAddress.assumingMemoryBound(to: Int16.self)
            let dst = channelData.pointee
            for i in 0..<frameCount {
                dst[i] = Float(int16Pointer[i]) / 32768.0
            }
        }

        return buffer
    }
}

// MARK: - URLSessionWebSocketDelegate

extension GeminiLiveService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ [Gemini] WebSocket connection established")
        isDisconnecting = false
        DispatchQueue.main.async {
            self.configureSession()
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
        print("🔌 [Gemini] WebSocket disconnected, closeCode: \(closeCode.rawValue), reason: \(reasonString)")
    }
}
