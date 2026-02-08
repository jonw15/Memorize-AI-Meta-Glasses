package com.turbometa.rayban.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.turbometa.rayban.data.ConversationStorage
import com.turbometa.rayban.managers.APIProvider
import com.turbometa.rayban.managers.APIProviderManager
import com.turbometa.rayban.managers.AppLanguage
import com.turbometa.rayban.managers.GoogleVisionModel
import com.turbometa.rayban.managers.LanguageManager
import com.turbometa.rayban.managers.OpenRouterModel
import com.turbometa.rayban.utils.APIKeyManager
import com.turbometa.rayban.utils.OutputLanguage
import com.turbometa.rayban.utils.StreamQuality
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * SettingsViewModel
 * Supports multi-provider configuration (Google AI Studio / OpenRouter)
 * 1:1 port from iOS settings structure
 */
class SettingsViewModel(application: Application) : AndroidViewModel(application) {

    private val apiKeyManager = APIKeyManager.getInstance(application)
    private val providerManager = APIProviderManager.getInstance(application)
    private val conversationStorage = ConversationStorage.getInstance(application)

    // Vision API Provider
    private val _visionProvider = MutableStateFlow(providerManager.currentProvider.value)
    val visionProvider: StateFlow<APIProvider> = _visionProvider.asStateFlow()

    // API Keys status
    private val _hasOpenRouterKey = MutableStateFlow(apiKeyManager.hasAPIKey(APIProvider.OPENROUTER))
    val hasOpenRouterKey: StateFlow<Boolean> = _hasOpenRouterKey.asStateFlow()

    private val _hasGoogleKey = MutableStateFlow(apiKeyManager.hasGoogleAPIKey())
    val hasGoogleKey: StateFlow<Boolean> = _hasGoogleKey.asStateFlow()

    // Legacy hasApiKey for backward compatibility
    private val _hasApiKey = MutableStateFlow(apiKeyManager.hasAPIKey())
    val hasApiKey: StateFlow<Boolean> = _hasApiKey.asStateFlow()

    private val _apiKeyMasked = MutableStateFlow(getMaskedApiKey())
    val apiKeyMasked: StateFlow<String> = _apiKeyMasked.asStateFlow()

    // AI Model (for Live AI)
    private val _selectedModel = MutableStateFlow(APIProviderManager.liveAIDefaultModel)
    val selectedModel: StateFlow<String> = _selectedModel.asStateFlow()

    // Vision Model
    private val _selectedVisionModel = MutableStateFlow(providerManager.selectedModel.value)
    val selectedVisionModel: StateFlow<String> = _selectedVisionModel.asStateFlow()

    // Output Language
    private val _selectedLanguage = MutableStateFlow(apiKeyManager.getOutputLanguage())
    val selectedLanguage: StateFlow<String> = _selectedLanguage.asStateFlow()

    // Video Quality
    private val _selectedQuality = MutableStateFlow(apiKeyManager.getVideoQuality())
    val selectedQuality: StateFlow<String> = _selectedQuality.asStateFlow()

    // Conversation count
    private val _conversationCount = MutableStateFlow(conversationStorage.getConversationCount())
    val conversationCount: StateFlow<Int> = _conversationCount.asStateFlow()

    // Error/Success messages
    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    // Dialog states
    private val _showApiKeyDialog = MutableStateFlow(false)
    val showApiKeyDialog: StateFlow<Boolean> = _showApiKeyDialog.asStateFlow()

    private val _showModelDialog = MutableStateFlow(false)
    val showModelDialog: StateFlow<Boolean> = _showModelDialog.asStateFlow()

    private val _showLanguageDialog = MutableStateFlow(false)
    val showLanguageDialog: StateFlow<Boolean> = _showLanguageDialog.asStateFlow()

    private val _showQualityDialog = MutableStateFlow(false)
    val showQualityDialog: StateFlow<Boolean> = _showQualityDialog.asStateFlow()

    private val _showDeleteConfirmDialog = MutableStateFlow(false)
    val showDeleteConfirmDialog: StateFlow<Boolean> = _showDeleteConfirmDialog.asStateFlow()

    private val _showVisionProviderDialog = MutableStateFlow(false)
    val showVisionProviderDialog: StateFlow<Boolean> = _showVisionProviderDialog.asStateFlow()

    // App Language
    private val _appLanguage = MutableStateFlow(LanguageManager.getCurrentLanguage())
    val appLanguage: StateFlow<AppLanguage> = _appLanguage.asStateFlow()

    private val _showAppLanguageDialog = MutableStateFlow(false)
    val showAppLanguageDialog: StateFlow<Boolean> = _showAppLanguageDialog.asStateFlow()

    private val _showVisionModelDialog = MutableStateFlow(false)
    val showVisionModelDialog: StateFlow<Boolean> = _showVisionModelDialog.asStateFlow()

    // Vision Model selection - expose provider manager states
    val openRouterModels: StateFlow<List<OpenRouterModel>> = providerManager.openRouterModels
    val isLoadingModels: StateFlow<Boolean> = providerManager.isLoadingModels
    val modelsError: StateFlow<String?> = providerManager.modelsError

    // Current editing key type
    private val _editingKeyType = MutableStateFlow<EditingKeyType?>(null)
    val editingKeyType: StateFlow<EditingKeyType?> = _editingKeyType.asStateFlow()

    enum class EditingKeyType {
        GOOGLE,
        OPENROUTER
    }

    init {
        observeProviderChanges()
    }

    private fun observeProviderChanges() {
        viewModelScope.launch {
            providerManager.currentProvider.collect { provider ->
                _visionProvider.value = provider
                refreshApiKeyStatus()
            }
        }
    }

    private fun refreshApiKeyStatus() {
        _hasOpenRouterKey.value = apiKeyManager.hasAPIKey(APIProvider.OPENROUTER)
        _hasGoogleKey.value = apiKeyManager.hasGoogleAPIKey()
        _hasApiKey.value = apiKeyManager.hasAPIKey()
        _apiKeyMasked.value = getMaskedApiKey()
    }

    // MARK: - Vision Provider

    fun showVisionProviderDialog() {
        _showVisionProviderDialog.value = true
    }

    fun hideVisionProviderDialog() {
        _showVisionProviderDialog.value = false
    }

    fun selectVisionProvider(provider: APIProvider) {
        providerManager.setCurrentProvider(provider)
        _visionProvider.value = provider
        _showVisionProviderDialog.value = false
        _message.value = "Vision API switched to ${provider.displayName}"
        refreshApiKeyStatus()
    }

    // MARK: - API Key Management

    fun showApiKeyDialog() {
        _showApiKeyDialog.value = true
    }

    fun hideApiKeyDialog() {
        _showApiKeyDialog.value = false
        _editingKeyType.value = null
    }

    fun showApiKeyDialogForType(type: EditingKeyType) {
        _editingKeyType.value = type
        _showApiKeyDialog.value = true
    }

    fun saveApiKey(apiKey: String): Boolean {
        val trimmedKey = apiKey.trim()
        if (trimmedKey.isBlank()) {
            _message.value = "API Key cannot be empty"
            return false
        }

        val success = when (_editingKeyType.value) {
            EditingKeyType.GOOGLE -> apiKeyManager.saveGoogleAPIKey(trimmedKey)
            EditingKeyType.OPENROUTER -> apiKeyManager.saveAPIKey(trimmedKey, APIProvider.OPENROUTER)
            null -> apiKeyManager.saveAPIKey(trimmedKey)
        }

        if (success) {
            refreshApiKeyStatus()
            _message.value = "API Key saved successfully"
            _showApiKeyDialog.value = false
            _editingKeyType.value = null
        } else {
            _message.value = "Failed to save API Key"
        }
        return success
    }

    fun deleteApiKey(): Boolean {
        val success = when (_editingKeyType.value) {
            EditingKeyType.GOOGLE -> apiKeyManager.deleteGoogleAPIKey()
            EditingKeyType.OPENROUTER -> apiKeyManager.deleteAPIKey(APIProvider.OPENROUTER)
            null -> apiKeyManager.deleteAPIKey()
        }

        if (success) {
            refreshApiKeyStatus()
            _message.value = "API Key deleted"
        } else {
            _message.value = "Failed to delete API Key"
        }
        return success
    }

    fun getAvailableLanguages(): List<OutputLanguage> = OutputLanguage.entries

    private fun getMaskedApiKey(): String {
        val apiKey = apiKeyManager.getAPIKey() ?: return ""
        if (apiKey.length <= 8) return "****"
        return "${apiKey.take(4)}****${apiKey.takeLast(4)}"
    }

    fun getMaskedKeyForType(type: EditingKeyType): String {
        val key = when (type) {
            EditingKeyType.GOOGLE -> apiKeyManager.getGoogleAPIKey()
            EditingKeyType.OPENROUTER -> apiKeyManager.getAPIKey(APIProvider.OPENROUTER)
        } ?: return ""
        if (key.length <= 8) return "****"
        return "${key.take(4)}****${key.takeLast(4)}"
    }

    fun getCurrentKeyForType(type: EditingKeyType): String {
        return when (type) {
            EditingKeyType.GOOGLE -> apiKeyManager.getGoogleAPIKey()
            EditingKeyType.OPENROUTER -> apiKeyManager.getAPIKey(APIProvider.OPENROUTER)
        } ?: ""
    }

    // AI Model Management
    fun showModelDialog() {
        _showModelDialog.value = true
    }

    fun hideModelDialog() {
        _showModelDialog.value = false
    }

    fun getSelectedModelDisplayName(): String {
        return _selectedModel.value
    }

    // Language Management
    fun showLanguageDialog() {
        _showLanguageDialog.value = true
    }

    fun hideLanguageDialog() {
        _showLanguageDialog.value = false
    }

    fun selectLanguage(language: OutputLanguage) {
        apiKeyManager.saveOutputLanguage(language.code)
        _selectedLanguage.value = language.code
        _showLanguageDialog.value = false
        _message.value = "Language changed to ${language.displayName}"
    }

    // App Language Functions
    fun showAppLanguageDialog() {
        _showAppLanguageDialog.value = true
    }

    fun hideAppLanguageDialog() {
        _showAppLanguageDialog.value = false
    }

    fun selectAppLanguage(language: AppLanguage) {
        LanguageManager.setLanguage(getApplication(), language)
        _appLanguage.value = language
        _showAppLanguageDialog.value = false

        // Auto-sync output language with app language
        val outputLangCode = when (language) {
            AppLanguage.CHINESE -> "zh-CN"
            AppLanguage.ENGLISH -> "en-US"
            AppLanguage.SYSTEM -> {
                // Detect system language
                val systemLocale = java.util.Locale.getDefault()
                if (systemLocale.language == "zh") "zh-CN" else "en-US"
            }
        }
        apiKeyManager.saveOutputLanguage(outputLangCode)
        _selectedLanguage.value = outputLangCode

        _message.value = "App language changed to ${language.displayName}"
    }

    fun getAppLanguageDisplayName(): String {
        return when (_appLanguage.value) {
            AppLanguage.SYSTEM -> "System"
            AppLanguage.CHINESE -> "中文"
            AppLanguage.ENGLISH -> "English"
        }
    }

    fun getAvailableAppLanguages(): List<AppLanguage> = LanguageManager.getAvailableLanguages()

    // Vision Model Functions
    fun showVisionModelDialog() {
        _showVisionModelDialog.value = true
        // Auto-fetch OpenRouter models when dialog opens
        if (_visionProvider.value == APIProvider.OPENROUTER) {
            fetchOpenRouterModels()
        }
    }

    fun hideVisionModelDialog() {
        _showVisionModelDialog.value = false
    }

    fun selectVisionModel(modelId: String) {
        providerManager.setSelectedModel(modelId)
        _selectedVisionModel.value = modelId
        _showVisionModelDialog.value = false
        _message.value = "Model changed to $modelId"
    }

    fun fetchOpenRouterModels() {
        viewModelScope.launch {
            providerManager.fetchOpenRouterModels(apiKeyManager)
        }
    }

    fun searchOpenRouterModels(query: String): List<OpenRouterModel> {
        return providerManager.searchModels(query)
    }

    fun getGoogleVisionModels(): List<GoogleVisionModel> {
        return GoogleVisionModel.availableModels
    }

    fun getSelectedVisionModelDisplayName(): String {
        val modelId = _selectedVisionModel.value
        // Check Google models first
        GoogleVisionModel.availableModels.find { it.id == modelId }?.let {
            return it.displayName
        }
        // Otherwise return the model ID (for OpenRouter models)
        return modelId
    }

    fun getSelectedLanguageDisplayName(): String {
        val langCode = _selectedLanguage.value
        return OutputLanguage.entries.find { it.code == langCode }?.let {
            "${it.nativeName} (${it.displayName})"
        } ?: langCode
    }

    // Video Quality Management
    fun getAvailableQualities(): List<StreamQuality> = StreamQuality.entries

    fun showQualityDialog() {
        _showQualityDialog.value = true
    }

    fun hideQualityDialog() {
        _showQualityDialog.value = false
    }

    fun selectQuality(quality: StreamQuality) {
        apiKeyManager.saveVideoQuality(quality.id)
        _selectedQuality.value = quality.id
        _showQualityDialog.value = false
        _message.value = "Video quality changed"
    }

    fun getSelectedQuality(): StreamQuality {
        val qualityId = _selectedQuality.value
        return StreamQuality.entries.find { it.id == qualityId } ?: StreamQuality.MEDIUM
    }

    // Conversation Management
    fun showDeleteConfirmDialog() {
        _showDeleteConfirmDialog.value = true
    }

    fun hideDeleteConfirmDialog() {
        _showDeleteConfirmDialog.value = false
    }

    fun deleteAllConversations() {
        viewModelScope.launch {
            val success = conversationStorage.deleteAllConversations()
            if (success) {
                _conversationCount.value = 0
                _message.value = "All conversations deleted"
            } else {
                _message.value = "Failed to delete conversations"
            }
            _showDeleteConfirmDialog.value = false
        }
    }

    fun refreshConversationCount() {
        _conversationCount.value = conversationStorage.getConversationCount()
    }

    // Message handling
    fun clearMessage() {
        _message.value = null
    }

    // Get current API key (for editing)
    fun getCurrentApiKey(): String {
        return when (_editingKeyType.value) {
            EditingKeyType.GOOGLE -> apiKeyManager.getGoogleAPIKey()
            EditingKeyType.OPENROUTER -> apiKeyManager.getAPIKey(APIProvider.OPENROUTER)
            null -> apiKeyManager.getAPIKey()
        } ?: ""
    }
}
