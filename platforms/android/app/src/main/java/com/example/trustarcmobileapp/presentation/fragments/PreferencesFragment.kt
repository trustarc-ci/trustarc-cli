package com.example.trustarcmobileapp.presentation.fragments

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.Toast
import androidx.fragment.app.Fragment
import com.example.trustarcmobileapp.R
import com.example.trustarcmobileapp.data.manager.ConsentManager
import com.example.trustarcmobileapp.presentation.views.AccordionView
import com.truste.androidmobileconsentsdk.TrustArc
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class PreferencesFragment : Fragment() {

    @Inject
    lateinit var consentManager: ConsentManager
    
    @Inject
    lateinit var trustArc: TrustArc

    private lateinit var accordionContainer: LinearLayout

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_preferences, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        
        accordionContainer = view.findViewById(R.id.accordionContainer)
        setupAccordions()
    }

    private fun setupAccordions() {
        setupConsentPreferencesAccordion()
        setupTcfStringAccordion()
        setupGoogleConsentsAccordion()
        setupWebScriptAccordion()
    }

    private fun setupConsentPreferencesAccordion() {
        val accordion = AccordionView(requireContext())
        accordion.setTitle("Consent Preferences")
        accordion.setOnExpandListener {
            accordion.showLoading()
            try {
                val consentPrefs = requireContext().getSharedPreferences("com.truste.androidmobileconsentsdk", Context.MODE_PRIVATE)
                val allPrefs = consentPrefs.all
                if (allPrefs.isNotEmpty()) {
                    val content = allPrefs.entries.joinToString("\n") { "${it.key}: ${it.value}" }
                    accordion.setContent(content)
                    accordion.setOnCopyClickListener {
                        copyToClipboard(content, "Consent Data Copied")
                    }
                } else {
                    accordion.setContent("(No Data)")
                }
            } catch (e: Exception) {
                accordion.setContent("Error loading data")
            }
            accordion.hideLoading()
        }
        accordionContainer.addView(accordion)
    }

    private fun setupTcfStringAccordion() {
        val accordion = AccordionView(requireContext())
        accordion.setTitle("IAB TCF String")
        accordion.setOnExpandListener {
            accordion.showLoading()
            try {
                val tcfString = trustArc.getTcfString()
                if (tcfString != null) {
                    if (tcfString.isNotEmpty()) {
                        accordion.setContent(tcfString)
                        accordion.setOnCopyClickListener {
                            copyToClipboard(tcfString, "TCF String Copied")
                        }
                    } else {
                        accordion.setContent("(No Data)")
                    }
                }
            } catch (e: Exception) {
                accordion.setContent("Error loading data: ${e.message}")
            }
            accordion.hideLoading()
        }
        accordionContainer.addView(accordion)
    }

    private fun setupGoogleConsentsAccordion() {
        val accordion = AccordionView(requireContext())
        accordion.setTitle("Google Consents")
        accordion.setOnExpandListener {
            accordion.showLoading()
            try {
                val googlePrefs = requireContext().getSharedPreferences("com.truste.androidmobileconsentsdk.google", Context.MODE_PRIVATE)
                val allPrefs = googlePrefs.all
                if (allPrefs.isNotEmpty()) {
                    val content = allPrefs.entries.joinToString("\n") { "${it.key}: ${it.value}" }
                    accordion.setContent(content)
                    accordion.setOnCopyClickListener {
                        copyToClipboard(content, "Google Consents Copied")
                    }
                } else {
                    accordion.setContent("(No Data)")
                }
            } catch (e: Exception) {
                accordion.setContent("Error loading data: ${e.message}")
            }
            accordion.hideLoading()
        }
        accordionContainer.addView(accordion)
    }

    private fun setupWebScriptAccordion() {
        val accordion = AccordionView(requireContext())
        accordion.setTitle("Consent Web Script")
        accordion.setOnExpandListener {
            accordion.showLoading()
            try {
                val webScriptPrefs = requireContext().getSharedPreferences("com.truste.androidmobileconsentsdk.webscript", Context.MODE_PRIVATE)
                val allPrefs = webScriptPrefs.all
                if (allPrefs.isNotEmpty()) {
                    val content = allPrefs.entries.joinToString("\n") { "${it.key}: ${it.value}" }
                    accordion.setContent(content)
                    accordion.setOnCopyClickListener {
                        copyToClipboard(content, "Web Script Copied")
                    }
                } else {
                    accordion.setContent("(No Data)")
                }
            } catch (e: Exception) {
                accordion.setContent("Error loading data: ${e.message}")
            }
            accordion.hideLoading()
        }
        accordionContainer.addView(accordion)
    }

    private fun copyToClipboard(data: String, message: String) {
        val clipboard = requireContext().getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("TrustArc Data", data)
        clipboard.setPrimaryClip(clip)
        Toast.makeText(requireContext(), message, Toast.LENGTH_SHORT).show()
    }
}