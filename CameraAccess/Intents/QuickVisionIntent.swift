/*
 * Quick Vision Intent
 * App Intent - Supports Siri and Shortcuts to trigger Quick Vision
 *
 * Supported modes:
 * - Default mode: General image description
 * - Health Vision: Analyze food healthiness
 * - Blind mode: Describe environment for visually impaired users
 * - Reading mode: Recognize and read aloud text
 * - Translation mode: Recognize and translate text
 * - Encyclopedia mode: Encyclopedia knowledge introduction
 * - Custom: Use a custom prompt
 */

import AppIntents
import UIKit
import SwiftUI

// MARK: - Quick Vision Intent (Default Mode)

@available(iOS 16.0, *)
struct QuickVisionIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Vision"
    static var description = IntentDescription("Take a photo with Ray-Ban Meta glasses and recognize image content")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Custom Prompt")
    var customPrompt: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.standard, customPrompt: customPrompt)
        return formatResult(manager)
    }
}

// MARK: - Health Mode Intent

@available(iOS 16.0, *)
struct QuickVisionHealthIntent: AppIntent {
    static var title: LocalizedStringResource = "Health Vision"
    static var description = IntentDescription("Analyze the healthiness of food/beverages")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.health)
        return formatResult(manager)
    }
}

// MARK: - Blind Mode Intent

@available(iOS 16.0, *)
struct QuickVisionBlindIntent: AppIntent {
    static var title: LocalizedStringResource = "Describe Environment"
    static var description = IntentDescription("Describe the surrounding environment in detail for visually impaired users")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.blind)
        return formatResult(manager)
    }
}

// MARK: - Reading Mode Intent

@available(iOS 16.0, *)
struct QuickVisionReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Text"
    static var description = IntentDescription("Recognize and read aloud text in images")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.reading)
        return formatResult(manager)
    }
}

// MARK: - Translation Mode Intent

@available(iOS 16.0, *)
struct QuickVisionTranslateIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Text"
    static var description = IntentDescription("Recognize and translate foreign text in images")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.translate)
        return formatResult(manager)
    }
}

// MARK: - Encyclopedia Mode Intent

@available(iOS 16.0, *)
struct QuickVisionEncyclopediaIntent: AppIntent {
    static var title: LocalizedStringResource = "Encyclopedia"
    static var description = IntentDescription("Recognize objects and provide encyclopedia knowledge")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.encyclopedia)
        return formatResult(manager)
    }
}

// MARK: - Helper Function

@available(iOS 16.0, *)
@MainActor
private func formatResult(_ manager: QuickVisionManager) -> some IntentResult & ProvidesDialog {
    if let result = manager.lastResult {
        return .result(dialog: "Recognition complete: \(result)")
    } else if let error = manager.errorMessage {
        return .result(dialog: "Recognition failed: \(error)")
    } else {
        return .result(dialog: "Recognition complete")
    }
}

// MARK: - App Shortcuts Provider

@available(iOS 16.0, *)
struct TurboMetaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Quick Vision
        AppShortcut(
            intent: QuickVisionIntent(),
            phrases: [
                "Use \(.applicationName) to recognize",
                "Use \(.applicationName) to see what this is",
                "\(.applicationName) Quick Vision",
                "\(.applicationName) photo recognition"
            ],
            shortTitle: "Quick Vision",
            systemImageName: "eye.circle.fill"
        )

        // Health Vision
        AppShortcut(
            intent: QuickVisionHealthIntent(),
            phrases: [
                "Use \(.applicationName) to analyze health",
                "\(.applicationName) Health Vision",
                "\(.applicationName) is this food healthy"
            ],
            shortTitle: "Health Vision",
            systemImageName: "heart.circle.fill"
        )

        // Blind mode
        AppShortcut(
            intent: QuickVisionBlindIntent(),
            phrases: [
                "Use \(.applicationName) to describe environment",
                "\(.applicationName) what is around me",
                "\(.applicationName) help me see ahead"
            ],
            shortTitle: "Describe Environment",
            systemImageName: "figure.walk.circle.fill"
        )

        // Reading mode
        AppShortcut(
            intent: QuickVisionReadingIntent(),
            phrases: [
                "Use \(.applicationName) to read text",
                "\(.applicationName) read this",
                "\(.applicationName) help me read text"
            ],
            shortTitle: "Read Text",
            systemImageName: "text.viewfinder"
        )

        // Translation mode
        AppShortcut(
            intent: QuickVisionTranslateIntent(),
            phrases: [
                "Use \(.applicationName) to translate",
                "\(.applicationName) translate this",
                "\(.applicationName) what does this mean"
            ],
            shortTitle: "Translate Text",
            systemImageName: "character.bubble.fill"
        )

        // Encyclopedia mode
        AppShortcut(
            intent: QuickVisionEncyclopediaIntent(),
            phrases: [
                "Use \(.applicationName) to identify this",
                "\(.applicationName) Encyclopedia",
                "\(.applicationName) what is this thing"
            ],
            shortTitle: "Encyclopedia",
            systemImageName: "books.vertical.circle.fill"
        )

        // Live AI
        AppShortcut(
            intent: LiveAIIntent(),
            phrases: [
                "Use \(.applicationName) Live AI",
                "\(.applicationName) Live AI",
                "Start \(.applicationName) Live AI",
                "\(.applicationName) start conversation"
            ],
            shortTitle: "Live AI",
            systemImageName: "brain.head.profile"
        )

        // Stop Live AI
        AppShortcut(
            intent: StopLiveAIIntent(),
            phrases: [
                "\(.applicationName) Stop Live AI",
                "Stop \(.applicationName) Live AI",
                "\(.applicationName) end conversation"
            ],
            shortTitle: "Stop Live AI",
            systemImageName: "stop.circle.fill"
        )
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let quickVisionTriggered = Notification.Name("quickVisionTriggered")
}

// MARK: - Quick Vision Manager

@MainActor
class QuickVisionManager: ObservableObject {
    static let shared = QuickVisionManager()

    @Published var isProcessing = false
    @Published var lastResult: String?
    @Published var errorMessage: String?
    @Published var lastImage: UIImage?
    @Published var lastMode: QuickVisionMode = .standard

    // Expose streamViewModel for Intent to check initialization status
    private(set) var streamViewModel: StreamSessionViewModel?
    private let tts = TTSService.shared

    private init() {
        // Listen for Intent trigger
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQuickVisionTrigger(_:)),
            name: .quickVisionTriggered,
            object: nil
        )
    }

    /// Set the StreamSessionViewModel reference
    func setStreamViewModel(_ viewModel: StreamSessionViewModel) {
        self.streamViewModel = viewModel
    }

    @objc private func handleQuickVisionTrigger(_ notification: Notification) {
        let customPrompt = notification.userInfo?["customPrompt"] as? String
        let modeString = notification.userInfo?["mode"] as? String
        let mode = modeString.flatMap { QuickVisionMode(rawValue: $0) } ?? .standard

        Task { @MainActor in
            await performQuickVisionWithMode(mode, customPrompt: customPrompt)
        }
    }

    /// Perform Quick Vision with the specified mode
    func performQuickVisionWithMode(_ mode: QuickVisionMode, customPrompt: String? = nil) async {
        guard !isProcessing else {
            print("⚠️ [QuickVision] Already processing")
            return
        }

        guard let streamViewModel = streamViewModel else {
            print("❌ [QuickVision] StreamViewModel not set")
            tts.speak("Quick Vision not initialized, please open the app first")
            return
        }

        isProcessing = true
        errorMessage = nil
        lastResult = nil
        lastImage = nil
        lastMode = mode

        // Get API Key
        guard let apiKey = APIKeyManager.shared.getAPIKey(), !apiKey.isEmpty else {
            errorMessage = "Please configure API Key in Settings first"
            tts.speak("Please configure API Key in Settings first")
            isProcessing = false
            return
        }

        // Announce start
        tts.speak("Recognizing...", apiKey: apiKey)

        // Get prompt
        let prompt = customPrompt ?? QuickVisionModeManager.shared.getPrompt(for: mode)

        do {
            // 0. Check if device is connected
            if !streamViewModel.hasActiveDevice {
                print("❌ [QuickVision] No active device connected")
                throw QuickVisionError.noDevice
            }

            // 1. Start video stream (if not already started)
            if streamViewModel.streamingStatus != .streaming {
                print("📹 [QuickVision] Starting stream...")
                await streamViewModel.handleStartStreaming()

                // Wait for stream to enter streaming state (up to 5 seconds)
                var streamWait = 0
                while streamViewModel.streamingStatus != .streaming && streamWait < 50 {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    streamWait += 1
                }

                if streamViewModel.streamingStatus != .streaming {
                    print("❌ [QuickVision] Failed to start streaming")
                    throw QuickVisionError.streamNotReady
                }
            }

            // 2. Wait for stream to stabilize
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            // 3. Clear previous photo, then capture
            streamViewModel.dismissPhotoPreview()
            print("📸 [QuickVision] Capturing photo...")
            streamViewModel.capturePhoto()

            // 4. Wait for photo capture to complete (up to 3 seconds)
            var photoWait = 0
            while streamViewModel.capturedPhoto == nil && photoWait < 30 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                photoWait += 1
            }

            // If SDK capturePhoto fails, use current video frame as fallback
            let photo: UIImage
            if let capturedPhoto = streamViewModel.capturedPhoto {
                photo = capturedPhoto
                print("📸 [QuickVision] Using SDK captured photo")
            } else if let videoFrame = streamViewModel.currentVideoFrame {
                photo = videoFrame
                print("📸 [QuickVision] SDK capturePhoto failed, using video frame as fallback")
            } else {
                print("❌ [QuickVision] No photo or video frame available")
                throw QuickVisionError.frameTimeout
            }

            print("📸 [QuickVision] Photo captured: \(photo.size.width)x\(photo.size.height)")

            // Save image for history
            lastImage = photo

            // 5. Pre-configure TTS audio session
            tts.prepareAudioSession()

            // 6. Stop video stream immediately
            print("🛑 [QuickVision] Stopping stream after capture")
            await streamViewModel.stopSession()

            // 7. Call vision API
            let service = QuickVisionService(apiKey: apiKey)
            let result = try await service.analyzeImage(photo, customPrompt: prompt)

            // 8. Save result
            lastResult = result

            // 9. Save to history
            saveToHistory(mode: mode, prompt: prompt, result: result, image: photo)

            // 10. TTS announce result
            tts.speak(result, apiKey: apiKey)

            print("✅ [QuickVision] Complete: \(result)")

        } catch let error as QuickVisionError {
            errorMessage = error.localizedDescription
            print("❌ [QuickVision] QuickVisionError: \(error)")
            tts.speak(error.localizedDescription, apiKey: apiKey)
            await streamViewModel.stopSession()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [QuickVision] Error: \(error)")
            tts.speak("Recognition failed, \(error.localizedDescription)", apiKey: apiKey)
            await streamViewModel.stopSession()
        }

        isProcessing = false
    }

    /// Perform Quick Vision (using the currently set mode)
    func performQuickVision(customPrompt: String? = nil) async {
        await performQuickVisionWithMode(QuickVisionModeManager.staticCurrentMode, customPrompt: customPrompt)
    }

    /// Perform Quick Vision (triggered from Shortcuts/Siri)
    func performQuickVisionFromIntent(customPrompt: String? = nil) async {
        await performQuickVision(customPrompt: customPrompt)
    }

    /// Save vision result to history
    private func saveToHistory(mode: QuickVisionMode, prompt: String, result: String, image: UIImage) {
        let record = QuickVisionRecord(
            mode: mode,
            prompt: prompt,
            result: result,
            thumbnail: image
        )
        QuickVisionStorage.shared.saveRecord(record)
        print("💾 [QuickVision] Record saved to history")
    }

    /// Stop video stream (called when page closes)
    func stopStream() async {
        await streamViewModel?.stopSession()
    }

    /// Manually trigger Quick Vision (called from UI)
    func triggerQuickVision(customPrompt: String? = nil) {
        Task { @MainActor in
            await performQuickVision(customPrompt: customPrompt)
        }
    }

    /// Manually trigger Quick Vision with specified mode (called from UI)
    func triggerQuickVisionWithMode(_ mode: QuickVisionMode) {
        Task { @MainActor in
            await performQuickVisionWithMode(mode)
        }
    }
}
