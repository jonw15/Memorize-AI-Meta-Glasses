package com.turbometa.rayban.utils

/**
 * Live AI Configuration
 * Server API and encryption constants for auto-fetching Live AI config
 */
object LiveAIConfig {
    /** Base URL of the config server API */
    const val API_APP = "https://yp3pqak8l7.execute-api.us-east-1.amazonaws.com/prod/"

    /** Config ID for Live AI configuration */
    const val CONFIG_ID_AI_LIVE = "ai_live_google"

    /** AES-256-CBC IV (Base64 encoded) */
    const val CONFIG_IV = "/Zk5T8D0i1rbM8ElAkjbRA=="
}
