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
    
    private var currentStreak: Int {
        let calendar = Calendar.current
        let today = Date()
        var streak = 0
        
        // Sort runs by date (most recent first)
        let sortedRuns = runManager.recentRuns.sorted { $0.startTime > $1.startTime }
        
        for dayOffset in 0...365 { // Check up to a year back
            let checkDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            
            // Check if there's a run on this date
            let hasRunOnDate = sortedRuns.contains { run in
                calendar.isDate(run.startTime, inSameDayAs: checkDate)
            }
            
            if hasRunOnDate {
                streak += 1
            } else {
                break // Streak broken
            }
        }
        
        return streak
    }
    
    private var longestStreak: Int {
        let calendar = Calendar.current
        var longestStreak = 0
        var currentStreak = 0
        var lastRunDate: Date?
        
        // Sort runs by date (oldest first)
        let sortedRuns = runManager.recentRuns.sorted { $0.startTime < $1.startTime }
        
        for run in sortedRuns {
            if let lastDate = lastRunDate {
                let daysBetween = calendar.dateComponents([.day], from: lastDate, to: run.startTime).day ?? 0
                
                if daysBetween == 1 {
                    // Consecutive day
                    currentStreak += 1
                } else if daysBetween > 1 {
                    // Gap in streak, reset
                    longestStreak = max(longestStreak, currentStreak)
                    currentStreak = 1
                } else {
                    // Same day, don't increment
                    continue
                }
            } else {
                // First run
                currentStreak = 1
            }
            
            lastRunDate = run.startTime
        }
        
        // Check final streak
        longestStreak = max(longestStreak, currentStreak)
        
        return longestStreak
    }
    
    var body: some View {
        ZStack {
            // Enhanced gradient background
            LinearGradient.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Enhanced streak section
                    StreakSection(
                        currentStreak: currentStreak,
                        longestStreak: longestStreak,
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
                    .padding(.horizontal, 20)
                    
                    // Enhanced gems section
                    GemsSection(gemsManager: gemsManager)
                        .padding(.horizontal, 20)
                    
                    // Enhanced quick stats
                    QuickStatsSection(runManager: runManager)
                        .padding(.horizontal, 20)
                    
                    // Enhanced active run view
                    if runManager.isRunning {
                        VStack(spacing: 24) {
                            // Enhanced run stats with better spacing
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                                RunStatCard(
                                    title: "Distance",
                                    value: UnitConverter.formatDistance(runManager.distance, unitSystem: preferencesManager.preferences.unitSystem),
                                    subtitle: preferencesManager.preferences.unitSystem == .imperial ? "miles" : "km",
                                    color: .blue,
                                    icon: "location.fill"
                                )
                                
                                RunStatCard(
                                    title: "Duration",
                                    value: UnitConverter.formatDuration(runManager.duration),
                                    subtitle: "time",
                                    color: .green,
                                    icon: "clock.fill"
                                )
                                
                                RunStatCard(
                                    title: "Pace",
                                    value: UnitConverter.formatPace(runManager.pace, unitSystem: preferencesManager.preferences.unitSystem),
                                    subtitle: preferencesManager.preferences.unitSystem == .imperial ? "min/mi" : "min/km",
                                    color: .orange,
                                    icon: "timer"
                                )
                            }
                            .padding(.horizontal, 20)
                            
                            // Enhanced gems earned preview
                            HStack {
                                Image(systemName: "diamond.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .shadow(color: .yellow.opacity(0.5), radius: 4)
                                
                                Text("Gems Earned This Run:")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("+\(Int(runManager.duration / 60))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.yellow)
                                    .shadow(color: .yellow.opacity(0.5), radius: 4)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Return to Run button (only show when run is active)
                    if runManager.isRunning {
                        Button("Return to Run") {
                            showingRunMap = true
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.top, 20)
            }
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
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                
                // Progress Circle
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                        .frame(width: 150, height: 150)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: min(gemsManager.dailyProgressPercentage, 1.0))
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [.gold, .orange]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: gemsManager.dailySecondsCompleted)
                    
                    // Center content
                    VStack(spacing: 4) {
                        let totalSeconds = gemsManager.dailySecondsCompleted
                        let minutes = totalSeconds / 60
                        let seconds = totalSeconds % 60
                        
                        Text(formatTimeDisplay(totalSeconds))
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
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.gold)
                        .tracking(1)
                    
                    Spacer()
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
    
    private func formatTimeDisplay(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
        } else {
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
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
                .font(.system(size: 24, weight: .bold, design: .monospaced))
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
    @ObservedObject var preferencesManager = UserPreferencesManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Text("QUICK STATS")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.gold)
                .tracking(1)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "Total Distance",
                    value: UnitConverter.formatDistance(runManager.totalDistance, unitSystem: preferencesManager.preferences.unitSystem),
                    subtitle: preferencesManager.preferences.unitSystem == .imperial ? "miles" : "km",
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
                    value: UnitConverter.formatPace(runManager.averagePace, unitSystem: preferencesManager.preferences.unitSystem),
                    subtitle: preferencesManager.preferences.unitSystem == .imperial ? "min/mi" : "min/km",
                    color: .orange
                )
                
                StatCard(
                    title: "Longest Run",
                    value: UnitConverter.formatDistance(runManager.longestDistance, unitSystem: preferencesManager.preferences.unitSystem),
                    subtitle: preferencesManager.preferences.unitSystem == .imperial ? "miles" : "km",
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

// MARK: - Enhanced Run Map View

struct RunMapView: View {
    @ObservedObject var runManager: RunManager
    @ObservedObject var preferencesManager = UserPreferencesManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showAverageSpeed = true
    @State private var showConfetti = false
    
    // Device-specific adaptations
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Adaptive sizing based on device
    private var adaptiveSpacing: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 40
        } else if UIScreen.main.bounds.height > 800 {
            return 35
        } else {
            return 30
        }
    }

    private var adaptiveIconSize: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 80
        } else if UIScreen.main.bounds.height > 800 {
            return 70
        } else {
            return 60
        }
    }

    private var adaptiveTitleSize: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 32
        } else if UIScreen.main.bounds.height > 800 {
            return 28
        } else {
            return 24
        }
    }
    
    var body: some View {
        ZStack {
            // Enhanced dark background
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.3), Color.black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Enhanced Header with Clearer Controls
                HStack {
                    // Close/Back Button
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("CLOSE")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // Run Status
                    VStack(spacing: 4) {
                        Text("ACTIVE RUN")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        if runManager.isRunning {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(1.2)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: runManager.isRunning)
                                
                                Text("LIVE TRACKING")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                                
                                Text("PAUSED")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Main Action Button (Start/Pause/Resume)
                    Button(action: {
                        if runManager.isRunning {
                            // Pause the run
                            runManager.pauseRun()
                        } else {
                            // Resume the run
                            runManager.resumeRun()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: runManager.isRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text(runManager.isRunning ? "PAUSE" : "RESUME")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(runManager.isRunning ? .orange : .green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(runManager.isRunning ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(Color.black.opacity(0.8))
                .padding(.bottom, 8) // Reduced extra bottom padding
                
                // Enhanced Map with better proportions
                ZStack {
                    Map(coordinateRegion: $region, showsUserLocation: true, userTrackingMode: .constant(.follow))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped() // Ensure clean edges
                    
                    // Live tracking indicator
                    if runManager.isRunning {
                        VStack {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(1.5)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: runManager.isRunning)
                                
                                Text("LIVE")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(15)
                            
                            Spacer()
                        }
                        .padding(.top, 20)
                        .padding(.leading, 20)
                    }
                }
                
                // Professional Stats overlay with large, beautiful cards
                VStack(spacing: 16) { // Increased spacing for better visual separation
                    Spacer()
                    
                    // Top row - 2 cards each taking more space
                    HStack(spacing: 16) {
                        // Current Speed - Larger card
                        CompactStatCard(
                            title: "CURRENT",
                            value: UnitConverter.formatSpeed(runManager.currentSpeed, unitSystem: preferencesManager.preferences.unitSystem),
                            color: .blue
                        )
                        .frame(maxWidth: .infinity)
                        
                        // Average Speed - Larger card
                        CompactStatCard(
                            title: "AVERAGE",
                            value: UnitConverter.formatSpeed(runManager.averageSpeed, unitSystem: preferencesManager.preferences.unitSystem),
                            color: .green
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    
                    // Middle row - 2 cards
                    HStack(spacing: 16) {
                        // Distance - Larger card
                        CompactStatCard(
                            title: "DISTANCE",
                            value: UnitConverter.formatDistance(runManager.currentRun?.distance ?? 0, unitSystem: preferencesManager.preferences.unitSystem),
                            color: .orange
                        )
                        .frame(maxWidth: .infinity)
                        
                        // Time - Larger card
                        CompactStatCard(
                            title: "TIME",
                            value: formatRunTime(Int(runManager.currentRun?.duration ?? 0)),
                            color: .purple
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    
                    // Bottom row - Pace card and Finish button
                    HStack(spacing: 16) {
                        // Pace - Larger card
                        CompactStatCard(
                            title: "PACE",
                            value: UnitConverter.formatPace(runManager.currentRun?.averagePace ?? 0, unitSystem: preferencesManager.preferences.unitSystem),
                            color: .red
                        )
                        .frame(maxWidth: .infinity)
                        
                        // Professional Finish Run Button
                        Button(action: {
                            runManager.finishRun()
                            dismiss()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                
                                VStack(spacing: 2) {
                                    Text("FINISH")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    Text("RUN")
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                            .frame(minHeight: 100)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(20)
                            .shadow(color: Color.red.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.6)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onAppear {
            // Start location updates if not already running
            if !runManager.isRunning {
                runManager.startRun()
            }
        }
    }
    
    private func formatRunTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Enhanced Stat Card

struct RunStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Spacer()
                
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            
            Text(subtitle)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Pause Menu View

struct PauseMenuView: View {
    @ObservedObject var runManager: RunManager
    let onResume: () -> Void
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("RUN PAUSED")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("What would you like to do?")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        runManager.resumeRun()
                        onResume()
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 24))
                            Text("RESUME RUN")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        runManager.finishRun()
                        onFinish()
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 24))
                            Text("FINISH RUN")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("CANCEL")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.top, 60)
        }
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
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    
                                            Text("+\(gemsManager.gemsEarnedToday)")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Gems")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Text("\(gemsManager.totalGems)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
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
    HomeView(runManager: RunManager.shared, permissionManager: PermissionManager())
} 
