package com.ariaspark.metawearables.services

import android.content.Context
import android.util.Base64
import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.ariaspark.metawearables.managers.APIProviderManager
import com.ariaspark.metawearables.utils.APIKeyManager
import com.ariaspark.metawearables.utils.AIConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * AI Config Service
 * Fetches encrypted AI configuration from server and decrypts it
 * Protocol: POST {API_APP}/config/get → AES-256-CBC decrypt → { key, url, model }
 */
object AIConfigService {

    private const val TAG = "AIConfig"

    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()

    data class ConfigResult(
        val key: String,
        val url: String,
        val model: String
    )

    /**
     * Fetches and decrypts AI config from the server, then stores it.
     */
    suspend fun fetchConfig(context: Context): ConfigResult? = withContext(Dispatchers.IO) {
        try {
            val url = "${AIConfig.API_APP}/config/get"

            val body = gson.toJson(mapOf("id" to AIConfig.CONFIG_ID_AI_LIVE))
            val requestBody = body.toRequestBody("application/json".toMediaType())

            val request = Request.Builder()
                .url(url)
                .post(requestBody)
                .build()

            val response = client.newCall(request).execute()
            val responseBody = response.body?.string()

            if (!response.isSuccessful || responseBody == null) {
                Log.e(TAG, "Server returned HTTP ${response.code}")
                return@withContext null
            }

            // Parse response JSON to get "content" field
            val json = gson.fromJson(responseBody, JsonObject::class.java)
            val content = json.get("content")?.asString
            if (content == null || content.length <= 44) {
                Log.e(TAG, "Invalid response: content missing or too short")
                return@withContext null
            }

            // Split content: first 44 chars = AES key (Base64), rest = encrypted data (Base64)
            val keyBase64 = content.substring(0, 44)
            val encryptedBase64 = content.substring(44)

            // Decrypt
            val decrypted = decrypt(encryptedBase64, keyBase64, AIConfig.CONFIG_IV)
            if (decrypted == null) {
                Log.e(TAG, "Decryption failed")
                return@withContext null
            }

            // Parse decrypted JSON
            val configObj = gson.fromJson(decrypted, JsonObject::class.java)
            val key = configObj.get("key")?.asString
            val configUrl = configObj.get("url")?.asString
            val model = configObj.get("model")?.asString

            if (key == null || configUrl == null || model == null) {
                Log.e(TAG, "Missing fields in decrypted config")
                return@withContext null
            }

            val result = ConfigResult(key, configUrl, model)

            // Store in APIProviderManager and APIKeyManager
            val providerManager = APIProviderManager.getInstance(context)
            providerManager.applyFetchedConfig(key, configUrl, model)

            val apiKeyManager = APIKeyManager.getInstance(context)
            apiKeyManager.saveGoogleAPIKey(key)

            Log.i(TAG, "Successfully fetched and applied config")
            result

        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch config: ${e.message}")
            null
        }
    }

    // MARK: - AES-256-CBC Decryption

    private fun decrypt(encryptedBase64: String, keyBase64: String, ivBase64: String): String? {
        return try {
            val keyBytes = Base64.decode(keyBase64, Base64.DEFAULT)
            val ivBytes = Base64.decode(ivBase64, Base64.DEFAULT)
            val encryptedBytes = Base64.decode(encryptedBase64, Base64.DEFAULT)

            val secretKey = SecretKeySpec(keyBytes, "AES")
            val ivSpec = IvParameterSpec(ivBytes)

            val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
            cipher.init(Cipher.DECRYPT_MODE, secretKey, ivSpec)

            val decryptedBytes = cipher.doFinal(encryptedBytes)
            String(decryptedBytes, Charsets.UTF_8)
        } catch (e: Exception) {
            Log.e(TAG, "Decryption error: ${e.message}")
            null
        }
    }
}
