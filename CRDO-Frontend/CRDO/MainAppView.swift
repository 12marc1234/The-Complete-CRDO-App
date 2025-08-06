//
//  MainAppView.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Main app view with tab navigation
//

import SwiftUI

struct MainAppView: View {
    @ObservedObject var authTracker: AuthenticationTracker
    @StateObject private var runManager = RunManager()
    @StateObject private var permissionManager = PermissionManager()
    @ObservedObject var gemsManager = GemsManager.shared
    @State private var selectedTab = 0
    @State private var showAppUpdated = false
    @State private var appUpdatedColor = Color.green
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Content
                TabView(selection: $selectedTab) {
                    // Home Tab
                    HomeView(runManager: runManager, permissionManager: permissionManager)
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .tag(0)
                    
                    // Recent Runs Tab
                    RecentRunsView(runManager: runManager)
                        .tabItem {
                            Image(systemName: "clock.fill")
                            Text("Recent")
                        }
                        .tag(1)
                    
                    // Friends Tab
                    FriendsView()
                        .tabItem {
                            Image(systemName: "person.2.fill")
                            Text("Friends")
                        }
                        .tag(2)
                    
                    // City Tab
                    CityView()
                        .tabItem {
                            Image(systemName: "building.2.fill")
                            Text("City")
                        }
                        .tag(3)
                    
                    // Profile Tab
                    ProfileView(authTracker: authTracker)
                        .tabItem {
                            Image(systemName: "person.circle.fill")
                            Text("Profile")
                        }
                        .tag(4)
                }
                .onAppear {
                    // Refresh gems data
                    gemsManager.refreshGemsData()
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Show APP UPDATED indicator when app loads (reduced delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAppUpdated = true
                }
            }
            
            // Change color for next update
            let colors: [Color] = [.green, .blue, .purple, .orange, .pink, .red, .yellow, .mint, .indigo, .teal]
            appUpdatedColor = colors.randomElement() ?? .green
        }
    }
}

#Preview {
    MainAppView(authTracker: AuthenticationTracker.shared)
} 