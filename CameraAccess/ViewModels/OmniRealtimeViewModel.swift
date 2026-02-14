/*
 * Omni Realtime ViewModel
 * Manages real-time multimodal conversation with AI
 * Uses Google Gemini Live for real-time audio+video chat
 */

import Foundation
import SwiftUI
import AVFoundation

@MainActor
class OmniRealtimeViewModel: ObservableObject {

    // Published state
    @Published var isConnected = false
    @Published var isRecording = false
    @Published var isSpeaking = false
    @Published var currentTranscript = ""
    @Published var conversationHistory: [ConversationMessage] = []
    @Published var errorMessage: String?
    @Published var showError = false

    // Service
    private var geminiService: GeminiLiveService?
    private let apiKey: String

    // Video frame
    private var currentVideoFrame: UIImage?
    private var isImageSendingEnabled = false // Whether image sending is enabled (after first audio)
    private var imageSendTimer: Timer?
    @Published var imageSendInterval: TimeInterval = 1.0
    private var lastUserTranscript = ""
    private var lastAssistantTranscript = ""

    init(apiKey: String) {
        self.apiKey = apiKey
        self.geminiService = GeminiLiveService(apiKey: apiKey)
        setupCallbacks()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        guard let geminiService = geminiService else { return }

        geminiService.onConnected = { [weak self] in
            Task { @MainActor in
                self?.isConnected = true
            }
        }

        geminiService.onFirstAudioSent = { [weak self] in
            Task { @MainActor in
                print("✅ [LiveAI-VM] Received first audio send callback, starting periodic image sending")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.isImageSendingEnabled = true
                    self?.startImageSendTimer()
                    print("📸 [LiveAI-VM] Periodic image sending started")
                }
            }
        }

        geminiService.onTranscriptDelta = { [weak self] (delta: String) in
            Task { @MainActor in
                guard let self else { return }
                let cleaned = delta.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return }
                print("📝 [LiveAI-VM] AI speech fragment: \(cleaned)")
                if self.currentTranscript.isEmpty {
                    self.currentTranscript = cleaned
                } else if cleaned.hasPrefix(self.currentTranscript) {
                    // Some providers send a full running transcript on each delta.
                    self.currentTranscript = cleaned
                } else {
                    // Others send only incremental chunks.
                    self.currentTranscript += cleaned
                }
            }
        }

        geminiService.onUserTranscript = { [weak self] (userText: String) in
            Task { @MainActor in
                guard let self = self else { return }
                let cleaned = userText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return }
                guard cleaned != self.lastUserTranscript else { return }
                self.lastUserTranscript = cleaned
                print("💬 [LiveAI-VM] Saving user speech: \(cleaned)")
                self.conversationHistory.append(
                    ConversationMessage(role: .user, content: cleaned)
                )
            }
        }

        geminiService.onTranscriptDone = { [weak self] (fullText: String) in
            Task { @MainActor in
                guard let self = self else { return }
                let textToSave = fullText.isEmpty ? self.currentTranscript : fullText
                let cleaned = textToSave.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    print("⚠️ [LiveAI-VM] AI response is empty, skipping save")
                    return
                }
                guard cleaned != self.lastAssistantTranscript else {
                    self.currentTranscript = ""
                    return
                }
                self.lastAssistantTranscript = cleaned
                print("💬 [LiveAI-VM] Saving AI response: \(cleaned)")
                self.conversationHistory.append(
                    ConversationMessage(role: .assistant, content: cleaned)
                )
                self.currentTranscript = ""
            }
        }

        geminiService.onAudioDone = { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = false
            }
        }

        geminiService.onError = { [weak self] (error: String) in
            Task { @MainActor in
                self?.errorMessage = error
                self?.showError = true
            }
        }
    }

    // MARK: - Connection

    func connect() {
        geminiService?.connect()
    }

    func disconnect() {
        // Save conversation before disconnecting
        saveConversation()

        stopImageSendTimer()
        stopRecording()
        geminiService?.disconnect()

        isConnected = false
        isImageSendingEnabled = false
    }

    private func saveConversation() {
        // Only save if there's meaningful conversation
        guard !conversationHistory.isEmpty else {
            print("💬 [LiveAI] No conversation content, skipping save")
            return
        }

        let record = ConversationRecord(
            messages: conversationHistory,
            aiModel: APIProviderManager.liveAIDefaultModel,
            language: "en-US"
        )

        ConversationStorage.shared.saveConversation(record)
        print("💾 [LiveAI] Conversation saved: \(conversationHistory.count) messages")
    }

    // MARK: - Recording

    func startRecording() {
        guard isConnected else {
            print("⚠️ [LiveAI] Not connected, cannot start recording")
            errorMessage = "Please connect to server first"
            showError = true
            return
        }

        print("🎤 [LiveAI] Start recording (voice-triggered mode) - Provider: Google Gemini")
        geminiService?.startRecording()
        isRecording = true
    }

    func stopRecording() {
        print("🛑 [LiveAI] Stop recording")
        stopImageSendTimer()
        geminiService?.stopRecording()
        isRecording = false
    }

    // MARK: - Video Frames

    func updateVideoFrame(_ frame: UIImage) {
        currentVideoFrame = frame
    }

    func setImageSendInterval(_ interval: TimeInterval) {
        imageSendInterval = interval
        if isImageSendingEnabled {
            startImageSendTimer()
        }
    }

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

    // MARK: - Cleanup

    func dismissError() {
        showError = false
    }

    nonisolated deinit {
        Task { @MainActor [weak geminiService] in
            geminiService?.disconnect()
        }
    }
}

// MARK: - Conversation Message

struct ConversationMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()

    enum MessageRole {
        case user
        case assistant
    }
}
