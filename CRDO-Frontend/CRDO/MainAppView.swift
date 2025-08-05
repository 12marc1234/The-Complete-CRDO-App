//
//  MainAppView.swift
//  CRDO
//
//  Created by Ethan Yip on 7/25/25.
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
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
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
                
                // Profile Tab
                ProfileView(authTracker: authTracker)
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
                    .tag(3)
                
                // City Tab
                CityView()
                    .tabItem {
                        Image(systemName: "building.2.fill")
                        Text("City")
                    }
                    .tag(4)
            }
            .accentColor(.gold)
            .onAppear {
                // Set tab bar appearance for dark mode
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor.black
                appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemYellow
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemYellow]
                appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]
                
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
                
                // Refresh gems data
                gemsManager.refreshGemsData()
            }
            
            // Gems display in top right corner
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "diamond.fill")
                                .foregroundColor(.yellow)
                                .font(.title3)
                            
                            Text("\(gemsManager.totalGems)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                        }
                        
                        if gemsManager.gemsEarnedToday > 0 {
                            Text("+\(gemsManager.gemsEarnedToday) today")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
            }
            
            // APP UPDATED indicator
            if showAppUpdated {
                VStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(appUpdatedColor)
                        Text("APP UPDATED!")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(appUpdatedColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .shadow(color: appUpdatedColor.opacity(0.3), radius: 10)
                    
                    Spacer()
                }
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showAppUpdated = false
                        }
                    }
                }
            }
        }
        .onAppear {
            // Show APP UPDATED indicator when app loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation(.easeInOut(duration: 0.5)) {
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