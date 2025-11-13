package com.example.trustarcmobileapp.di

import android.content.Context
import com.example.trustarcmobileapp.data.manager.ConsentManager
import com.example.trustarcmobileapp.data.manager.ConsentManagerImpl
import com.truste.androidmobileconsentsdk.SdkMode
import com.truste.androidmobileconsentsdk.TrustArc
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    @Provides
    @Singleton
    fun provideContext(@ApplicationContext context: Context): Context {
        return context
    }

    @Provides
    @Singleton
    fun provideTrustArc(@ApplicationContext appContext: Context): TrustArc {
        return TrustArc(appContext, SdkMode.Standard)
    }

    @Provides
    @Singleton
    fun provideConsentManager(consentManagerImpl: ConsentManagerImpl): ConsentManager {
        return consentManagerImpl
    }

}