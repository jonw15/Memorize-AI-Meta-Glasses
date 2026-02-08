/*
 * TTS Service
 * Text-to-speech service using system AVSpeechSynthesizer
 */

import AVFoundation
import Foundation

@MainActor
class TTSService: NSObject, ObservableObject {
    static let shared = TTSService()

    @Published var isSpeaking = false

    private var currentTask: Task<Void, Never>?
    private var systemSynthesizer: AVSpeechSynthesizer?

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Pre-configure audio session (call before stopping stream)
    func prepareAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
            print("🔊 [TTS] Audio session pre-configured")
        } catch {
            print("⚠️ [TTS] Audio session pre-configuration failed: \(error)")
        }
    }

    /// Speak text using system TTS
    func speak(_ text: String, apiKey: String? = nil) {
        // Cancel previous task
        currentTask?.cancel()
        stop()

        isSpeaking = true
        currentTask = Task {
            await systemTTSSpeak(text: text)
            isSpeaking = false
        }
    }

    /// Stop speaking
    func stop() {
        currentTask?.cancel()
        currentTask = nil
        systemSynthesizer?.stopSpeaking(at: .immediate)
        systemSynthesizer = nil
        isSpeaking = false
        print("🔊 [TTS] Stopped")
    }

    // MARK: - Private Methods

    /// System TTS
    private func systemTTSSpeak(text: String) async {
        print("🔊 [TTS] Speaking with system TTS")

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
            print("✅ [TTS] System TTS audio session configured")
        } catch {
            print("⚠️ [TTS] System TTS audio session error: \(error)")
        }

        // Use instance variable to keep strong reference, prevent deallocation
        systemSynthesizer = AVSpeechSynthesizer()

        guard let synthesizer = systemSynthesizer else { return }

        let utterance = AVSpeechUtterance(string: text)
        // Select system voice based on current language setting
        let voiceLanguage = "en-US"
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLanguage)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.0
        utterance.volume = 1.0
        utterance.pitchMultiplier = 1.0

        print("🔊 [TTS] System TTS speaking: \(text.prefix(30))...")
        synthesizer.speak(utterance)

        // Wait a short time for playback to start
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Wait for playback to complete
        while synthesizer.isSpeaking {
            if Task.isCancelled {
                synthesizer.stopSpeaking(at: .immediate)
                systemSynthesizer = nil
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        print("✅ [TTS] System TTS finished")
        systemSynthesizer = nil
    }
}
