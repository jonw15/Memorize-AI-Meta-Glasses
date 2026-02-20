# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Aria Spark is a multimodal AI assistant for RayBan Meta smart glasses. It has two native apps — iOS (Swift/SwiftUI) and Android (Kotlin/Jetpack Compose) — that connect to the glasses via Meta's DAT SDK and integrate with AI services (Google AI Studio Gemini, OpenRouter) for features like live AI conversations, image recognition, nutrition analysis, RTMP live streaming, screen recording live streaming, Quick Vision (Siri-triggered recognition), Live Translate (iOS only), and Live Chat (WebRTC video calls streamed through the glasses camera). WordLearn is a planned feature (stubs exist, not yet implemented).

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
- Min SDK 31, target SDK 34, compile SDK 35, Kotlin 1.9
- Current version: 1.5.0 (versionCode 4)

## Architecture

Both platforms follow **MVVM** with matching layer structures:

### iOS (CameraAccess/)
- **Entry**: `AriaApp.swift` → configures `Wearables` SDK → `MainAppView` → `HomeScreenView` (project intro) → `PermissionsRequestView` (mic + photo library) → `RegistrationView` (pairing) or `MainTabView` (4 tabs: Home, Records, Gallery, Settings)
- **ViewModels/**: `WearablesViewModel` (device connection), `StreamSessionViewModel` (camera stream), `OmniRealtimeViewModel` (Live AI), `LeanEatViewModel`, `VisionRecognitionViewModel`, `RTMPStreamingViewModel`, `LiveTranslateViewModel`, `DebugMenuViewModel` (DEBUG only)
- **Views/**: Key views include:
  - `AriaHomeView` — main home screen with feature grid (Live Chat, Live AI, Quick Vision, Live Translate, LeanEat, RTMP Streaming, Screen Recording Stream tiles). Handles notification-driven navigation
  - `HomeScreenView` — onboarding/connection screen shown when not registered, with project intro and "Connect Ray-Ban Meta" flow
  - `RecordsView` — Records tab with 5 sub-tabs: Live AI, Live Translate, LeanEat, WordLearn, Quick Vision
  - `ConversationDetailView` — individual conversation messages view
  - `GalleryView` — Gallery tab with 3-column photo grid (placeholder)
  - `PermissionsRequestView` — first-launch permissions request for mic + photo library
  - `PhotoPreviewView` — photo preview overlay with AI Recognition, LeanEat, and Share
  - `NonStreamView` — pre-stream screen with getting started tips
  - `SimpleLiveStreamView` — screen-recording live stream (for TikTok/Kuaishou/Douyin)
  - `LiveAISettingsView` — Live AI mode selection (standard, museum, blind, reading, translate, custom)
  - `LiveTranslateSettingsView` — Live Translate settings (languages, voice, mic toggle)
  - `QuickVisionSettingsView` — Quick Vision settings + history
  - `LiveChatView` + `LiveChatWebView` — WebRTC video chat via WKWebView
  - **Views/Components/**: `CardView`, `CircleButton`, `CustomButton`, `MediaPickerView`, `StatusText` — shared UI components
  - **Views/MockDeviceKit/**: `MockDeviceKitView`, `MockDeviceCardView`, `MockDeviceKitButton` (DEBUG only, currently commented out in `AriaApp.swift`)
- **Services/**: Each feature has a dedicated service — `GeminiLiveService` (Gemini Live real-time voice API), `VisionAPIService`, `VisionAPIConfig` (centralizes Vision API config from `APIProviderManager`), `LeanEatService`, `QuickVisionService`, `TTSService`, `RTMPStreamingService`, `LiveTranslateService`, `ConversationStorage`, `QuickVisionStorage`
- **Managers/**: `APIProviderManager` (switch between Google AI Studio/OpenRouter, also exposes `staticLiveAIAPIKey`), `APIKeyManager` (Keychain storage), `LanguageManager` (zh-Hans/en), `LiveAIModeManager`, `QuickVisionModeManager`, `LiveAIManager`
- **Models/**: Data models for each feature domain
- **Intents/**: `QuickVisionIntent` (+ 6 mode variants: Health, Blind, Reading, Translate, Encyclopedia, Custom), `LiveAIIntent`, `StopLiveAIIntent`, and `QuickVisionManager` singleton (orchestrates Siri-triggered Quick Vision flow)
- **Utilities/**: `DesignSystem.swift` (defines `AppColors` with feature-specific colors, `AppTypography`, `AppSpacing`, `AppCornerRadius`, `AppShadow`, `Color(hex:)` extension), `PermissionsManager` (mic + photo library permissions), `TimeUtils` (`StreamTimeLimit` enum, countdown formatting)
- **Notifications**: `.liveAITriggered`, `.liveChatTriggered`, `.liveChatClosedToLiveAI`, `.returnToNewProjectIntro` — used for cross-view navigation
- **Localization**: `en.lproj/Localizable.strings` and `zh-Hans.lproj/Localizable.strings`, accessed via `"key".localized`

### Android (android/app/src/main/java/com/ariaspark/metawearables/)
- **Entry**: `AriaApplication` (Application subclass, auto-fetches AI config on launch) → `MainActivity` → initializes DAT SDK, requests permissions → `AriaNavigation` (Compose navigation)
- **ui/navigation/Navigation.kt**: Defines `Screen` sealed class (Home, LiveAI, LeanEat, Vision, QuickVision, Settings, Records, Gallery, LiveStream, RTMPStream, QuickVisionMode, LiveAIMode, LiveChat), `BottomNavItem` sealed class (Home, Records, Gallery, Settings), and `AriaNavigation` composable with full NavHost
- **viewmodels/**: Mirrors iOS ViewModels — `WearablesViewModel`, `OmniRealtimeViewModel`, `LeanEatViewModel`, `VisionViewModel`, `RTMPStreamingViewModel`, `RecordsViewModel`, `SettingsViewModel`
- **services/**: `GeminiLiveService`, `VisionAPIService`, `LeanEatService`, `QuickVisionService`, `RTMPStreamingService`, `PorcupineWakeWordService`
- **managers/**: `APIProviderManager`, `LanguageManager`, `LiveAIModeManager`, `QuickVisionModeManager`
- **data/**: `ConversationStorage`, `QuickVisionStorage`
- **models/**: `ConversationModels` (ConversationRecord, ConversationMessage, MessageRole), `FoodNutritionModels`, `LiveAIMode` enum (STANDARD, MUSEUM, BLIND, READING, TRANSLATE, CUSTOM), `QuickVisionMode` enum (STANDARD, HEALTH, BLIND, READING, TRANSLATE, ENCYCLOPEDIA, CUSTOM), `QuickVisionRecord`
- **utils/**: `APIKeyManager` (EncryptedSharedPreferences with AES256_GCM, stores per-provider keys + settings), `OutputLanguage` enum, `StreamQuality` enum, `AIConfig.kt`
- **ui/screens/**: Compose screens for each feature — includes `LiveChatScreen.kt` (WebRTC video chat with WebView JS override, QR code via zxing, Bluetooth audio routing via AudioManager.setCommunicationDevice), `SimpleLiveStreamScreen.kt` (screen-recording live stream), `ModeSettingsScreen.kt` (QuickVisionModeScreen + LiveAIModeScreen), `GalleryScreen.kt` (placeholder)
- **ui/components/CommonComponents.kt**: `GradientButton`, `FeatureCard`, `StatusBadge`, `SectionHeader`, `AriaTopBar`, `LoadingIndicator`, `ErrorMessage`, `SuccessMessage`, `EmptyState`, `ConfirmDialog`, `NutritionBar`, `HealthScoreCircle`
- **ui/theme/**: Material 3 theme (Color, Theme, Type)
- **Key dependencies**: `mwdat-core` + `mwdat-camera` (DAT SDK), `coil-compose` (image loading), `kotlinx-collections-immutable`, `exifinterface`, `zxing` (QR codes). Room database is declared in `libs.versions.toml` but not yet used

### Key SDK Integration
- **Meta DAT SDK v0.3.0**: `MWDATCore` + `MWDATCamera` (iOS) / `com.meta.wearable.dat.core` + `com.meta.wearable.dat.camera` (Android) — handles device discovery, pairing, camera streaming, photo capture
- Device must be in developer mode (Meta AI app → Settings → tap version 5 times)
- `WearablesViewModel` is the central hub for device state across both platforms
- Mock device support (DEBUG only): `MockDeviceKitViewModel` / `MockDeviceViewModel` on iOS, `mwdat-mockdevice` on Android (currently commented out)

### Feature → AI Service Map

| Feature                  | Model                                              | Protocol        | Platform      |
|--------------------------|----------------------------------------------------|-----------------|---------------|
| Live AI                  | `gemini-2.5-flash-native-audio-preview-12-2025`    | WebSocket       | iOS + Android |
| Vision/Image Recognition | `gemini-2.5-flash`                                 | REST            | iOS + Android |
| Quick Vision             | `gemini-2.5-flash` (via VisionAPIService)          | REST            | iOS + Android |
| LeanEat (Nutrition)      | `gemini-2.5-flash`                                 | REST            | iOS + Android |
| Live Translate           | `gemini-2.5-flash-native-audio-preview-12-2025`    | WebSocket       | iOS only      |
| System TTS               | iOS `AVSpeechSynthesizer` / Android `TextToSpeech` | Local           | iOS + Android |
| RTMP Streaming           | HaishinKit                                         | RTMP            | iOS + Android |
| Screen Recording Stream  | N/A (glasses camera shown full-screen for native screen recording) | N/A | iOS + Android |
| Live Chat                | WebRTC (`ariaspark.com`)                           | WebRTC          | iOS + Android |
| Wake Word (Android)      | Porcupine SDK (require access key)                 | Local on-device | Android only  |

All Gemini features share a single auto-fetched API key from `AIConfigService`.

> **Note:** Porcupine requires a paid Picovoice access key. [OpenWakeWord](https://github.com/dscripka/openWakeWord) (ONNX Runtime) is a free, keyless, on-device alternative that could replace it.

### System TTS Usage
- **Quick Vision**: `TTSService.shared` (iOS) / `TextToSpeech` (Android) speaks recognition results and status messages
- **LiveAIManager** (iOS only): `TTSService.shared` speaks error messages (e.g. "not initialized", "configure API key")
- Live AI conversation audio comes from Gemini's native audio stream, not System TTS

### AI Service Communication
- **GeminiLiveService**: WebSocket connection to Gemini Live API for real-time audio+video AI chat
- **AIConfigService**: Fetches encrypted config from `{API_APP}/config/get`, decrypts it (AES-256-CBC with PKCS7), extracts `key`, `url`, `model`. To configure, set the three constants in `CameraAccess/Utils/AIConfig.swift` (iOS) and `android/.../utils/AIConfig.kt` (Android) — both files must have identical values:
  - `apiApp` / `API_APP` — server base URL (the part before `/config/get`)
  - `configIdAILive` / `CONFIG_ID_AI_LIVE` — the config ID sent as `{ "id": "..." }` in the POST body
  - `configIV` / `CONFIG_IV` — pre-shared AES IV (Base64), corresponds to `configKey.key` in the C# reference
- **VisionAPIService**: REST calls to Google AI Studio or OpenRouter (OpenAI-compatible `/v1/chat/completions` endpoint) using `gemini-2.5-flash` or configurable models
- **VisionAPIConfig** (iOS): Static struct centralizing Vision API config — dynamically pulls `apiKey`, `baseURL`, `model` from `APIProviderManager`, defines provider-specific constants and `headers(with:)` helper

### API Configuration
- A single API key is auto-fetched from a config server on app launch via `AIConfigService` and shared by all Gemini AI services (Live AI, Vision, LeanEat, QuickVision)
- The API key has **no fallback** — if the server fetch fails, AI features will not work
- The Live AI WebSocket URL and model have hardcoded fallback defaults in `APIProviderManager` (standard Gemini endpoint and model)
- Provider selection, model settings, and API key management are all hidden from end users in Settings
- The three configurable server constants live in `AIConfig.swift` (iOS) / `AIConfig.kt` (Android) — see `AIConfigService` above for details

### Live Chat (WebRTC Video Calls)
- Embeds a WebView loading `https://app.ariaspark.com/webrtc/?a=<room_code>&autostart=true`
- JavaScript override replaces browser camera with glasses frames via `canvas.captureStream(30)` and routes audio through a `GainNode` for mute control
- Native UI overlay controls (mute, hangup, video toggle) call `window.__toggleAudio()` / `window.__toggleVideo()` in the WebView
- Glasses frames are sent as Base64 JPEG at ~10fps via `window.__updateGlassesFrame(b64)`
- iOS: `LiveChatView.swift` + `LiveChatWebView.swift`, Bluetooth audio via `AVAudioSession` with `.allowBluetoothHFP`
- Android: `LiveChatScreen.kt`, Bluetooth audio via `AudioManager.setCommunicationDevice()` (API 31+), QR codes via `com.google.zxing:core`

## Localization

Strings use key-based localization (`"key".localized` on iOS). When adding user-facing text, add entries to both `en.lproj/Localizable.strings` and `zh-Hans.lproj/Localizable.strings`. The Android app uses `LanguageManager` for runtime language switching.

### Platform Differences

- **Live Translate** — iOS only; no Android implementation exists (no service, ViewModel, or screen)
- **Wake Word** — Android only (Porcupine SDK); no iOS equivalent
- **Screen Recording Stream** — both platforms (`SimpleLiveStreamView` iOS / `SimpleLiveStreamScreen` Android)
- **WordLearn** — planned feature, stubs exist in iOS `RecordsView` and `DesignSystem` but no implementation on either platform

## Important Notes

- The Xcode project is `CameraAccess.xcodeproj` (not a workspace) — the original project name from Meta's sample code
- The app module is called `CameraAccess` in Xcode but the app itself is `Aria`
- Android DAT SDK dependency requires GitHub Packages authentication (see `android/settings.gradle.kts`)
- `.gitignore` blocks `*APIKey*.swift` and `*Secret*.swift` files — API keys must not be committed
- Some comments in the codebase are in Chinese (the primary audience is Chinese-speaking users)
- The debug menu (`DebugMenuView` + `MockDeviceKitView`) is currently commented out in `AriaApp.swift`
- OpenRouter default model is `google/gemini-3-flash-preview`

## Adding/Removing Swift Files to the Xcode Project

The `xcodeproj` Ruby gem is too old for this project's format (`PBXFileSystemSynchronizedRootGroup`), so edit `CameraAccess.xcodeproj/project.pbxproj` directly. Four edits are needed per file:

1. **PBXBuildFile section** — add: `ID1 /* File.swift in Sources */ = {isa = PBXBuildFile; fileRef = ID2 /* File.swift */; };`
2. **PBXFileReference section** — add: `ID2 /* File.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = File.swift; sourceTree = "<group>"; };`
3. **PBXGroup children** — add `ID2 /* File.swift */,` to the correct group (e.g. `Services`, `Utils`, `Views`)
4. **PBXSourcesBuildPhase files** — add `ID1 /* File.swift in Sources */,`

Use a readable ID convention: prefix `LA` for AI config, `LC` for LiveChat, `LT` for LiveTranslate, etc. Build file IDs use `XX0001...` and file reference IDs use `XX1001...`. To remove a file, delete the same 4 entries.
