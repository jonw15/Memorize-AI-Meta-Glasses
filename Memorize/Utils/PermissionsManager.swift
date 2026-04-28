/*
 * Permissions Manager
 * Unified management of all permissions required by the app
 */

import Foundation
import UIKit
import AVFoundation
import Photos

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var allPermissionsGranted = false

    private init() {}

    // MARK: - Request All Permissions

    func requestAllPermissions(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        print("📋 [Permissions] Requesting all permissions...")

        Task { @MainActor in
            let microphoneGranted = await requestMicrophonePermission()
            let photoLibraryGranted = await requestPhotoLibraryPermission()
            let allGranted = microphoneGranted && photoLibraryGranted
            self.allPermissionsGranted = allGranted

            if allGranted {
                print("✅ [Permissions] All permissions granted")
            } else {
                print("⚠️ [Permissions] Some permissions not granted:")
                print("   Microphone: \(microphoneGranted ? "✅" : "❌")")
                print("   Photo Library: \(photoLibraryGranted ? "✅" : "❌")")
            }

            completion(allGranted)
        }
    }

    // MARK: - Check All Permission Status

    func checkAllPermissions() -> Bool {
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        let microphoneGranted = microphoneStatus == .authorized
        let photoGranted = photoStatus == .authorized || photoStatus == .limited

        allPermissionsGranted = microphoneGranted && photoGranted
        return allPermissionsGranted
    }

    // MARK: - Microphone Permission

    private func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            print("✅ [Permissions] Microphone permission granted")
            return true

        case .notDetermined:
            print("🎤 [Permissions] Requesting microphone permission...")
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    print(granted ? "✅ [Permissions] Microphone permission granted" : "❌ [Permissions] Microphone permission denied")
                    continuation.resume(returning: granted)
                }
            }

        case .denied, .restricted:
            print("❌ [Permissions] Microphone permission denied or restricted")
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Photo Library Permission

    private func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            print("✅ [Permissions] Photo library permission granted")
            return true

        case .notDetermined:
            print("📷 [Permissions] Requesting photo library permission...")
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    let granted = newStatus == .authorized || newStatus == .limited
                    print(granted ? "✅ [Permissions] Photo library permission granted" : "❌ [Permissions] Photo library permission denied")
                    continuation.resume(returning: granted)
                }
            }

        case .denied, .restricted:
            print("❌ [Permissions] Photo library permission denied or restricted")
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Open System Settings

    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
}
