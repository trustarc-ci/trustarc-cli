package com.example.trustarcmobileapp.presentation

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.navigation.NavController
import androidx.navigation.fragment.NavHostFragment
import androidx.navigation.ui.setupWithNavController
import com.example.trustarcmobileapp.R
import com.example.trustarcmobileapp.data.manager.ConsentManager
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.truste.androidmobileconsentsdk.TrustArc
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : AppCompatActivity() {

    @Inject
    lateinit var consentManager: ConsentManager
    
    @Inject
    lateinit var trustArc: TrustArc

    private lateinit var navController: NavController

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main_with_navigation)
        
        setupNavigation()
        
        // TrustArc initialization moved to MyApplication.onCreate()
    }

    private fun setupNavigation() {
        val navHostFragment = supportFragmentManager
            .findFragmentById(R.id.nav_host_fragment) as NavHostFragment
        navController = navHostFragment.navController
        
        val bottomNavigationView = findViewById<BottomNavigationView>(R.id.bottom_navigation)
        bottomNavigationView.setupWithNavController(navController)
    }
}