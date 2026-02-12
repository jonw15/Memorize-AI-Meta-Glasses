package com.turbometa.rayban

import android.app.Application
import android.util.Log
import com.turbometa.rayban.services.AIConfigService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class TurboMetaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this

        // Auto-fetch AI config from server
        CoroutineScope(Dispatchers.IO).launch {
            try {
                AIConfigService.fetchConfig(this@TurboMetaApplication)
            } catch (e: Exception) {
                Log.e("TurboMeta", "AI config fetch failed: ${e.message}")
            }
        }
    }

    companion object {
        lateinit var instance: TurboMetaApplication
            private set
    }
}
