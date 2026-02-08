/*
 * Qwen-Omni-Realtime WebSocket Service
 * Provides real-time audio and video chat with AI
 */

import Foundation
import UIKit
import AVFoundation

// MARK: - WebSocket Events

enum OmniClientEvent: String {
    case sessionUpdate = "session.update"
    case inputAudioBufferAppend = "input_audio_buffer.append"
    case inputAudioBufferCommit = "input_audio_buffer.commit"
    case inputImageBufferAppend = "input_image_buffer.append"
    case responseCreate = "response.create"
}

enum OmniServerEvent: String {
    case sessionCreated = "session.created"
    case sessionUpdated = "session.updated"
    case inputAudioBufferSpeechStarted = "input_audio_buffer.speech_started"
    case inputAudioBufferSpeechStopped = "input_audio_buffer.speech_stopped"
    case inputAudioBufferCommitted = "input_audio_buffer.committed"
    case responseCreated = "response.created"
    case responseAudioTranscriptDelta = "response.audio_transcript.delta"
    case responseAudioTranscriptDone = "response.audio_transcript.done"
    case responseAudioDelta = "response.audio.delta"
    case responseAudioDone = "response.audio.done"
    case responseDone = "response.done"
    case conversationItemCreated = "conversation.item.created"
    case conversationItemInputAudioTranscriptionCompleted = "conversation.item.input_audio_transcription.completed"
    case error = "error"
}

// MARK: - Service Class

class OmniRealtimeService: NSObject {

    // WebSocket
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // Configuration
    private let apiKey: String
    private let model = "qwen3-omni-flash-realtime"
    // Dynamically get WebSocket URL based on user's region setting (Beijing/Singapore)
    private var baseURL: String {
        return APIProviderManager.staticLiveAIWebsocketURL
    }

    // Audio Engine (for recording)
    private var audioEngine: AVAudioEngine?

    // Audio Playback Engine (separate engine for playback)
    private var playbackEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    // Use Float32 standard format, compatible with iOS 18
    private let playbackFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)

    // Audio buffer management
    private var audioBuffer = Data()
    private var isCollectingAudio = false
    private var audioChunkCount = 0
    private let minChunksBeforePlay = 2 // Start playback after receiving the first 2 chunks
    private var hasStartedPlaying = false
    private var isPlaybackEngineRunning = false

    // Callbacks
    var onTranscriptDelta: ((String) -> Void)?
    var onTranscriptDone: ((String) -> Void)?
    var onUserTranscript: ((String) -> Void)? // User speech recognition result
    var onAudioDelta: ((Data) -> Void)?
    var onAudioDone: (() -> Void)?
    var onSpeechStarted: (() -> Void)?
    var onSpeechStopped: (() -> Void)?
    var onError: ((String) -> Void)?
    var onConnected: (() -> Void)?
    var onFirstAudioSent: (() -> Void)?

    // State
    private var isRecording = false
    private var hasAudioBeenSent = false
    private var eventIdCounter = 0

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
        setupAudioEngine()
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        // Recording engine
        audioEngine = AVAudioEngine()

        // Playback engine (separate from recording)
        setupPlaybackEngine()
    }

    private func setupPlaybackEngine() {
        playbackEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()

        guard let playbackEngine = playbackEngine,
              let playerNode = playerNode,
              let playbackFormat = playbackFormat else {
            print("❌ [Omni] Failed to initialize playback engine")
            return
        }

        // Attach player node
        playbackEngine.attach(playerNode)

        // Connect player node to output with explicit format
        playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: playbackFormat)
        playbackEngine.prepare()

        print("✅ [Omni] Playback engine initialized: Float32 @ 24kHz")
    }

    private func startPlaybackEngine() {
        guard let playbackEngine = playbackEngine, !isPlaybackEngineRunning else { return }

        do {
            try playbackEngine.start()
            isPlaybackEngineRunning = true
            print("▶️ [Omni] Playback engine started")
        } catch {
            print("❌ [Omni] Failed to start playback engine: \(error)")
        }
    }

    private func stopPlaybackEngine() {
        guard let playbackEngine = playbackEngine, isPlaybackEngineRunning else { return }

        // Important: reset playerNode first to clear all scheduled but unplayed buffers
        playerNode?.stop()
        playerNode?.reset()  // Clear all buffers in the queue
        playbackEngine.stop()
        isPlaybackEngineRunning = false
        print("⏹️ [Omni] Playback engine stopped and queue cleared")
    }

    // MARK: - WebSocket Connection

    func connect() {
        let urlString = "\(baseURL)?model=\(model)"
        print("🔌 [Omni] Preparing to connect WebSocket: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("❌ [Omni] Invalid URL")
            onError?("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())

        webSocket = urlSession?.webSocketTask(with: request)
        webSocket?.resume()

        print("🔌 [Omni] WebSocket task started")
        receiveMessage()

        // Wait a bit then send session configuration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("⚙️ [Omni] Preparing to configure session")
            self.configureSession()
        }
    }

    func disconnect() {
        print("🔌 [Omni] Disconnecting WebSocket")
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        stopRecording()
        stopPlaybackEngine()
    }

    // MARK: - Session Configuration

    private func configureSession() {
        // Get voice and prompt based on current language settings
        let voice = LanguageManager.staticTtsVoice
        let instructions = LiveAIModeManager.staticSystemPrompt

        let sessionConfig: [String: Any] = [
            "event_id": generateEventId(),
            "type": OmniClientEvent.sessionUpdate.rawValue,
            "session": [
                "modalities": ["text", "audio"],
                "voice": voice,
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm24",
                "smooth_output": true,
                "instructions": instructions,
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "silence_duration_ms": 800
                ]
            ]
        ]

        sendEvent(sessionConfig)
    }

    // MARK: - Audio Recording

    func startRecording() {
        guard !isRecording else {
            return
        }

        do {
            print("🎤 [Omni] Starting recording")

            // Stop engine if already running and remove any existing taps
            if let engine = audioEngine, engine.isRunning {
                engine.stop()
                engine.inputNode.removeTap(onBus: 0)
            }

            let audioSession = AVAudioSession.sharedInstance()

            // Allow Bluetooth to use the glasses' microphone
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)

            guard let engine = audioEngine else {
                print("❌ [Omni] Audio engine not initialized")
                return
            }

            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            // Convert to PCM16 24kHz mono
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer)
            }

            engine.prepare()
            try engine.start()

            isRecording = true
            print("✅ [Omni] Recording started")

        } catch {
            print("❌ [Omni] Failed to start recording: \(error.localizedDescription)")
            onError?("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard isRecording else {
            return
        }

        print("🛑 [Omni] Stopping recording")
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        isRecording = false
        hasAudioBeenSent = false
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Convert Float32 audio to PCM16 format
        guard let floatChannelData = buffer.floatChannelData else {
            return
        }

        let frameLength = Int(buffer.frameLength)
        let channel = floatChannelData.pointee

        // Convert Float32 (-1.0 to 1.0) to Int16 (-32768 to 32767)
        var int16Data = [Int16](repeating: 0, count: frameLength)
        for i in 0..<frameLength {
            let sample = channel[i]
            let clampedSample = max(-1.0, min(1.0, sample))
            int16Data[i] = Int16(clampedSample * 32767.0)
        }

        let data = Data(bytes: int16Data, count: frameLength * MemoryLayout<Int16>.size)
        let base64Audio = data.base64EncodedString()

        sendAudioAppend(base64Audio)

        // Notify that the first audio has been sent
        if !hasAudioBeenSent {
            hasAudioBeenSent = true
            print("✅ [Omni] First audio sent, voice trigger mode enabled")
            DispatchQueue.main.async { [weak self] in
                self?.onFirstAudioSent?()
            }
        }
    }

    // MARK: - Send Events

    private func sendEvent(_ event: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: event),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [Omni] Failed to serialize event")
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(message) { error in
            if let error = error {
                print("❌ [Omni] Failed to send event: \(error.localizedDescription)")
                self.onError?("Send error: \(error.localizedDescription)")
            }
        }
    }

    func sendAudioAppend(_ base64Audio: String) {
        let event: [String: Any] = [
            "event_id": generateEventId(),
            "type": OmniClientEvent.inputAudioBufferAppend.rawValue,
            "audio": base64Audio
        ]
        sendEvent(event)
    }

    func sendImageAppend(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            print("❌ [Omni] Failed to compress image")
            return
        }
        let base64Image = imageData.base64EncodedString()

        print("📸 [Omni] Sending image: \(imageData.count) bytes")

        let event: [String: Any] = [
            "event_id": generateEventId(),
            "type": OmniClientEvent.inputImageBufferAppend.rawValue,
            "image": base64Image
        ]
        sendEvent(event)
    }

    func commitAudioBuffer() {
        let event: [String: Any] = [
            "event_id": generateEventId(),
            "type": OmniClientEvent.inputAudioBufferCommit.rawValue
        ]
        sendEvent(event)
    }

    // MARK: - Receive Messages

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue receiving

            case .failure(let error):
                print("❌ [Omni] Failed to receive message: \(error.localizedDescription)")
                self?.onError?("Receive error: \(error.localizedDescription)")
            }
        }
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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        DispatchQueue.main.async {
            switch type {
            case OmniServerEvent.sessionCreated.rawValue,
                 OmniServerEvent.sessionUpdated.rawValue:
                print("✅ [Omni] Session established")
                self.onConnected?()

            case OmniServerEvent.inputAudioBufferSpeechStarted.rawValue:
                print("🎤 [Omni] Speech start detected")
                self.onSpeechStarted?()

            case OmniServerEvent.inputAudioBufferSpeechStopped.rawValue:
                print("🛑 [Omni] Speech stop detected")
                self.onSpeechStopped?()

            case OmniServerEvent.responseAudioTranscriptDelta.rawValue:
                if let delta = json["delta"] as? String {
                    print("💬 [Omni] AI response chunk: \(delta)")
                    self.onTranscriptDelta?(delta)
                }

            case OmniServerEvent.responseAudioTranscriptDone.rawValue:
                let text = json["text"] as? String ?? ""
                if text.isEmpty {
                    print("⚠️ [Omni] AI response done but done event has no text field (using accumulated delta)")
                } else {
                    print("✅ [Omni] AI full response: \(text)")
                }
                // Always call the callback, even if text is empty, so ViewModel uses accumulated chunks
                self.onTranscriptDone?(text)

            case OmniServerEvent.responseAudioDelta.rawValue:
                if let base64Audio = json["delta"] as? String,
                   let audioData = Data(base64Encoded: base64Audio) {
                    self.onAudioDelta?(audioData)

                    // Buffer audio chunks
                    if !self.isCollectingAudio {
                        self.isCollectingAudio = true
                        self.audioBuffer = Data()
                        self.audioChunkCount = 0
                        self.hasStartedPlaying = false

                        // Clear old buffers that may remain in the playerNode queue
                        if self.isPlaybackEngineRunning {
                            // Important: reset disconnects playerNode, requires full reinitialization
                            self.stopPlaybackEngine()
                            self.setupPlaybackEngine()
                            self.startPlaybackEngine()
                            self.playerNode?.play()
                            print("🔄 [Omni] Reinitialized playback engine")
                        }
                    }

                    self.audioChunkCount += 1

                    // Streaming playback strategy: start streaming after collecting a few chunks
                    if !self.hasStartedPlaying {
                        // Before first playback: collect first
                        self.audioBuffer.append(audioData)

                        if self.audioChunkCount >= self.minChunksBeforePlay {
                            // Collected enough chunks, start playback
                            self.hasStartedPlaying = true
                            self.playAudio(self.audioBuffer)
                            self.audioBuffer = Data()
                        }
                    } else {
                        // Already playing: schedule each chunk directly, AVAudioPlayerNode queues automatically
                        self.playAudio(audioData)
                    }
                }

            case OmniServerEvent.responseAudioDone.rawValue:
                self.isCollectingAudio = false

                // Play remaining buffered audio (if any)
                if !self.audioBuffer.isEmpty {
                    self.playAudio(self.audioBuffer)
                    self.audioBuffer = Data()
                }

                self.audioChunkCount = 0
                self.hasStartedPlaying = false
                self.onAudioDone?()

            case OmniServerEvent.conversationItemInputAudioTranscriptionCompleted.rawValue:
                // User speech recognition completed
                if let transcript = json["transcript"] as? String {
                    print("👤 [Omni] User said: \(transcript)")
                    self.onUserTranscript?(transcript)
                }

            case OmniServerEvent.conversationItemCreated.rawValue:
                // May contain other types of conversation items
                break

            case OmniServerEvent.error.rawValue:
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("❌ [Omni] Server error: \(message)")
                    self.onError?(message)
                }

            default:
                break
            }
        }
    }

    // MARK: - Audio Playback (AVAudioEngine + AVAudioPlayerNode)

    private func playAudio(_ audioData: Data) {
        guard let playerNode = playerNode,
              let playbackFormat = playbackFormat else {
            return
        }

        // Start playback engine if not running
        if !isPlaybackEngineRunning {
            startPlaybackEngine()
            playerNode.play()
        } else {
            // Ensure playerNode is running
            if !playerNode.isPlaying {
                playerNode.play()
            }
        }

        // Convert PCM16 Data to Float32 AVAudioPCMBuffer
        guard let pcmBuffer = createPCMBuffer(from: audioData, format: playbackFormat) else {
            return
        }

        // Schedule buffer for playback
        playerNode.scheduleBuffer(pcmBuffer)
    }

    private func createPCMBuffer(from data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        // Server sends PCM16 format, 2 bytes per frame
        let frameCount = data.count / 2
        guard frameCount > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channelData = buffer.floatChannelData else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        // Convert PCM16 to Float32 (compatible with iOS 18+)
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let baseAddress = bytes.baseAddress else { return }
            let int16Pointer = baseAddress.assumingMemoryBound(to: Int16.self)
            let floatData = channelData[0]
            for i in 0..<frameCount {
                // Int16 range -32768 to 32767, convert to -1.0 to 1.0
                floatData[i] = Float(int16Pointer[i]) / 32768.0
            }
        }

        return buffer
    }

    // MARK: - Helpers

    private func generateEventId() -> String {
        eventIdCounter += 1
        return "event_\(eventIdCounter)_\(UUID().uuidString.prefix(8))"
    }
}

// MARK: - URLSessionWebSocketDelegate

extension OmniRealtimeService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ [Omni] WebSocket connection established, protocol: \(`protocol` ?? "none")")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
        print("🔌 [Omni] WebSocket disconnected, closeCode: \(closeCode.rawValue), reason: \(reasonString)")
    }
}
