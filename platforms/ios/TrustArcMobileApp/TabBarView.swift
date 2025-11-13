//
//  TabBarView.swift
//  TrustArcMobileApp
//
//  Created by TrustArc on 3/12/25.
//

import SwiftUI

struct TabBarView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            WebTestView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Web Test")
                }
                .tag(1)
            
            PreferencesView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Preferences")
                }
                .tag(2)
        }
        .accentColor(Color(UIColor.systemBlue)) // Adapts to dark mode
    }
}

#Preview {
    TabBarView()
}