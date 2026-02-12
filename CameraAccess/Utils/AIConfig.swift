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
