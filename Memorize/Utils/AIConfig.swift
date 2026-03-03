/*
 * AI Configuration
 * Server API and encryption constants for auto-fetching AI config
 */

import Foundation

struct AIConfig {
    /// Base URL of the config server API
    static let apiApp = "https://yp3pqak8l7.execute-api.us-east-1.amazonaws.com/prod/"

    /// Config ID for AI configuration
    static let configIdAILive = "ai_live_google"

    /// AES-256-CBC IV (Base64 encoded)
    static let configIV = "/Zk5T8D0i1rbM8ElAkjbRA=="
}

/// Tunable Live AI parameters — change these values to adjust behavior globally.
struct LiveAIConfig {
    /// How often (in seconds) to send a camera frame to Gemini during Live AI.
    static let imageSendIntervalSeconds: TimeInterval = 1.0

    /// When true, YouTube videos play via native AVPlayer (better Bluetooth routing).
    /// When false, uses WKWebView via app.ariaspark.com/yt/ (original behavior).
    static let useNativeYouTubePlayer: Bool = true

    /// When true, pre-decrypt all YouTube video streams when search results arrive.
    /// When false, decrypt on tap only.
    static let isPreDecryptVideo: Bool = false

    /// When true, skip native AVPlayer and force WKWebView fallback for testing.
    static let isTestYouTubeWebviewFallback: Bool = false
}
