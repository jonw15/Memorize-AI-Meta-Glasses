package com.turbometa.rayban.utils

import android.content.Context
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.turbometa.rayban.managers.APIProvider
import com.turbometa.rayban.managers.APIProviderManager

/**
 * API Key Manager
 * Secure storage and retrieval of API keys using EncryptedSharedPreferences
 * Supports multiple API providers (Google AI Studio, OpenRouter)
 * 1:1 port from iOS APIKeyManager.swift
 */
class APIKeyManager(context: Context) {

    companion object {
        private const val TAG = "APIKeyManager"
        private const val PREFS_NAME = "turbometa_secure_prefs"

        // Account names for different providers
        private const val KEY_GOOGLE = "google-api-key"
        private const val KEY_OPENROUTER = "openrouter-api-key"

        // Settings keys
        private const val KEY_AI_MODEL = "ai_model"
        private const val KEY_OUTPUT_LANGUAGE = "output_language"
        private const val KEY_VIDEO_QUALITY = "video_quality"
        private const val KEY_RTMP_URL = "rtmp_url"

        @Volatile
        private var instance: APIKeyManager? = null

        fun getInstance(context: Context): APIKeyManager {
            return instance ?: synchronized(this) {
                instance ?: APIKeyManager(context.applicationContext).also { instance = it }
            }
        }
    }

    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val sharedPreferences = EncryptedSharedPreferences.create(
        context,
        PREFS_NAME,
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    // MARK: - Provider-specific API Key Management

    fun saveAPIKey(key: String, provider: APIProvider): Boolean {
        return try {
            if (key.isBlank()) return false
            val accountKey = accountName(provider)
            sharedPreferences.edit().putString(accountKey, key).apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save API key: ${e.message}")
            false
        }
    }

    fun getAPIKey(provider: APIProvider): String? {
        return try {
            val accountKey = accountName(provider)
            sharedPreferences.getString(accountKey, null)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get API key: ${e.message}")
            null
        }
    }

    fun deleteAPIKey(provider: APIProvider): Boolean {
        return try {
            val accountKey = accountName(provider)
            sharedPreferences.edit().remove(accountKey).apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete API key: ${e.message}")
            false
        }
    }

    fun hasAPIKey(provider: APIProvider): Boolean {
        return !getAPIKey(provider).isNullOrBlank()
    }

    // MARK: - Google API Key (convenience methods)

    fun saveGoogleAPIKey(key: String): Boolean {
        return saveAPIKey(key, APIProvider.GOOGLE)
    }

    fun getGoogleAPIKey(): String? {
        return getAPIKey(APIProvider.GOOGLE)
    }

    fun deleteGoogleAPIKey(): Boolean {
        return deleteAPIKey(APIProvider.GOOGLE)
    }

    fun hasGoogleAPIKey(): Boolean {
        return hasAPIKey(APIProvider.GOOGLE)
    }

    // MARK: - Backward Compatible Methods (defaults to current provider)

    fun saveAPIKey(key: String): Boolean {
        return saveAPIKey(key, APIProviderManager.staticCurrentProvider)
    }

    fun getAPIKey(): String? {
        return getAPIKey(APIProviderManager.staticCurrentProvider)
    }

    fun deleteAPIKey(): Boolean {
        return deleteAPIKey(APIProviderManager.staticCurrentProvider)
    }

    fun hasAPIKey(): Boolean {
        return hasAPIKey(APIProviderManager.staticCurrentProvider)
    }

    // MARK: - Private Helpers

    private fun accountName(provider: APIProvider): String {
        return when (provider) {
            APIProvider.GOOGLE -> KEY_GOOGLE
            APIProvider.OPENROUTER -> KEY_OPENROUTER
        }
    }

    // MARK: - Settings (non-sensitive data)

    // AI Model
    fun saveAIModel(model: String) {
        sharedPreferences.edit().putString(KEY_AI_MODEL, model).apply()
    }

    fun getAIModel(): String {
        return sharedPreferences.getString(KEY_AI_MODEL, "gemini-2.5-flash-native-audio-preview-12-2025") ?: "gemini-2.5-flash-native-audio-preview-12-2025"
    }

    // Output Language
    fun saveOutputLanguage(language: String) {
        sharedPreferences.edit().putString(KEY_OUTPUT_LANGUAGE, language).apply()
    }

    fun getOutputLanguage(): String {
        return sharedPreferences.getString(KEY_OUTPUT_LANGUAGE, "en-US") ?: "en-US"
    }

    // Video Quality
    fun saveVideoQuality(quality: String) {
        sharedPreferences.edit().putString(KEY_VIDEO_QUALITY, quality).apply()
    }

    fun getVideoQuality(): String {
        return sharedPreferences.getString(KEY_VIDEO_QUALITY, "MEDIUM") ?: "MEDIUM"
    }

    // RTMP URL
    fun saveRtmpUrl(url: String) {
        sharedPreferences.edit().putString(KEY_RTMP_URL, url).apply()
    }

    fun getRtmpUrl(): String? {
        return sharedPreferences.getString(KEY_RTMP_URL, null)
    }
}

// Available output languages
enum class OutputLanguage(val code: String, val displayName: String, val nativeName: String) {
    ENGLISH("en-US", "English", "English"),
    CHINESE("zh-CN", "Chinese", "\u4e2d\u6587"),
    JAPANESE("ja-JP", "Japanese", "\u65e5\u672c\u8a9e"),
    KOREAN("ko-KR", "Korean", "\ud55c\uad6d\uc5b4"),
    SPANISH("es-ES", "Spanish", "Espa\u00f1ol"),
    FRENCH("fr-FR", "French", "Fran\u00e7ais")
}

// Video quality options
enum class StreamQuality(val id: String, val displayNameResId: Int, val descriptionResId: Int) {
    LOW("LOW", com.turbometa.rayban.R.string.quality_low, com.turbometa.rayban.R.string.quality_low_desc),
    MEDIUM("MEDIUM", com.turbometa.rayban.R.string.quality_medium, com.turbometa.rayban.R.string.quality_medium_desc),
    HIGH("HIGH", com.turbometa.rayban.R.string.quality_high, com.turbometa.rayban.R.string.quality_high_desc)
}
