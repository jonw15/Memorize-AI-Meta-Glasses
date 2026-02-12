# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Aria Spark is a multimodal AI assistant for RayBan Meta smart glasses. It has two native apps — iOS (Swift/SwiftUI) and Android (Kotlin/Jetpack Compose) — that connect to the glasses via Meta's DAT SDK and integrate with AI services (Google AI Studio Gemini, OpenRouter) for features like live AI conversations, image recognition, nutrition analysis, RTMP live streaming, Quick Vision (Siri-triggered recognition), and Live Chat (WebRTC video calls streamed through the glasses camera).

## Build & Run

### iOS
- Open `CameraAccess.xcodeproj` in Xcode 15+
- Select a development team and set your Bundle Identifier
- Build and run on a physical iPhone (iOS 17.0+) — the DAT SDK requires a real device
- Run with `Cmd + R`
- Tests: `Cmd + U` (runs `CameraAccessTests` target which uses `MWDATMockDevice` for simulated device connections)

### Android
- Open the `android/` directory in Android Studio
- The DAT SDK is pulled from GitHub Packages — requires `github_username` and `github_token` in `android/local.properties`
- Build: `cd android && ./gradlew assembleDebug`
- Release APK: `cd android && ./gradlew assembleRelease` (splits by ABI: arm64-v8a, armeabi-v7a, universal)
- Min SDK 31, target SDK 34, Kotlin 1.9

## Architecture

Both platforms follow **MVVM** with matching layer structures:

### iOS (CameraAccess/)
- **Entry**: `TurboMetaApp.swift` → configures `Wearables` SDK → `MainAppView` → `RegistrationView` (pairing) or `MainTabView` (4 tabs: Home, Records, Gallery, Settings)
- **ViewModels/**: `WearablesViewModel` (device connection), `StreamSessionViewModel` (camera stream), `OmniRealtimeViewModel` (Live AI), `LeanEatViewModel`, `VisionRecognitionViewModel`, `RTMPStreamingViewModel`, `LiveTranslateViewModel`
- **Views/**: `LiveChatView.swift` (room create/join UI) + `LiveChatWebView.swift` (WKWebView with JS getUserMedia override, streams glasses frames via canvas.captureStream, routes audio through Bluetooth AVAudioSession)
- **Services/**: Each feature has a dedicated service — `GeminiLiveService` (Gemini Live real-time voice API), `VisionAPIService`, `LeanEatService`, `QuickVisionService`, `TTSService`, `RTMPStreamingService`, `LiveTranslateService`, `ConversationStorage`, `QuickVisionStorage`
- **Managers/**: `APIProviderManager` (switch between Google AI Studio/OpenRouter), `APIKeyManager` (Keychain storage), `LanguageManager` (zh-Hans/en), `LiveAIModeManager`, `QuickVisionModeManager`, `LiveAIManager`
- **Models/**: Data models for each feature domain
- **Intents/**: `QuickVisionIntent` and `LiveAIIntent` for Siri Shortcuts / App Intents
- **Utilities/**: `DesignSystem.swift` defines `AppColors` and shared UI constants
- **Localization**: `en.lproj/Localizable.strings` and `zh-Hans.lproj/Localizable.strings`, accessed via `"key".localized`

### Android (android/app/src/main/java/com/turbometa/rayban/)
- **Entry**: `MainActivity` → initializes DAT SDK, requests permissions → `TurboMetaNavigation` (Compose navigation)
- **viewmodels/**: Mirrors iOS ViewModels — `WearablesViewModel`, `OmniRealtimeViewModel`, `LeanEatViewModel`, `VisionViewModel`, `RTMPStreamingViewModel`, `RecordsViewModel`, `SettingsViewModel`
- **services/**: `GeminiLiveService`, `VisionAPIService`, `LeanEatService`, `QuickVisionService`, `RTMPStreamingService`, `PorcupineWakeWordService`
- **managers/**: `APIProviderManager`, `LanguageManager`, `LiveAIModeManager`, `QuickVisionModeManager`
- **data/**: `ConversationStorage`, `QuickVisionStorage`
- **ui/screens/**: Compose screens for each feature — includes `LiveChatScreen.kt` (WebRTC video chat with WebView JS override, QR code via zxing, Bluetooth audio routing via AudioManager.setCommunicationDevice)
- **ui/theme/**: Material 3 theme (Color, Theme, Type)

### Key SDK Integration
- **Meta DAT SDK v0.3.0**: `MWDATCore` (iOS) / `com.meta.wearable.dat.core` (Android) — handles device discovery, pairing, camera streaming, photo capture
- Device must be in developer mode (Meta AI app → Settings → tap version 5 times)
- `WearablesViewModel` is the central hub for device state across both platforms

### AI Service Communication
- **GeminiLiveService**: WebSocket connection to Gemini Live API for real-time audio+video AI chat. The API key, WebSocket URL, and model are auto-fetched from a config server on app launch (`LiveAIConfigService`), decrypted via AES-256-CBC, and stored in `APIProviderManager`. Falls back to hardcoded defaults if server is unreachable.
- **LiveAIConfigService**: Fetches encrypted config from `{API_APP}/config/get`, decrypts it (AES-256-CBC with PKCS7), extracts `key`, `url`, `model`. To configure, set the three placeholder values in `CameraAccess/Utils/LiveAIConfig.swift` (iOS) and `android/.../utils/LiveAIConfig.kt` (Android) — both files must have identical values:
  - `apiApp` / `API_APP` — server base URL (the part before `/config/get`)
  - `configIdAILive` / `CONFIG_ID_AI_LIVE` — the config ID sent as `{ "id": "..." }` in the POST body
  - `configIV` / `CONFIG_IV` — pre-shared AES IV (Base64), corresponds to `configKey.key` in the C# reference
- **VisionAPIService**: REST calls to Google AI Studio or OpenRouter (OpenAI-compatible `/v1/chat/completions` endpoint) using `gemini-2.5-flash` or configurable models
- Vision API keys stored in iOS Keychain (`APIKeyManager`) / Android EncryptedSharedPreferences; Live AI key auto-fetched from server

### API Configuration
- `VisionAPIConfig.swift` / `APIProviderManager` controls provider selection and endpoint routing
- Google AI Studio at `generativelanguage.googleapis.com/v1beta/openai`
- OpenRouter at `openrouter.ai/api/v1`

### Live Chat (WebRTC Video Calls)
- Embeds a WebView loading `https://app.ariaspark.com/webrtc/?a=<room_code>&autostart=true`
- JavaScript override replaces browser camera with glasses frames via `canvas.captureStream(30)` and routes audio through a `GainNode` for mute control
- Native UI overlay controls (mute, hangup, video toggle) call `window.__toggleAudio()` / `window.__toggleVideo()` in the WebView
- Glasses frames are sent as Base64 JPEG at ~10fps via `window.__updateGlassesFrame(b64)`
- iOS: `LiveChatView.swift` + `LiveChatWebView.swift`, Bluetooth audio via `AVAudioSession` with `.allowBluetoothHFP`
- Android: `LiveChatScreen.kt`, Bluetooth audio via `AudioManager.setCommunicationDevice()` (API 31+), QR codes via `com.google.zxing:core`

## Localization

Strings use key-based localization (`"key".localized` on iOS). When adding user-facing text, add entries to both `en.lproj/Localizable.strings` and `zh-Hans.lproj/Localizable.strings`. The Android app uses `LanguageManager` for runtime language switching.

## Important Notes

- The Xcode project is `CameraAccess.xcodeproj` (not a workspace) — the original project name from Meta's sample code
- The app module is called `CameraAccess` in Xcode but the app itself is `TurboMeta`
- Android DAT SDK dependency requires GitHub Packages authentication (see `android/settings.gradle.kts`)
- `.gitignore` blocks `*APIKey*.swift` and `*Secret*.swift` files — API keys must not be committed
- Some comments in the codebase are in Chinese (the primary audience is Chinese-speaking users)

## Adding/Removing Swift Files to the Xcode Project

The `xcodeproj` Ruby gem is too old for this project's format (`PBXFileSystemSynchronizedRootGroup`), so edit `CameraAccess.xcodeproj/project.pbxproj` directly. Four edits are needed per file:

1. **PBXBuildFile section** — add: `ID1 /* File.swift in Sources */ = {isa = PBXBuildFile; fileRef = ID2 /* File.swift */; };`
2. **PBXFileReference section** — add: `ID2 /* File.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = File.swift; sourceTree = "<group>"; };`
3. **PBXGroup children** — add `ID2 /* File.swift */,` to the correct group (e.g. `Services`, `Utils`, `Views`)
4. **PBXSourcesBuildPhase files** — add `ID1 /* File.swift in Sources */,`

Use a readable ID convention: prefix `LA` for LiveAI, `LC` for LiveChat, `LT` for LiveTranslate, etc. Build file IDs use `XX0001...` and file reference IDs use `XX1001...`. To remove a file, delete the same 4 entries.
