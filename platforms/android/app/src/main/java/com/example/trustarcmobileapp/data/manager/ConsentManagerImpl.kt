package com.example.trustarcmobileapp.data.manager

import android.util.Log
import com.example.trustarcmobileapp.config.AppConfig
import com.truste.androidmobileconsentsdk.TrustArc
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ConsentManagerImpl @Inject constructor(
    private val trustArc: TrustArc
) : ConsentManager {
    
    private var isInitialized = false
    
    override fun initialize() {
        if (isInitialized) {
            Log.d("ConsentManager", "TrustArc already initialized, skipping")
            return
        }
        
        Log.d("ConsentManager", "Initializing TrustArc SDK")
//        trustArc.useGdprDetection(false)
        trustArc.enableDebugLog(true)
        trustArc.start(domainName = AppConfig.MAC_DOMAIN)
        isInitialized = true
    }
}