package com.turbometa.rayban.viewmodels

import android.app.Application
import android.graphics.Bitmap
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.turbometa.rayban.data.ConversationStorage
import com.turbometa.rayban.managers.APIProviderManager
import com.turbometa.rayban.models.ConversationMessage
import com.turbometa.rayban.models.ConversationRecord
import com.turbometa.rayban.models.MessageRole
import com.turbometa.rayban.services.GeminiLiveService
import com.turbometa.rayban.utils.APIKeyManager
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * OmniRealtimeViewModel
 * Uses Google Gemini Live for real-time AI conversation
 * 1:1 port from iOS OmniRealtimeViewModel
 */
class OmniRealtimeViewModel(application: Application) : AndroidViewModel(application) {

    companion object {
        private const val TAG = "OmniRealtimeViewModel"
    }

    private val apiKeyManager = APIKeyManager.getInstance(application)
    private val providerManager = APIProviderManager.getInstance(application)
    private val conversationStorage = ConversationStorage.getInstance(application)

    // Service
    private var geminiService: GeminiLiveService? = null

    // State
    sealed class ViewState {
        object Idle : ViewState()
        object Connecting : ViewState()
        object Connected : ViewState()
        object Recording : ViewState()
        object Processing : ViewState()
        object Speaking : ViewState()
        data class Error(val message: String) : ViewState()
    }

    private val _viewState = MutableStateFlow<ViewState>(ViewState.Idle)
    val viewState: StateFlow<ViewState> = _viewState.asStateFlow()

    private val _messages = MutableStateFlow<List<ConversationMessage>>(emptyList())
    val messages: StateFlow<List<ConversationMessage>> = _messages.asStateFlow()

    private val _currentTranscript = MutableStateFlow("")
    val currentTranscript: StateFlow<String> = _currentTranscript.asStateFlow()

    private val _userTranscript = MutableStateFlow("")
    val userTranscript: StateFlow<String> = _userTranscript.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private val _isRecording = MutableStateFlow(false)
    val isRecording: StateFlow<Boolean> = _isRecording.asStateFlow()

    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking.asStateFlow()

    // Periodic image sending
    private val _imageSendInterval = MutableStateFlow(1.0)
    val imageSendInterval: StateFlow<Double> = _imageSendInterval.asStateFlow()

    private var imageSendJob: Job? = null
    private var isImageSendingEnabled = false
    private var currentVideoFrame: Bitmap? = null

    private var currentSessionId: String = UUID.randomUUID().toString()
    private var pendingVideoFrame: Bitmap? = null

    init {
        initializeService()
    }

    private fun initializeService() {
        val apiKey = providerManager.getLiveAIAPIKey(apiKeyManager)
        val language = apiKeyManager.getOutputLanguage()

        if (apiKey.isBlank()) {
            _errorMessage.value = "API Key not configured for Google Gemini"
            Log.e(TAG, "API Key not configured for Google Gemini")
            return
        }

        Log.d(TAG, "Initializing Gemini Live service")

        val model = APIProviderManager.liveAIDefaultModel

        geminiService = GeminiLiveService(apiKey, model, language, getApplication()).apply {
            onTranscriptDelta = { delta ->
                _currentTranscript.value += delta
            }

            onTranscriptDone = { transcript ->
                if (transcript.isNotBlank()) {
                    addAssistantMessage(_currentTranscript.value.ifBlank { transcript })
                }
                _currentTranscript.value = ""
                _viewState.value = ViewState.Connected
            }

            onUserTranscript = { transcript ->
                if (transcript.isNotBlank()) {
                    _userTranscript.value = transcript
                    addUserMessage(transcript)
                }
            }

            onSpeechStarted = {
                _viewState.value = ViewState.Recording
            }

            onSpeechStopped = {
                _viewState.value = ViewState.Processing
            }

            onError = { error ->
                _errorMessage.value = error
                _viewState.value = ViewState.Error(error)
            }

            onConnected = {
                _isConnected.value = true
                _viewState.value = ViewState.Connected
            }

            onFirstAudioSent = {
                // Start periodic image sending after a 1s delay (matching iOS)
                viewModelScope.launch {
                    Log.d(TAG, "Received first audio send callback, starting periodic image sending")
                    delay(1000)
                    isImageSendingEnabled = true
                    startImageSendTimer()
                    Log.d(TAG, "Periodic image sending started")
                }
            }
        }

        observeGeminiServiceStates()
    }

    private fun observeGeminiServiceStates() {
        viewModelScope.launch {
            geminiService?.isConnected?.collect { connected ->
                _isConnected.value = connected
                if (connected && _viewState.value == ViewState.Connecting) {
                    _viewState.value = ViewState.Connected
                } else if (!connected && _viewState.value != ViewState.Idle) {
                    _viewState.value = ViewState.Idle
                }
            }
        }

        viewModelScope.launch {
            geminiService?.isRecording?.collect { recording ->
                _isRecording.value = recording
            }
        }

        viewModelScope.launch {
            geminiService?.isSpeaking?.collect { speaking ->
                _isSpeaking.value = speaking
                if (speaking) {
                    _viewState.value = ViewState.Speaking
                }
            }
        }
    }

    // MARK: - Periodic Image Sending

    private fun startImageSendTimer() {
        stopImageSendTimer()
        imageSendJob = viewModelScope.launch {
            while (true) {
                delay(((_imageSendInterval.value) * 1000).toLong())
                if (isImageSendingEnabled) {
                    currentVideoFrame?.let { frame ->
                        geminiService?.sendImageInput(frame)
                    }
                }
            }
        }
    }

    private fun stopImageSendTimer() {
        imageSendJob?.cancel()
        imageSendJob = null
    }

    fun setImageSendInterval(interval: Double) {
        _imageSendInterval.value = interval
        // Restart timer with new interval if currently sending
        if (isImageSendingEnabled) {
            startImageSendTimer()
        }
    }

    fun connect() {
        viewModelScope.launch {
            if (_isConnected.value) return@launch

            _viewState.value = ViewState.Connecting
            _messages.value = emptyList()
            currentSessionId = UUID.randomUUID().toString()

            geminiService?.connect()
        }
    }

    fun disconnect() {
        viewModelScope.launch {
            saveCurrentConversation()
            stopImageSendTimer()
            isImageSendingEnabled = false
            geminiService?.disconnect()
            _viewState.value = ViewState.Idle
            _isConnected.value = false
            _messages.value = emptyList()
            _currentTranscript.value = ""
            _userTranscript.value = ""
        }
    }

    fun startRecording() {
        if (!_isConnected.value) {
            _errorMessage.value = "Not connected"
            return
        }

        // Update video frame if available
        pendingVideoFrame?.let { frame ->
            geminiService?.updateVideoFrame(frame)
        }

        geminiService?.startRecording()
        _viewState.value = ViewState.Recording
    }

    fun stopRecording() {
        geminiService?.stopRecording()
        stopImageSendTimer()
        isImageSendingEnabled = false
        if (_viewState.value == ViewState.Recording) {
            _viewState.value = ViewState.Processing
        }
    }

    fun updateVideoFrame(frame: Bitmap) {
        pendingVideoFrame = frame
        currentVideoFrame = frame
        geminiService?.updateVideoFrame(frame)
    }

    fun sendImage(image: Bitmap) {
        geminiService?.sendImageInput(image)
    }

    private fun addUserMessage(text: String) {
        val message = ConversationMessage(
            id = UUID.randomUUID().toString(),
            role = MessageRole.USER,
            content = text,
            timestamp = System.currentTimeMillis()
        )
        _messages.value = _messages.value + message
    }

    private fun addAssistantMessage(text: String) {
        val message = ConversationMessage(
            id = UUID.randomUUID().toString(),
            role = MessageRole.ASSISTANT,
            content = text,
            timestamp = System.currentTimeMillis()
        )
        _messages.value = _messages.value + message
    }

    private fun saveCurrentConversation() {
        if (_messages.value.isEmpty()) return

        val record = ConversationRecord(
            id = currentSessionId,
            timestamp = System.currentTimeMillis(),
            messages = _messages.value,
            aiModel = APIProviderManager.liveAIDefaultModel,
            language = apiKeyManager.getOutputLanguage()
        )

        conversationStorage.saveConversation(record)
    }

    fun clearError() {
        _errorMessage.value = null
        geminiService?.clearError()
        if (_viewState.value is ViewState.Error) {
            _viewState.value = if (_isConnected.value) ViewState.Connected else ViewState.Idle
        }
    }

    fun refreshService() {
        disconnect()
        geminiService = null
        initializeService()
    }

    override fun onCleared() {
        super.onCleared()
        saveCurrentConversation()
        stopImageSendTimer()
        geminiService?.disconnect()
    }
}
