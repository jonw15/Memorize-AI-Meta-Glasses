# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TurboMeta is a multimodal AI assistant for RayBan Meta smart glasses. It has two native apps — iOS (Swift/SwiftUI) and Android (Kotlin/Jetpack Compose) — that connect to the glasses via Meta's DAT SDK and integrate with AI services (Google AI Studio Gemini, OpenRouter) for features like live AI conversations, image recognition, nutrition analysis, RTMP live streaming, and Quick Vision (Siri-triggered recognition).

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
- **ui/screens/**: Compose screens for each feature
- **ui/theme/**: Material 3 theme (Color, Theme, Type)

### Key SDK Integration
- **Meta DAT SDK v0.3.0**: `MWDATCore` (iOS) / `com.meta.wearable.dat.core` (Android) — handles device discovery, pairing, camera streaming, photo capture
- Device must be in developer mode (Meta AI app → Settings → tap version 5 times)
- `WearablesViewModel` is the central hub for device state across both platforms

### AI Service Communication
- **GeminiLiveService**: WebSocket connection to Gemini Live API (`wss://generativelanguage.googleapis.com/ws/...`) for real-time audio+video AI chat using `gemini-2.5-flash-native-audio-preview-12-2025`
- **VisionAPIService**: REST calls to Google AI Studio or OpenRouter (OpenAI-compatible `/v1/chat/completions` endpoint) using `gemini-2.5-flash` or configurable models
- API keys stored in iOS Keychain (`APIKeyManager`) / Android EncryptedSharedPreferences

### API Configuration
- `VisionAPIConfig.swift` / `APIProviderManager` controls provider selection and endpoint routing
- Google AI Studio at `generativelanguage.googleapis.com/v1beta/openai`
- OpenRouter at `openrouter.ai/api/v1`

## Localization

Strings use key-based localization (`"key".localized` on iOS). When adding user-facing text, add entries to both `en.lproj/Localizable.strings` and `zh-Hans.lproj/Localizable.strings`. The Android app uses `LanguageManager` for runtime language switching.

## Important Notes

- The Xcode project is `CameraAccess.xcodeproj` (not a workspace) — the original project name from Meta's sample code
- The app module is called `CameraAccess` in Xcode but the app itself is `TurboMeta`
- Android DAT SDK dependency requires GitHub Packages authentication (see `android/settings.gradle.kts`)
- `.gitignore` blocks `*APIKey*.swift` and `*Secret*.swift` files — API keys must not be committed
- Some comments in the codebase are in Chinese (the primary audience is Chinese-speaking users)
