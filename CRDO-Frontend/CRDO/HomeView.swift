//
//  HomeView.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Home view with streaks and quick stats
//

import SwiftUI
import MapKit
import Charts

struct HomeView: View {
    @ObservedObject var runManager: RunManager
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var preferencesManager = UserPreferencesManager.shared
    @ObservedObject var gemsManager = GemsManager.shared
    @State private var showingRunMap = false
    @State private var showingUserSettings = false
    
    var body: some View {
        ZStack {
            // Dark background
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Streak section
                    StreakSection(
                        currentStreak: 5, // Mock value for now
                        longestStreak: 12, // Mock value for now
                        freezeTokens: 3, // Mock value for now
                        isRunActive: runManager.isRunning,
                        onStartRun: {
                            if runManager.isRunning {
                                runManager.stopRun()
                            } else {
                                runManager.startRun()
                                showingRunMap = true
                            }
                        },
                        onEndRun: {
                            if runManager.isRunning {
                                runManager.stopRun()
                            }
                        },
                        runManager: runManager,
                        gemsManager: gemsManager
                    )
                    
                    // Gems section
                    GemsSection(gemsManager: gemsManager)
                    
                    // Quick stats
                    QuickStatsSection(runManager: runManager)
                    
                    // Active run view
                    if runManager.isRunning {
                        VStack(spacing: 20) {
                            // Run stats
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                                StatCard(
                                    title: "Distance",
                                    value: UnitConverter.formatDistance(runManager.distance, unitSystem: preferencesManager.preferences.unitSystem),
                                    subtitle: preferencesManager.preferences.unitSystem == .imperial ? "miles" : "km",
                                    color: .blue
                                )
                                
                                StatCard(
                                    title: "Duration",
                                    value: UnitConverter.formatDuration(runManager.duration),
                                    subtitle: "time",
                                    color: .green
                                )
                                
                                StatCard(
                                    title: "Pace",
                                    value: UnitConverter.formatPace(runManager.pace, unitSystem: preferencesManager.preferences.unitSystem),
                                    subtitle: preferencesManager.preferences.unitSystem == .imperial ? "min/mi" : "min/km",
                                    color: .orange
                                )
                            }
                            
                            // Gems earned preview
                            HStack {
                                Image(systemName: "diamond.fill")
                                    .foregroundColor(.yellow)
                                    .font(.title3)
                                
                                Text("Gems Earned This Run:")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                let gemsEarned = GemsManager.shared.calculateGemsForRun(
                                    distance: runManager.distance,
                                    averageSpeed: runManager.averageSpeed
                                )
                                Text("+\(gemsEarned)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.yellow)
                            }
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            
                            // Stop button
                            Button(action: {
                                runManager.finishRun()
                            }) {
                                Text("Finish Run")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.red)
                                    .cornerRadius(25)
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                    }
                    
                    // Extra spacing for better scrolling
                    Spacer(minLength: 100)
                }
                .padding(.top, 20)
            }
            .scrollIndicators(.hidden) // Hide scroll indicators for cleaner look
        }
        .sheet(isPresented: $showingRunMap) {
            RunMapView(runManager: runManager)
        }
    }
}

// MARK: - Streak Section

struct StreakSection: View {
    let currentStreak: Int
    let longestStreak: Int
    let freezeTokens: Int
    let isRunActive: Bool
    let onStartRun: () -> Void
    let onEndRun: () -> Void
    @ObservedObject var runManager: RunManager
    @ObservedObject var gemsManager: GemsManager
    
    @State private var glowAnimation = false
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Daily Progress Circle
            VStack(spacing: 15) {
                Text("DAILY GOAL: 15 MIN")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Progress Circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: min(gemsManager.dailyProgressPercentage, 1.0))
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.gold, .orange]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: gemsManager.dailySecondsCompleted)
                    
                    // Center content
                    VStack(spacing: 4) {
                        let totalSeconds = gemsManager.dailySecondsCompleted
                        let minutes = totalSeconds / 60
                        let seconds = totalSeconds % 60
                        
                        Text("\(minutes):\(String(format: "%02d", seconds))")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("time")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gold.opacity(0.8))
                    }
                }
                .onAppear {
                    glowAnimation = true
                    pulseAnimation = true
                }
            }
            
            // Streak Display
            VStack(spacing: 15) {
                HStack {
                    Text("🔥 STREAKS")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.gold)
                        .tracking(1)
                    
                    Spacer()
                    
                    Button("View All") {
                        // Placeholder action
                    }
                    .font(.caption2)
                    .foregroundColor(.gold.opacity(0.8))
                }
                
                // Streak Cards
                HStack(spacing: 8) {
                    // Current Streak
                    StreakCard(
                        title: "Current",
                        value: currentStreak,
                        subtitle: "days",
                        icon: "🔥",
                        color: .orange,
                        isAnimated: true
                    )
                    
                    // Longest Streak
                    StreakCard(
                        title: "Longest",
                        value: longestStreak,
                        subtitle: "days",
                        icon: "🏆",
                        color: .gold,
                        isAnimated: false
                    )
                    
                    // Total Runs
                    StreakCard(
                        title: "Total",
                        value: runManager.recentRuns.count,
                        subtitle: "runs",
                        icon: "💪",
                        color: .green,
                        isAnimated: false
                    )
                }
            }
            
            // Start Run Button
            Button(action: onStartRun) {
                HStack {
                    Image(systemName: isRunActive ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(isRunActive ? "Pause Run" : "Start Run")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isRunActive ? Color.orange : Color.green)
                .cornerRadius(25)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    let title: String
    let value: Int
    let subtitle: String
    let icon: String
    let color: Color
    let isAnimated: Bool
    @State private var animation = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.title2)
                .scaleEffect(animation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animation)
            
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            if isAnimated {
                animation = true
            }
        }
    }
}

// MARK: - Quick Stats Section

struct QuickStatsSection: View {
    @ObservedObject var runManager: RunManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("QUICK STATS")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.gold)
                .tracking(1)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "Total Distance",
                    value: String(format: "%.1f", runManager.totalDistance),
                    subtitle: "miles",
                    color: .blue
                )
                
                StatCard(
                    title: "Total Time",
                    value: formatTime(runManager.totalTime),
                    subtitle: "hours",
                    color: .green
                )
                
                StatCard(
                    title: "Average Pace",
                    value: UnitConverter.formatPace(runManager.currentRun?.averagePace ?? 0, unitSystem: .imperial),
                    subtitle: "min/mi",
                    color: .orange
                )
                
                StatCard(
                    title: "Best Run",
                    value: String(format: "%.1f", runManager.bestDistance),
                    subtitle: "miles",
                    color: .gold
                )
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours):\(String(format: "%02d", minutes))"
    }
}

// MARK: - Run Map View

struct RunMapView: View {
    @ObservedObject var runManager: RunManager
    @Environment(\.dismiss) private var dismiss
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showAverageSpeed = true
    
    var body: some View {
        ZStack {
            // Dark background
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Active Run")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Stop") {
                        runManager.stopRun()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                .padding()
                .background(Color.black.opacity(0.8))
                
                // Map
                Map(coordinateRegion: $region, showsUserLocation: true, userTrackingMode: .constant(.follow))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Stats overlay
                VStack(spacing: 16) {
                    // Average Speed Display
                    if showAverageSpeed {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Current Speed")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(String(format: "%.1f mph", runManager.currentSpeed))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Average Speed")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(String(format: "%.1f mph", runManager.averageSpeed))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                    }
                    
                    // Run stats
                    HStack(spacing: 20) {
                        VStack {
                            Text("Distance")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(UnitConverter.formatDistance(runManager.currentRun?.distance ?? 0, unitSystem: .imperial))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Text("Time")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(formatRunTime(Int(runManager.currentRun?.duration ?? 0)))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        VStack {
                            Text("Pace")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(UnitConverter.formatPace(runManager.currentRun?.averagePace ?? 0, unitSystem: .imperial))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
    }
    
    private func formatRunTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct GemsSection: View {
    @ObservedObject var gemsManager: GemsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "diamond.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                Text("Gems")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(gemsManager.totalGems)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Earnings")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("+\(gemsManager.gemsEarnedToday)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Gems")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(gemsManager.totalGems)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

#Preview {
    HomeView(runManager: RunManager(), permissionManager: PermissionManager())
} 