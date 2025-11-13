package com.example.trustarcmobileapp.presentation.views

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import com.example.trustarcmobileapp.R

class AccordionView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr) {

    private val titleTextView: TextView
    private val chevronIcon: ImageView
    private val contentContainer: LinearLayout
    private val contentScrollView: ScrollView
    private val contentTextView: TextView
    private val copyButton: Button
    private val progressBar: ProgressBar
    
    private var isExpanded = false
    private var onExpandListener: (() -> Unit)? = null
    private var onCopyClickListener: (() -> Unit)? = null

    init {
        orientation = VERTICAL
        LayoutInflater.from(context).inflate(R.layout.view_accordion, this, true)
        
        titleTextView = findViewById(R.id.tvAccordionTitle)
        chevronIcon = findViewById(R.id.ivChevron)
        contentContainer = findViewById(R.id.contentContainer)
        contentScrollView = findViewById(R.id.contentScrollView)
        contentTextView = findViewById(R.id.tvContent)
        copyButton = findViewById(R.id.btnCopy)
        progressBar = findViewById(R.id.progressBar)
        
        setupClickListeners()
    }

    private fun setupClickListeners() {
        val headerContainer = findViewById<LinearLayout>(R.id.headerContainer)
        headerContainer.setOnClickListener {
            toggleExpansion()
        }
        
        copyButton.setOnClickListener {
            onCopyClickListener?.invoke()
        }
    }

    private fun toggleExpansion() {
        isExpanded = !isExpanded
        
        if (isExpanded) {
            contentContainer.visibility = View.VISIBLE
            chevronIcon.rotation = 180f
            onExpandListener?.invoke()
        } else {
            contentContainer.visibility = View.GONE
            chevronIcon.rotation = 0f
        }
    }

    fun setTitle(title: String) {
        titleTextView.text = title
    }

    fun setContent(content: String) {
        contentTextView.text = content
        copyButton.visibility = if (content == "(No Data)" || content.startsWith("Error")) View.GONE else View.VISIBLE
    }

    fun setOnExpandListener(listener: () -> Unit) {
        onExpandListener = listener
    }

    fun setOnCopyClickListener(listener: () -> Unit) {
        onCopyClickListener = listener
    }

    fun showLoading() {
        progressBar.visibility = View.VISIBLE
        contentScrollView.visibility = View.GONE
        copyButton.visibility = View.GONE
    }

    fun hideLoading() {
        progressBar.visibility = View.GONE
        contentScrollView.visibility = View.VISIBLE
    }
}