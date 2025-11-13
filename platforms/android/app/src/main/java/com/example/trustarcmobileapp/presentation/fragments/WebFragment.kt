package com.example.trustarcmobileapp.presentation.fragments

import android.annotation.SuppressLint
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.fragment.app.Fragment
import com.example.trustarcmobileapp.R
import com.example.trustarcmobileapp.config.AppConfig
import com.truste.androidmobileconsentsdk.TrustArc
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class WebFragment : Fragment() {

    @Inject
    lateinit var trustArc: TrustArc

    private lateinit var webView: WebView

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_web, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        
        webView = view.findViewById(R.id.webView)
        setupWebView()
        webView.loadUrl(AppConfig.TEST_WEBSITE_URL)
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView() {
        webView.webViewClient = object : WebViewClient() {
            override fun onPageCommitVisible(view: WebView?, url: String?) {
                val script = trustArc.getWebScript()
                if (!script.isNullOrEmpty()) {
                    webView.evaluateJavascript(script) { javaScriptResult ->
                        Log.d("CONSENT SCRIPT", "Loaded script: $javaScriptResult")
                    }
                }
            }
        }

        webView.settings.run {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = true
            allowContentAccess = true
            builtInZoomControls = true
        }

        webView.isVerticalScrollBarEnabled = true
        webView.scrollBarStyle = WebView.SCROLLBARS_OUTSIDE_OVERLAY
        webView.isScrollbarFadingEnabled = false
    }
}