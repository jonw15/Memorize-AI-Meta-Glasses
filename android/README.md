# Aria Ray-Ban AI - Android

**Version 1.5.0**

AI assistant for Ray-Ban Meta smart glasses - Android version.

> **🎬 RTMP Live Streaming (Experimental)**
>
> Push live video from Ray-Ban Meta glasses to **any RTMP-compatible platform** - YouTube Live, Twitch, Bilibili, Douyin, TikTok, Facebook Live, and more!

## Features

### Live AI - Real-time AI Conversation
- Real-time voice conversation with AI through Ray-Ban Meta glasses
- Powered by Google Gemini Live for real-time audio + video AI chat
- Periodic image sending with adjustable interval (1s/3s)
- Multiple conversation modes: Standard, Museum Guide, Accessibility, Reading, Translation, Custom

### Quick Vision
- Take photos with glasses and get AI analysis
- Wake word detection: Say "Jarvis" to trigger Quick Vision
- Multiple recognition modes: Standard, Health, Accessibility, Reading, Translation, Encyclopedia, Custom

### Multi-Provider Support
- **Vision API**: Google AI Studio / OpenRouter (Gemini, Claude, GPT, etc.)
- **Live AI**: Google Gemini Live (real-time voice)

### LeanEat - Smart Nutrition Analysis
- Take a photo of food to get nutrition analysis
- Health scoring, calorie breakdown, and dietary suggestions

### 🎬 RTMP Live Streaming (Experimental)
- Stream first-person view from glasses to any RTMP server
- Compatible with all major platforms: YouTube, Twitch, Bilibili, Douyin, TikTok, Facebook Live, etc.
- H.264 hardware encoding for smooth streaming
- Adjustable bitrate (1-4 Mbps)
- Real-time preview on phone

---

## ⚠️ Important Notes

### Developer Mode Required

Before using Aria, you **must** enable developer mode in the Meta AI App:

1. Update Ray-Ban Meta glasses firmware to version 20+
2. Update Meta AI App to the latest version
3. Open **Meta AI App** on your phone
4. Go to **Settings** → **App Info**
5. **Tap the version number 5 times rapidly**
6. You'll see "Developer mode enabled" message

### Wake Word Detection (Picovoice)

The wake word detection feature ("Jarvis") uses **Picovoice Porcupine**. To use this feature:

1. **Register at Picovoice Console**
   - Go to https://console.picovoice.ai/
   - Create a free account

2. **Get Access Key**
   - After registration, get your Access Key from the console

3. **Configure in App**
   - Go to Settings → Quick Vision → Picovoice Access Key
   - Enter your Access Key

4. **⚠️ Microphone Always On**
   - Wake word detection requires the microphone to be always listening
   - This runs as a foreground service with a notification
   - Battery optimization should be disabled for best performance

---

## Release Notes

### v1.5.0

#### New Features

- **🧠 Live AI Multi-Mode**
  - Museum Guide: Professional exhibition guide
  - Accessibility: Environment description for visually impaired users
  - Reading Assistant: Help read and understand text
  - Translator: Real-time translation assistant
  - Custom: Use your own system prompt

- **👁️ Quick Vision Multi-Mode**
  - Health: Analyze food nutrition and health
  - Encyclopedia: Identify objects and provide knowledge
  - Reading: Read and recognize text in images
  - Translation: Recognize and translate text
  - Custom: Use your own prompt

- **🗣️ Siri Shortcuts**: Voice-activate Quick Vision and Live AI

- **Google AI Studio Migration**
  - Migrated from Alibaba Cloud to Google AI Studio as primary provider
  - Vision API powered by Gemini 2.5 Flash
  - Live AI powered by Gemini 2.5 Flash Native Audio
  - Default output language changed to English

- **Periodic Image Sending for Live AI**
  - Automatically sends camera frames to AI during conversation
  - Adjustable interval: 1 second (default) or 3 seconds
  - Toggle in the Live AI screen header

### v1.4.0 (2024-12-31)

#### New Features

- **🎬 RTMP Live Streaming (Experimental)**
  - Stream first-person view from Ray-Ban Meta glasses to any RTMP server
  - Works with all major live streaming platforms worldwide
  - H.264 hardware encoding with adjustable bitrate
  - Real-time preview on phone while streaming
  - Timestamp smoothing for stable frame rate

#### Supported Platforms

- YouTube Live
- Twitch
- Bilibili
- Douyin
- TikTok
- Facebook Live
- Any RTMP-compatible server (MediaMTX, nginx-rtmp, etc.)

---

### v1.3.0 (2024-12-31)

#### New Features

- **Wake Word Detection**
  - Say "Jarvis" to trigger Quick Vision without touching the phone
  - Powered by Picovoice Porcupine

- **Vision Model Selection**
  - Choose from multiple vision models
  - Google AI Studio: Gemini 2.5 Flash, Gemini 2.5 Pro, Gemini 2.0 Flash
  - OpenRouter: Search and select from all available models
  - Filter by vision-capable models

- **App Language**
  - Switch app interface language (System/Chinese/English)
  - Auto-syncs output language when switching

#### Improvements

- **Quick Vision Flow**
  - Optimized capture flow: TTS → Start stream → Capture → Stop stream → Analyze → TTS result
  - Added debounce for wake word (prevents multiple triggers)

- **Bilingual Support**
  - Full English/Chinese translation for all UI elements
  - AI prompts follow output language setting

#### Bug Fixes

- Fixed language switching not taking effect
- Fixed hardcoded Chinese strings in various screens
- Fixed Live AI reconnection issues

---

## Setup

### API Keys

1. **Google AI Studio** (for Vision API & Live AI)
   - Get API Key: https://aistudio.google.com/apikey

2. **OpenRouter** (optional, for Vision with various models)
   - Get API Key: https://openrouter.ai/keys

3. **Picovoice** (for Wake Word Detection)
   - Get Access Key: https://console.picovoice.ai/

---

## Requirements

- Android 8.0 (API 26) or higher
- Ray-Ban Meta glasses paired via Meta AI app
- Developer mode enabled in Meta AI app

---

## Build

```bash
# Debug build
./gradlew assembleDebug

# Release build
./gradlew assembleRelease

# Install to device
./gradlew installDebug
```

---

## License

MIT License
