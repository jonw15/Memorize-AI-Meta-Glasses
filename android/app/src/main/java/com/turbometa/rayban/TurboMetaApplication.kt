package com.turbometa.rayban

import android.app.Application
import android.util.Log
import com.turbometa.rayban.services.LiveAIConfigService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class TurboMetaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this

        // Auto-fetch Live AI config from server
        CoroutineScope(Dispatchers.IO).launch {
            try {
                LiveAIConfigService.fetchConfig(this@TurboMetaApplication)
            } catch (e: Exception) {
                Log.e("TurboMeta", "Live AI config fetch failed: ${e.message}")
            }
        }
    }

    companion object {
        lateinit var instance: TurboMetaApplication
            private set
    }
}
