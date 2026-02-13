/*
 * Live Translate WebSocket Service
 * Real-time translation service using Google Gemini Live API
 */

import Foundation
import UIKit
import AVFoundation

// MARK: - Service Class

class LiveTranslateService: NSObject {

    // WebSocket
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // Configuration
    private let apiKey: String
    private let model = "gemini-2.5-flash-native-audio-preview-12-2025"
    private let baseURL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"

    // Audio Engine (for recording)
    private var audioEngine: AVAudioEngine?

    // Audio Playback Engine (separate engine for playback)
    private var playbackEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let playbackFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)

    // Audio buffer management
    private var audioBuffer = Data()
    private var isCollectingAudio = false
    private var audioChunkCount = 0
    private let minChunksBeforePlay = 2
    private var hasStartedPlaying = false
    private var isPlaybackEngineRunning = false

    // Audio resampling
    private var audioConverter: AVAudioConverter?
    private let targetSampleRate: Double = 16000  // Gemini expects 16kHz
    private let recordTargetFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)

    // Translation settings
    private var sourceLanguage: TranslateLanguage = .en
    private var targetLanguage: TranslateLanguage = .zh
    private var voice: TranslateVoice = .cherry
    private var audioOutputEnabled = true

    // Session state
    private var isSessionConfigured = false
    private var currentTranslationText = ""

    // Callbacks
    var onConnected: (() -> Void)?
    var onTranslationText: ((String) -> Void)?    // Translation result text
    var onTranslationDelta: ((String) -> Void)?   // Incremental translation text
    var onAudioDelta: ((Data) -> Void)?
    var onAudioDone: (() -> Void)?
    var onError: ((String) -> Void)?

    // State
    private var isRecording = false

    // Image sending
    private var lastImageSendTime: Date?
    private let imageInterval: TimeInterval = 0.5  // Send at most one image every 0.5 seconds

    init(apiKey: String) {
        self.apiKey = apiKey
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
              let playerNode = playerNode,
              let playbackFormat = playbackFormat else {
            print("❌ [Translate] Failed to initialize playback engine")
            return
        }

        playbackEngine.attach(playerNode)
        playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: playbackFormat)
        playbackEngine.prepare()

        print("✅ [Translate] Playback engine initialized: Float32 @ 24kHz")
    }

    private func startPlaybackEngine() {
        guard let playbackEngine = playbackEngine, !isPlaybackEngineRunning else { return }

        do {
            try playbackEngine.start()
            isPlaybackEngineRunning = true
            print("▶️ [Translate] Playback engine started")
        } catch {
            print("❌ [Translate] Failed to start playback engine: \(error)")
        }
    }

    private func stopPlaybackEngine() {
        guard let playbackEngine = playbackEngine, isPlaybackEngineRunning else { return }

        playerNode?.stop()
        playerNode?.reset()
        playbackEngine.stop()
        isPlaybackEngineRunning = false
        print("⏹️ [Translate] Playback engine stopped")
    }

    // MARK: - WebSocket Connection

    func connect() {
        let urlString = "\(baseURL)?key=\(apiKey)"
        print("🔌 [Translate] Preparing to connect WebSocket")

        guard let url = URL(string: urlString) else {
            print("❌ [Translate] Invalid URL")
            onError?("Invalid URL")
            return
        }

        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())

        webSocket = urlSession?.webSocketTask(with: url)
        webSocket?.resume()

        print("🔌 [Translate] WebSocket task started")
        receiveMessage()
    }

    func disconnect() {
        print("🔌 [Translate] Disconnecting WebSocket")
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        stopRecording()
        stopPlaybackEngine()
        isSessionConfigured = false
    }

    // MARK: - Configuration

    func updateSettings(
        sourceLanguage: TranslateLanguage,
        targetLanguage: TranslateLanguage,
        voice: TranslateVoice,
        audioEnabled: Bool
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.voice = voice
        self.audioOutputEnabled = audioEnabled

        // If already connected, reconfigure session
        if isSessionConfigured {
            // Disconnect and reconnect with new settings
            // (Gemini setup is sent once at connection start)
            print("⚠️ [Translate] Settings updated, reconnect needed for changes to take effect")
        }
    }

    private func configureSession() {
        guard !isSessionConfigured else { return }

        let sourceDisplayName = sourceLanguage.displayName
        let targetDisplayName = targetLanguage.displayName

        let systemPrompt = """
You are a real-time translator. Listen to the user's speech and translate it.
Source language: \(sourceDisplayName) (\(sourceLanguage.rawValue))
Target language: \(targetDisplayName) (\(targetLanguage.rawValue))

Rules:
- Only output the translation, nothing else
- Maintain the tone and style of the original speech
- If the speech is unclear, provide the best translation possible
- Do not add explanations or notes
- Respond in the target language only
"""

        // Determine response modalities
        var responseModalities: [String] = ["TEXT"]
        if audioOutputEnabled {
            responseModalities = ["AUDIO"]
        }

        // Gemini Live API setup message
        let setupMessage: [String: Any] = [
            "setup": [
                "model": model.hasPrefix("models/") ? model : "models/\(model)",
                "generation_config": [
                    "response_modalities": responseModalities,
                    "speech_config": [
                        "voice_config": [
                            "prebuilt_voice_config": [
                                "voice_name": "Aoede"
                            ]
                        ]
                    ]
                ],
                "system_instruction": [
                    "parts": [
                        ["text": systemPrompt]
                    ]
                ]
            ]
        ]

        sendJSON(setupMessage)
        print("⚙️ [Translate] Sending session configuration: \(sourceLanguage.rawValue) → \(targetLanguage.rawValue)")
    }

    // MARK: - Audio Recording

    func startRecording(usePhoneMic: Bool = false) {
        guard !isRecording else { return }

        do {
            print("🎤 [Translate] Starting recording, using \(usePhoneMic ? "iPhone" : "Bluetooth") microphone")

            if let engine = audioEngine, engine.isRunning {
                engine.stop()
                engine.inputNode.removeTap(onBus: 0)
            }

            let audioSession = AVAudioSession.sharedInstance()

            if usePhoneMic {
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.defaultToSpeaker]
                )
                print("🎙️ [Translate] Using iPhone microphone (translate others)")
            } else {
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.allowBluetooth, .defaultToSpeaker]
                )
                print("🎙️ [Translate] Using Bluetooth microphone (translate self)")
            }
            try audioSession.setActive(true)

            // Print current audio input device
            if let inputRoute = audioSession.currentRoute.inputs.first {
                print("🎙️ [Translate] Current input device: \(inputRoute.portName) (\(inputRoute.portType.rawValue))")
            }

            guard let engine = audioEngine else {
                print("❌ [Translate] Audio engine not initialized")
                return
            }

            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            // Setup audio converter for resampling
            if let recordTargetFormat {
                audioConverter = AVAudioConverter(from: inputFormat, to: recordTargetFormat)
            }

            print("🎵 [Translate] Input format: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) channels")
            print("🎵 [Translate] Target format: \(targetSampleRate) Hz (will auto-resample)")

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer, inputFormat: inputFormat)
            }

            engine.prepare()
            try engine.start()

            isRecording = true
            print("✅ [Translate] Recording started")

        } catch {
            print("❌ [Translate] Failed to start recording: \(error.localizedDescription)")
            onError?("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        print("🛑 [Translate] Stopping recording")
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        isRecording = false
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) {
        guard let audioConverter, let recordTargetFormat else { return }

        let ratio = recordTargetFormat.sampleRate / inputFormat.sampleRate
        let targetFrameCapacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))

        guard let converted = AVAudioPCMBuffer(pcmFormat: recordTargetFormat, frameCapacity: max(1, targetFrameCapacity)) else {
            return
        }

        var hasProvidedInput = false
        var error: NSError?

        let status = audioConverter.convert(to: converted, error: &error) { _, outStatus in
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

        // Float32 → PCM16
        var int16Data = [Int16](repeating: 0, count: frameLength)
        for i in 0..<frameLength {
            let sample = channel[i]
            let clampedSample = max(-1.0, min(1.0, sample))
            int16Data[i] = Int16(clampedSample * 32767.0)
        }

        let data = Data(bytes: int16Data, count: frameLength * MemoryLayout<Int16>.size)
        let base64Audio = data.base64EncodedString()

        sendRealtimeInput(audioData: base64Audio)
    }

    // MARK: - Image Sending

    func sendImageFrame(_ image: UIImage) {
        // Rate limit: at most one image every 0.5 seconds
        let now = Date()
        if let lastTime = lastImageSendTime, now.timeIntervalSince(lastTime) < imageInterval {
            return
        }
        lastImageSendTime = now

        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            print("❌ [Translate] Failed to compress image")
            return
        }

        // Limit image size to 500KB
        guard imageData.count <= 500 * 1024 else {
            print("⚠️ [Translate] Image too large, skipping")
            return
        }

        let base64Image = imageData.base64EncodedString()
        print("📸 [Translate] Sending image: \(imageData.count) bytes")

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

    // MARK: - Send Events

    private func sendJSON(_ json: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [Translate] Failed to serialize JSON")
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(message) { error in
            if let error = error {
                print("❌ [Translate] Failed to send: \(error.localizedDescription)")
                self.onError?("Send error: \(error.localizedDescription)")
            }
        }
    }

    private func sendRealtimeInput(audioData: String) {
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

    // MARK: - Receive Messages

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage()

            case .failure(let error):
                print("❌ [Translate] Failed to receive message: \(error.localizedDescription)")
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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        DispatchQueue.main.async {
            // Handle setup complete
            if json["setupComplete"] != nil {
                print("✅ [Translate] Session configuration complete")
                self.isSessionConfigured = true
                self.onConnected?()
                return
            }

            // Handle server content (audio/text responses)
            if let serverContent = json["serverContent"] as? [String: Any] {
                self.handleServerContent(serverContent)
                return
            }

            // Handle errors
            if let error = json["error"] as? [String: Any] {
                let message = error["message"] as? String ?? "Unknown error"
                print("❌ [Translate] Server error: \(message)")
                self.onError?(message)
                return
            }
        }
    }

    private func handleServerContent(_ content: [String: Any]) {
        // Check for model turn
        if let modelTurn = content["modelTurn"] as? [String: Any],
           let parts = modelTurn["parts"] as? [[String: Any]] {

            for part in parts {
                // Handle text response (translation text)
                if let text = part["text"] as? String {
                    print("💬 [Translate] Translation: \(text)")
                    currentTranslationText += text
                    onTranslationDelta?(text)
                }

                // Handle inline audio data
                if let inlineData = part["inlineData"] as? [String: Any],
                   let mimeType = inlineData["mimeType"] as? String,
                   mimeType.contains("audio"),
                   let base64Audio = inlineData["data"] as? String,
                   let audioData = Data(base64Encoded: base64Audio) {

                    onAudioDelta?(audioData)
                    handleAudioChunk(audioData)
                }
            }
        }

        // Check if turn is complete
        if let turnComplete = content["turnComplete"] as? Bool, turnComplete {
            print("✅ [Translate] Translation complete")
            finishAudioPlayback()

            // Emit full translation text
            if !currentTranslationText.isEmpty {
                onTranslationText?(currentTranslationText)
                currentTranslationText = ""
            }
        }

        // Check for interrupted flag
        if let interrupted = content["interrupted"] as? Bool, interrupted {
            print("⚠️ [Translate] Response interrupted")
            stopPlaybackEngine()
            setupPlaybackEngine()
            currentTranslationText = ""
        }

        // Handle output transcription (AI speech text)
        if let outputTranscription = content["outputTranscription"] as? [String: Any],
           let text = outputTranscription["text"] as? String {
            print("💬 [Translate] AI text: \(text)")
            onTranslationDelta?(text)
            currentTranslationText += text
        }
    }

    // MARK: - Audio Playback

    private func handleAudioChunk(_ audioData: Data) {
        if !isCollectingAudio {
            isCollectingAudio = true
            audioBuffer = Data()
            audioChunkCount = 0
            hasStartedPlaying = false

            if isPlaybackEngineRunning {
                stopPlaybackEngine()
                setupPlaybackEngine()
                startPlaybackEngine()
                playerNode?.play()
            }
        }

        audioChunkCount += 1

        if !hasStartedPlaying {
            audioBuffer.append(audioData)
            if audioChunkCount >= minChunksBeforePlay {
                hasStartedPlaying = true
                playAudio(audioBuffer)
                audioBuffer = Data()
            }
        } else {
            playAudio(audioData)
        }
    }

    private func finishAudioPlayback() {
        isCollectingAudio = false

        if !audioBuffer.isEmpty {
            playAudio(audioBuffer)
            audioBuffer = Data()
        }

        audioChunkCount = 0
        hasStartedPlaying = false
        onAudioDone?()
    }

    private func playAudio(_ audioData: Data) {
        guard let playerNode = playerNode,
              let playbackFormat = playbackFormat else { return }

        if !isPlaybackEngineRunning {
            startPlaybackEngine()
            playerNode.play()
        } else if !playerNode.isPlaying {
            playerNode.play()
        }

        guard let pcmBuffer = createPCMBuffer(from: audioData, format: playbackFormat) else { return }
        playerNode.scheduleBuffer(pcmBuffer)
    }

    private func createPCMBuffer(from data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = data.count / 2
        guard frameCount > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channelData = buffer.floatChannelData else { return nil }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        // PCM16 → Float32
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let baseAddress = bytes.baseAddress else { return }
            let int16Pointer = baseAddress.assumingMemoryBound(to: Int16.self)
            let floatData = channelData[0]
            for i in 0..<frameCount {
                floatData[i] = Float(int16Pointer[i]) / 32768.0
            }
        }

        return buffer
    }
}

// MARK: - URLSessionWebSocketDelegate

extension LiveTranslateService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ [Translate] WebSocket connection established")
        DispatchQueue.main.async {
            self.configureSession()
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
        print("🔌 [Translate] WebSocket disconnected, closeCode: \(closeCode.rawValue), reason: \(reasonString)")
    }
}
