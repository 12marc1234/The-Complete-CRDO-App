//
//  ContentView.swift
//  CRDO
//
//  Created by Ethan Yip on 7/25/25.
//  Main content view with authentication flow
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authTracker = AuthenticationTracker.shared
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if !authTracker.isAuthenticated {
                AuthenticationView(authTracker: authTracker)
                    .transition(.opacity.combined(with: .scale))
            } else {
                MainAppView(authTracker: authTracker)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }
}

#Preview {
    ContentView()
}