package com.example.trustarcmobileapp

import android.app.Application
import com.example.trustarcmobileapp.data.manager.ConsentManager
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class MyApplication : Application() {
    
    @Inject
    lateinit var consentManager: ConsentManager
    
    override fun onCreate() {
        super.onCreate()
        // Initialize TrustArc SDK once when app starts
        consentManager.initialize()
    }
}