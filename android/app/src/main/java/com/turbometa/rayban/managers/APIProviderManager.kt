package com.turbometa.rayban.managers

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/**
 * API Provider Manager
 * Manages different API providers (Google AI Studio / OpenRouter)
 * 1:1 port from iOS APIProviderManager.swift
 */

// MARK: - API Provider Enum (Vision API)

enum class APIProvider(val id: String) {
    GOOGLE("google"),
    OPENROUTER("openrouter");

    val displayName: String
        get() = when (this) {
            GOOGLE -> "Google AI Studio"
            OPENROUTER -> "OpenRouter"
        }

    val displayNameEn: String
        get() = when (this) {
            GOOGLE -> "Google AI Studio"
            OPENROUTER -> "OpenRouter"
        }

    val baseURL: String
        get() = when (this) {
            GOOGLE -> "https://generativelanguage.googleapis.com/v1beta/openai"
            OPENROUTER -> "https://openrouter.ai/api/v1"
        }

    val defaultModel: String
        get() = when (this) {
            GOOGLE -> "gemini-2.5-flash"
            OPENROUTER -> "google/gemini-3-flash-preview"
        }

    val apiKeyHelpURL: String
        get() = when (this) {
            GOOGLE -> "https://aistudio.google.com/apikey"
            OPENROUTER -> "https://openrouter.ai/keys"
        }

    val supportsVision: Boolean
        get() = true

    companion object {
        fun fromId(id: String): APIProvider {
            // Migrate old "alibaba" provider to "google"
            if (id == "alibaba") return GOOGLE
            return entries.find { it.id == id } ?: GOOGLE
        }
    }
}

// MARK: - OpenRouter Model

data class OpenRouterModel(
    val id: String,
    val name: String,
    val description: String? = null,
    @SerializedName("context_length")
    val contextLength: Int? = null,
    val pricing: Pricing? = null,
    val architecture: Architecture? = null
) {
    val displayName: String
        get() = name.ifEmpty { id }

    val isVisionCapable: Boolean
        get() {
            // Check if model supports vision based on architecture or ID
            architecture?.let { arch ->
                if (arch.modality?.contains("image") == true ||
                    arch.modality?.contains("multimodal") == true) {
                    return true
                }
            }
            // Fallback: check common vision model patterns
            val visionPatterns = listOf("vision", "vl", "gpt-4o", "claude-3", "gemini")
            return visionPatterns.any { id.lowercase().contains(it) }
        }

    val priceDisplay: String
        get() {
            val p = pricing ?: return ""
            val promptPrice = (p.prompt.toDoubleOrNull() ?: 0.0) * 1_000_000
            val completionPrice = (p.completion.toDoubleOrNull() ?: 0.0) * 1_000_000
            return String.format("$%.2f / $%.2f per 1M tokens", promptPrice, completionPrice)
        }

    data class Pricing(
        val prompt: String,
        val completion: String
    )

    data class Architecture(
        val modality: String? = null,
        val tokenizer: String? = null,
        @SerializedName("instruct_type")
        val instructType: String? = null
    )
}

data class OpenRouterModelsResponse(
    val data: List<OpenRouterModel>
)

// MARK: - Google Vision Model

data class GoogleVisionModel(
    val id: String,
    val displayName: String,
    val description: String
) {
    companion object {
        val availableModels = listOf(
            GoogleVisionModel(
                "gemini-2.5-flash",
                "Gemini 2.5 Flash",
                "Default, fast responses"
            ),
            GoogleVisionModel(
                "gemini-2.5-pro",
                "Gemini 2.5 Pro",
                "Most capable model"
            ),
            GoogleVisionModel(
                "gemini-2.0-flash",
                "Gemini 2.0 Flash",
                "Legacy model"
            )
        )
    }
}

// MARK: - API Provider Manager

class APIProviderManager private constructor(context: Context) {

    companion object {
        private const val PREFS_NAME = "api_provider_prefs"
        private const val KEY_PROVIDER = "api_provider"
        private const val KEY_SELECTED_MODEL = "selected_vision_model"

        // Live AI Configuration — defaults (overridden by server fetch)
        private const val DEFAULT_LIVE_AI_MODEL = "gemini-2.5-flash-native-audio-preview-12-2025"
        private const val DEFAULT_LIVE_AI_WS_URL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"

        // Dynamic values set by LiveAIConfigService
        @Volatile var liveAIFetchedKey: String? = null
            private set
        @Volatile var liveAIFetchedURL: String? = null
            private set
        @Volatile var liveAIFetchedModel: String? = null
            private set

        val liveAIDefaultModel: String
            get() = liveAIFetchedModel ?: DEFAULT_LIVE_AI_MODEL

        val liveAIWebSocketURL: String
            get() = liveAIFetchedURL ?: DEFAULT_LIVE_AI_WS_URL

        @Volatile
        private var instance: APIProviderManager? = null

        fun getInstance(context: Context): APIProviderManager {
            return instance ?: synchronized(this) {
                instance ?: APIProviderManager(context.applicationContext).also { instance = it }
            }
        }

        // Static accessors for non-context access
        private var prefs: SharedPreferences? = null

        val staticCurrentProvider: APIProvider
            get() {
                val id = prefs?.getString(KEY_PROVIDER, "google") ?: "google"
                return APIProvider.fromId(id)
            }

        val staticCurrentModel: String
            get() {
                return prefs?.getString(KEY_SELECTED_MODEL, null)
                    ?: staticCurrentProvider.defaultModel
            }

        val staticBaseURL: String
            get() = staticCurrentProvider.baseURL
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val gson = Gson()
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    init {
        // Set static prefs for non-context access
        Companion.prefs = this.prefs

        // Migrate old "alibaba" provider to "google"
        val savedProvider = prefs.getString(KEY_PROVIDER, null)
        if (savedProvider == "alibaba") {
            prefs.edit().putString(KEY_PROVIDER, "google").apply()
        }
    }

    // Vision API Provider
    private val _currentProvider = MutableStateFlow(
        APIProvider.fromId(prefs.getString(KEY_PROVIDER, "google") ?: "google")
    )
    val currentProvider: StateFlow<APIProvider> = _currentProvider

    private val _selectedModel = MutableStateFlow(
        prefs.getString(KEY_SELECTED_MODEL, null) ?: APIProvider.GOOGLE.defaultModel
    )
    val selectedModel: StateFlow<String> = _selectedModel

    // OpenRouter Models
    private val _openRouterModels = MutableStateFlow<List<OpenRouterModel>>(emptyList())
    val openRouterModels: StateFlow<List<OpenRouterModel>> = _openRouterModels

    private val _isLoadingModels = MutableStateFlow(false)
    val isLoadingModels: StateFlow<Boolean> = _isLoadingModels

    private val _modelsError = MutableStateFlow<String?>(null)
    val modelsError: StateFlow<String?> = _modelsError

    // MARK: - Setters

    fun setCurrentProvider(provider: APIProvider) {
        val oldValue = _currentProvider.value
        _currentProvider.value = provider
        prefs.edit().putString(KEY_PROVIDER, provider.id).apply()

        // Reset to default model when provider changes
        if (oldValue != provider) {
            setSelectedModel(provider.defaultModel)
        }
    }

    fun setSelectedModel(model: String) {
        _selectedModel.value = model
        prefs.edit().putString(KEY_SELECTED_MODEL, model).apply()
    }

    // MARK: - Live AI Configuration

    fun getLiveAIAPIKey(apiKeyManager: com.turbometa.rayban.utils.APIKeyManager): String {
        return liveAIFetchedKey ?: apiKeyManager.getGoogleAPIKey() ?: ""
    }

    fun hasLiveAIAPIKey(apiKeyManager: com.turbometa.rayban.utils.APIKeyManager): Boolean {
        return getLiveAIAPIKey(apiKeyManager).isNotEmpty()
    }

    fun applyFetchedConfig(key: String, url: String, model: String) {
        liveAIFetchedKey = key
        liveAIFetchedURL = url
        liveAIFetchedModel = model
    }

    // MARK: - Get Current Configuration

    val currentBaseURL: String
        get() = _currentProvider.value.baseURL

    fun getCurrentAPIKey(apiKeyManager: com.turbometa.rayban.utils.APIKeyManager): String {
        return apiKeyManager.getAPIKey(_currentProvider.value) ?: ""
    }

    val currentModel: String
        get() = _selectedModel.value

    fun hasAPIKey(apiKeyManager: com.turbometa.rayban.utils.APIKeyManager): Boolean {
        return apiKeyManager.hasAPIKey(_currentProvider.value)
    }

    // MARK: - OpenRouter Models

    suspend fun fetchOpenRouterModels(apiKeyManager: com.turbometa.rayban.utils.APIKeyManager) {
        if (_currentProvider.value != APIProvider.OPENROUTER) return

        val apiKey = apiKeyManager.getAPIKey(APIProvider.OPENROUTER)
        if (apiKey.isNullOrEmpty()) {
            _modelsError.value = "Please configure OpenRouter API Key first"
            return
        }

        _isLoadingModels.value = true
        _modelsError.value = null

        withContext(Dispatchers.IO) {
            try {
                val request = Request.Builder()
                    .url("https://openrouter.ai/api/v1/models")
                    .addHeader("Authorization", "Bearer $apiKey")
                    .addHeader("X-Title", "TurboMeta")
                    .get()
                    .build()

                val response = httpClient.newCall(request).execute()

                if (!response.isSuccessful) {
                    _modelsError.value = "Failed to fetch models: ${response.code}"
                    return@withContext
                }

                val body = response.body?.string() ?: ""
                val modelsResponse = gson.fromJson(body, OpenRouterModelsResponse::class.java)

                // Sort models: vision-capable first, then by name
                _openRouterModels.value = modelsResponse.data.sortedWith(
                    compareByDescending<OpenRouterModel> { it.isVisionCapable }
                        .thenBy { it.displayName }
                )

                android.util.Log.d("APIProviderManager", "Loaded ${_openRouterModels.value.size} OpenRouter models")

            } catch (e: Exception) {
                _modelsError.value = e.message ?: "Unknown error"
                android.util.Log.e("APIProviderManager", "Failed to fetch OpenRouter models", e)
            }
        }

        _isLoadingModels.value = false
    }

    fun searchModels(query: String): List<OpenRouterModel> {
        if (query.isEmpty()) return _openRouterModels.value
        val lowercaseQuery = query.lowercase()
        return _openRouterModels.value.filter { model ->
            model.id.lowercase().contains(lowercaseQuery) ||
            model.displayName.lowercase().contains(lowercaseQuery) ||
            (model.description?.lowercase()?.contains(lowercaseQuery) == true)
        }
    }

    fun visionCapableModels(): List<OpenRouterModel> {
        return _openRouterModels.value.filter { it.isVisionCapable }
    }
}
