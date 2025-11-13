//
//  PreferencesView.swift
//  TrustArcMobileApp
//
//  Created by TrustArc on 3/12/25.
//

import SwiftUI
import trustarc_consent_sdk

struct PreferencesView: View {
    @StateObject private var preferencesViewModel = PreferencesViewModel()
    @State private var showCopyAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView {
                VStack(spacing: 10) {
                    consentPreferencesAccordion
                    tcfStringAccordion
                    googleConsentsAccordion
                    webScriptAccordion
                }
                .padding(16)
            }
        }
        .background(Color(UIColor.systemGroupedBackground)) // Adapts to dark mode
        .onAppear {
            preferencesViewModel.loadPreferences()
        }
        .alert("Text Copied", isPresented: $showCopyAlert) {
            Button("OK") { }
        } message: {
            Text("The content has been copied to the clipboard.")
        }
    }

    private var headerView: some View {
        VStack {
            Text("Preferences")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemIndigo)) // Adapts to dark mode
    }

    private var consentPreferencesAccordion: some View {
        AccordionView(
            title: "Consent Preferences",
            isExpanded: preferencesViewModel.expandedSection == "ConsentPreferences",
            isLoading: preferencesViewModel.loadingSection == "ConsentPreferences",
            onToggle: {
                preferencesViewModel.toggleAccordion("ConsentPreferences")
            }
        ) {
            if let consentData = preferencesViewModel.consentData, !consentData.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    CopyButton(
                        text: "Click here to copy the contents",
                        data: consentData.description,
                        onCopy: { showCopyAlert = true }
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Array(consentData.keys.sorted()), id: \.self) { key in
                                Text("\(key): \(consentData[key] ?? "")")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(UIColor.secondaryLabel)) // Adapts to dark mode
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            } else {
                Text("(No Data)")
                    .font(.system(size: 14))
                    .foregroundColor(Color(UIColor.secondaryLabel)) // Adapts to dark mode
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var tcfStringAccordion: some View {
        AccordionView(
            title: "IAB TCF String",
            isExpanded: preferencesViewModel.expandedSection == "IABTCFString",
            isLoading: preferencesViewModel.loadingSection == "IABTCFString",
            onToggle: {
                preferencesViewModel.toggleAccordion("IABTCFString")
            }
        ) {
            if let tcfString = preferencesViewModel.tcfString, !tcfString.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    CopyButton(
                        text: "Click here to copy the contents",
                        data: tcfString,
                        onCopy: { showCopyAlert = true }
                    )

                    ScrollView {
                        Text(tcfString)
                            .font(.system(size: 14))
                            .foregroundColor(Color(UIColor.secondaryLabel)) // Adapts to dark mode
                    }
                    .frame(maxHeight: 300)
                }
            } else {
                Text("(No Data)")
                    .font(.system(size: 14))
                    .foregroundColor(Color(UIColor.secondaryLabel)) // Adapts to dark mode
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var googleConsentsAccordion: some View {
        AccordionView(
            title: "Google Consents",
            isExpanded: preferencesViewModel.expandedSection == "GoogleConsents",
            isLoading: preferencesViewModel.loadingSection == "GoogleConsents",
            onToggle: {
                preferencesViewModel.toggleAccordion("GoogleConsents")
            }
        ) {
            if let googleConsents = preferencesViewModel.googleConsents, !googleConsents.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    CopyButton(
                        text: "Click here to copy the contents",
                        data: googleConsents,
                        onCopy: { showCopyAlert = true }
                    )

                    ScrollView {
                        Text(googleConsents)
                            .font(.system(size: 14))
                            .foregroundColor(Color(UIColor.secondaryLabel)) // Adapts to dark mode
                    }
                    .frame(maxHeight: 300)
                }
            } else {
                Text("(No Data)")
                    .font(.system(size: 14))
                    .foregroundColor(Color(UIColor.secondaryLabel)) // Adapts to dark mode
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var webScriptAccordion: some View {
        AccordionView(
            title: "Consent Web Script",
            isExpanded: preferencesViewModel.expandedSection == "WebScript",
            isLoading: preferencesViewModel.loadingSection == "WebScript",
            onToggle: {
                preferencesViewModel.toggleAccordion("WebScript")
            }
        ) {
            if let webScript = preferencesViewModel.webScript, !webScript.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    CopyButton(
                        text: "Click here to copy the contents",
                        data: webScript,
                        onCopy: { showCopyAlert = true }
                    )

                    ScrollView {
                        Text(webScript)
                            .font(.system(size: 14))
                            .foregroundColor(Color(UIColor.secondaryLabel)) // Adapts to dark mode
                    }
                    .frame(maxHeight: 300)
                }
            } else {
                Text("(No Data)")
                    .font(.system(size: 14))
                    .foregroundColor(Color(UIColor.secondaryLabel)) // Adapts to dark mode
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct AccordionView<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let isLoading: Bool
    let onToggle: () -> Void
    let content: Content
    
    init(title: String, isExpanded: Bool, isLoading: Bool, onToggle: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isExpanded = isExpanded
        self.isLoading = isLoading
        self.onToggle = onToggle
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(UIColor.label)) // Adapts to dark mode

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 18))
                        .foregroundColor(Color(UIColor.systemBlue)) // Adapts to dark mode
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor.systemBlue)))
                            .scaleEffect(0.8)
                            .padding()
                    } else {
                        content
                            .padding(.vertical, 10)
                            .padding(.leading, 10)
                    }
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(Color(UIColor.secondarySystemBackground)) // Adapts to dark mode
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(UIColor.separator), lineWidth: 1) // Adapts to dark mode
        )
        .cornerRadius(10)
    }
}

struct CopyButton: View {
    let text: String
    let data: String
    let onCopy: () -> Void
    
    var body: some View {
        Button(action: {
            UIPasteboard.general.string = data
            onCopy()
        }) {
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(Color(UIColor.systemBlue)) // Adapts to dark mode
                .cornerRadius(10)
        }
    }
}

struct ConsentPreference {
    let key: String
    let value: String
    let description: String
}

@MainActor
class PreferencesViewModel: ObservableObject {
    @Published var consentData: [String: String]?
    @Published var tcfString: String?
    @Published var googleConsents: String?
    @Published var webScript: String?
    @Published var expandedSection: String?
    @Published var loadingSection: String?
    
    func loadPreferences() {
        // Initial load - don't fetch data yet, wait for user to expand sections
    }
    
    func toggleAccordion(_ section: String) {
        if expandedSection == section {
            expandedSection = nil // Collapse
        } else {
            expandedSection = section // Expand and fetch data
            fetchData(for: section)
        }
    }
    
    private func fetchData(for section: String) {
        loadingSection = section
        
        Task {
            do {
                switch section {
                case "ConsentPreferences":
                    await fetchConsentPreferences()
                case "IABTCFString":
                    await fetchTCFString()
                case "GoogleConsents":
                    await fetchGoogleConsents()
                case "WebScript":
                    await fetchWebScript()
                default:
                    break
                }
            }
            
            await MainActor.run {
                self.loadingSection = nil
            }
        }
    }
    
    private func fetchConsentPreferences() async {
        // Get consent data from TrustArc SDK
        let consentDataByCategory = TrustArc.sharedInstance.getConsentDataByCategory()
        
        var data: [String: String] = [:]
        
        if let consents = consentDataByCategory as? [String: TAConsent] {
            for (key, consent) in consents {
                let hasConsent = consent.domains?.contains { domain in
                    domain.values.contains("1")
                } ?? false
                
                data[key] = hasConsent ? "1" : "0"
            }
        }
        
        await MainActor.run {
            self.consentData = data.isEmpty ? nil : data
        }
    }
    
    private func fetchTCFString() async {
        // Placeholder - implement with actual TrustArc SDK method if available
        await MainActor.run {
            self.tcfString = TrustArc.sharedInstance.getTcfString()
        }
    }
    
    private func fetchGoogleConsents() async {
        // Placeholder - implement with actual TrustArc SDK method if available
        await MainActor.run {
            self.googleConsents = TrustArc.sharedInstance.getGoogleConsents()
        }
    }
    
    private func fetchWebScript() async {
        let script = TrustArc.sharedInstance.getWebScript()
        
        await MainActor.run {
            self.webScript = script.isEmpty == false ? script : nil
        }
    }
}

#Preview {
    PreferencesView()
}
