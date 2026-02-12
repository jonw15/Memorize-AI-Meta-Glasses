package com.ariaspark.metawearables

import android.app.Application
import android.util.Log
import com.ariaspark.metawearables.services.AIConfigService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class AriaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this

        // Auto-fetch AI config from server
        CoroutineScope(Dispatchers.IO).launch {
            try {
                AIConfigService.fetchConfig(this@AriaApplication)
            } catch (e: Exception) {
                Log.e("Aria", "AI config fetch failed: ${e.message}")
            }
        }
    }

    companion object {
        lateinit var instance: AriaApplication
            private set
    }
}
