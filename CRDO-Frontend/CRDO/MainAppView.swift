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
                // Gems display in top right corner
                HStack {
                    Spacer()
                    
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "diamond.fill")
                                .foregroundColor(.yellow)
                                .font(.title3)
                            
                            Text("\(gemsManager.totalGems)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }
                
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
                    RecentRunsView()
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
                    print("💎 MainAppView - Total gems: \(gemsManager.totalGems)")
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Show APP UPDATED indicator when app loads (reduced delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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