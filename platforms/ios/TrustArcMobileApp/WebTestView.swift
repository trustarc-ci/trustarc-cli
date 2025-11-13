//
//  WebTestView.swift
//  TrustArcMobileApp
//
//  Created by TrustArc on 3/12/25.
//

import SwiftUI
import WebKit
import trustarc_consent_sdk

struct WebTestView: View {
    @StateObject private var webViewModel = WebTestViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack {
                Text("Web Test")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemIndigo)) // Adapts to dark mode
            
            ZStack {
                WebView(viewModel: webViewModel)
                    .background(Color(UIColor.systemBackground)) // Adapts to dark mode

                if webViewModel.isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .foregroundColor(Color(UIColor.systemBlue))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground).opacity(0.8))
                }

                if webViewModel.hasError {
                    VStack {
                        Spacer()
                        Text("Error loading webpage")
                            .font(.system(size: 16))
                            .foregroundColor(Color(UIColor.systemRed))
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") {
                            webViewModel.loadWebView()
                        }
                        .padding()
                        .background(Color(UIColor.systemIndigo))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground).opacity(0.9))
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground)) // Adapts to dark mode
        .onAppear {
            DispatchQueue.main.async {
                webViewModel.loadWebView()
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let viewModel: WebTestViewModel
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        // Inject the TrustArc JavaScript before the page loads
        let taWebscript = TrustArc.sharedInstance.getWebScript()
        
        if !taWebscript.isEmpty {
            let taScript = WKUserScript(source: taWebscript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            userContentController.addUserScript(taScript)
        }
        
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = context.coordinator
        
        // Configure WebView exactly like WebViewTester.swift
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        
        configureWebView(webView)
        
        // Load URL immediately like WebViewTester.swift does in viewDidLoad
        viewModel.loadURL(in: webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if viewModel.shouldReload {
            viewModel.loadURL(in: webView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    private func configureWebView(_ webView: WKWebView) {
        // Exact configuration from WebViewTester.swift
        if #available(iOS 14, *) {
            let preferences = WKWebpagePreferences()
            preferences.allowsContentJavaScript = true
            webView.configuration.defaultWebpagePreferences = preferences
        } else {
            webView.configuration.preferences.javaScriptEnabled = true
            webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let viewModel: WebTestViewModel
        
        init(viewModel: WebTestViewModel) {
            self.viewModel = viewModel
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.viewModel.setLoading(true)
            }
        }
        
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.viewModel.setLoading(false)
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.viewModel.setLoading(false)
                self.viewModel.setError(true)
            }
            print("WebView failed to load: \(error.localizedDescription)")
        }
    }
}

@MainActor
class WebTestViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var hasError = false
    @Published var shouldReload = false
    
    func loadWebView() {
        // Reset any error state
        hasError = false
        shouldReload = true
    }
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    func setError(_ error: Bool) {
        hasError = error
    }
    
    func loadURL(in webView: WKWebView) {
        let urlString = AppConfig.shared.testWebsiteUrl
        
        DispatchQueue.main.async {
            self.loadURL(urlString, in: webView)
        }
    }
    
    private func loadURL(_ urlString: String, in webView: WKWebView) {
        // Exact implementation from WebViewTester.swift
        print("Loading URL: \(urlString)")
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
            shouldReload = false
            print("URL request created and loaded")
        } else {
            print("Failed to create URL from string: \(urlString)")
            hasError = true
        }
    }
}

#Preview {
    WebTestView()
}
