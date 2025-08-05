//
//  ProfileView.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Profile view with settings and user info
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var authTracker: AuthenticationTracker
    @ObservedObject var preferencesManager = UserPreferencesManager.shared
    @ObservedObject var gemsManager = GemsManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.black.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Profile header
                        VStack(spacing: 20) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(Color.gold.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gold)
                            }
                            
                            // User info
                            VStack(spacing: 8) {
                                Text(authTracker.currentUser?.fullName ?? authTracker.currentUser?.firstName != nil ? "\(authTracker.currentUser?.firstName ?? "") \(authTracker.currentUser?.lastName ?? "")" : "User")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text("Runner")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 20)
                        
                        // Stats summary
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Your Stats")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                                StatCard(
                                    title: "Total Runs",
                                    value: "24",
                                    subtitle: "This month",
                                    color: .blue
                                )
                                
                                StatCard(
                                    title: "Total Distance",
                                    value: "156.2 mi",
                                    subtitle: "Lifetime",
                                    color: .green
                                )
                                
                                StatCard(
                                    title: "Average Pace",
                                    value: "8:30",
                                    subtitle: "This month",
                                    color: .orange
                                )
                                
                                StatCard(
                                    title: "Best Time",
                                    value: "1:23:45",
                                    subtitle: "10K race",
                                    color: .purple
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Gems section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Gems")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                                StatCard(
                                    title: "Total Gems",
                                    value: "\(gemsManager.totalGems)",
                                    subtitle: "Lifetime",
                                    color: .yellow
                                )
                                
                                StatCard(
                                    title: "Today's Earnings",
                                    value: "+\(gemsManager.gemsEarnedToday)",
                                    subtitle: "Gems earned",
                                    color: .green
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Settings
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                SettingsRow(
                                    icon: "ruler",
                                    title: "Units",
                                    value: preferencesManager.preferences.unitSystem == .imperial ? "Imperial" : "Metric"
                                ) {
                                    preferencesManager.preferences.unitSystem = preferencesManager.preferences.unitSystem == .imperial ? .metric : .imperial
                                }
                                
                                SettingsRow(
                                    icon: "speedometer",
                                    title: "Show Speed",
                                    value: preferencesManager.preferences.showSpeed ? "On" : "Off"
                                ) {
                                    preferencesManager.preferences.showSpeed.toggle()
                                }
                                
                                SettingsRow(
                                    icon: "pause.circle",
                                    title: "Auto Pause",
                                    value: preferencesManager.preferences.autoPause ? "On" : "Off"
                                ) {
                                    preferencesManager.preferences.autoPause.toggle()
                                }
                                
                                SettingsRow(
                                    icon: "speaker.wave.2",
                                    title: "Voice Announcements",
                                    value: preferencesManager.preferences.voiceAnnouncements ? "On" : "Off"
                                ) {
                                    preferencesManager.preferences.voiceAnnouncements.toggle()
                                }
                            }
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Actions
                        VStack(spacing: 15) {
                            Button("Export Data") {
                                // Export functionality
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(25)
                            
                            Button("Sign Out") {
                                authTracker.signOut()
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(25)
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        // Edit profile functionality
                    }
                    .foregroundColor(.gold)
                }
            }
        }
        .onAppear {
            // UserPreferencesManager automatically loads preferences on init
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.gold)
                    .frame(width: 25)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.gray)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileView(authTracker: AuthenticationTracker.shared)
} 