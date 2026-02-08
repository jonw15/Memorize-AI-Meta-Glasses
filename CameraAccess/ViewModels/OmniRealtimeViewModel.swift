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
                print("✅ [LiveAI-VM] Received first audio send callback, enabling image sending")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.isImageSendingEnabled = true
                    print("📸 [LiveAI-VM] Image sending enabled (voice-triggered mode)")
                }
            }
        }

        geminiService.onSpeechStarted = { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = true

                if let strongSelf = self,
                   strongSelf.isImageSendingEnabled,
                   let frame = strongSelf.currentVideoFrame {
                    print("🎤📸 [LiveAI-VM] User speech detected, sending current video frame")
                    strongSelf.geminiService?.sendImageInput(frame)
                }
            }
        }

        geminiService.onSpeechStopped = { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = false
            }
        }

        geminiService.onTranscriptDelta = { [weak self] (delta: String) in
            Task { @MainActor in
                print("📝 [LiveAI-VM] AI response fragment: \(delta)")
                self?.currentTranscript += delta
            }
        }

        geminiService.onUserTranscript = { [weak self] (userText: String) in
            Task { @MainActor in
                guard let self = self else { return }
                print("💬 [LiveAI-VM] Saving user speech: \(userText)")
                self.conversationHistory.append(
                    ConversationMessage(role: .user, content: userText)
                )
            }
        }

        geminiService.onTranscriptDone = { [weak self] (fullText: String) in
            Task { @MainActor in
                guard let self = self else { return }
                let textToSave = fullText.isEmpty ? self.currentTranscript : fullText
                guard !textToSave.isEmpty else {
                    print("⚠️ [LiveAI-VM] AI response is empty, skipping save")
                    return
                }
                print("💬 [LiveAI-VM] Saving AI response: \(textToSave)")
                self.conversationHistory.append(
                    ConversationMessage(role: .assistant, content: textToSave)
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
            language: "zh-CN" // TODO: Get from settings
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
        geminiService?.stopRecording()
        isRecording = false
    }

    // MARK: - Video Frames

    func updateVideoFrame(_ frame: UIImage) {
        currentVideoFrame = frame
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
