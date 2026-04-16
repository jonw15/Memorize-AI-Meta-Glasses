/*
 * Live AI Intent
 * App Intent - Supports Siri and Shortcuts to trigger Live AI (runs in background, no unlock needed)
 */

import AppIntents
import UIKit

// MARK: - Live AI Intent (Background Mode)

@available(iOS 16.0, *)
struct LiveAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Live AI"
    static let description = IntentDescription("Start real-time multimodal conversation")
    // Must open app because iOS has system restrictions on background recording
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Post notification to automatically open Live AI view in the app
        NotificationCenter.default.post(name: .liveAITriggered, object: nil)
        return .result(dialog: "Put on your glasses, look at your project, and tell me what you're working on.")
    }
}

// MARK: - Stop Live AI Intent

@available(iOS 16.0, *)
struct StopLiveAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Live AI"
    static let description = IntentDescription("Stop the running Live AI session")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = LiveAIManager.shared

        if manager.isRunning {
            await manager.stopSession()
            return .result(dialog: "Live AI stopped")
        } else {
            return .result(dialog: "Live AI is not running")
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let liveAITriggered = Notification.Name("liveAITriggered")
    static let liveChatTriggered = Notification.Name("liveChatTriggered")
    static let liveChatClosedToLiveAI = Notification.Name("liveChatClosedToLiveAI")
    static let returnToNewProjectIntro = Notification.Name("returnToNewProjectIntro")
}
