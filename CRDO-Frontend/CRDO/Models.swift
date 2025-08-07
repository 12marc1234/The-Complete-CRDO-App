//
//  Models.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Data models and structs
//

import Foundation
import SwiftUI
import CoreLocation
import Charts

// MARK: - Color Extensions

extension Color {
    static let gold = Color(red: 1.0, green: 0.843, blue: 0.0)
    static let darkGray = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let lightGray = Color(red: 0.9, green: 0.9, blue: 0.9)
}

// MARK: - User Preferences

struct UserPreferences: Codable {
    var unitSystem: UnitSystem = .imperial
    var autoPause: Bool = true
    var voiceAnnouncements: Bool = false
    var totalGems: Int = 0
    var gemsEarnedToday: Int = 0
    var lastRunDate: Date?
}

class UserPreferencesManager: ObservableObject {
    static let shared = UserPreferencesManager()
    
    @Published var preferences: UserPreferences {
        didSet {
            savePreferences()
        }
    }
    
    private init() {
        self.preferences = UserPreferences()
        loadPreferences()
    }
    
    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "userPreferences"),
           let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            self.preferences = preferences
        }
    }
    
    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "userPreferences")
        }
    }
}

class GemsManager: ObservableObject {
    static let shared = GemsManager()
    
    @Published var totalGems: Int = 0
    @Published var gemsEarnedToday: Int = 0
    @Published var lastRunDate: Date?
    @Published var dailySecondsCompleted: Int = 0
    @Published var dailyMinutesGoal: Int = 15
    
    private init() {
        loadGemsData()
        checkDailyReset()
        
        // Listen for user changes to reload data
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadGemsData()
        }
    }
    
    func loadGemsData() {
        let userId = DataManager.shared.getUserId() ?? "guest"
        let prefix = "gems_\(userId)_"
        
        totalGems = UserDefaults.standard.integer(forKey: prefix + "totalGems")
        gemsEarnedToday = UserDefaults.standard.integer(forKey: prefix + "gemsEarnedToday")
        lastRunDate = UserDefaults.standard.object(forKey: prefix + "lastRunDate") as? Date
        dailySecondsCompleted = UserDefaults.standard.integer(forKey: prefix + "dailySecondsCompleted")
        dailyMinutesGoal = UserDefaults.standard.integer(forKey: prefix + "dailyMinutesGoal")
        
        // Set default goal if not set
        if dailyMinutesGoal == 0 {
            dailyMinutesGoal = 15
        }
        
        // Sync with UserPreferences if available (but don't override if we have saved data)
        let preferencesManager = UserPreferencesManager.shared
        if totalGems == 0 && preferencesManager.preferences.totalGems > 0 {
            totalGems = preferencesManager.preferences.totalGems
        }
        if gemsEarnedToday == 0 && preferencesManager.preferences.gemsEarnedToday > 0 {
            gemsEarnedToday = preferencesManager.preferences.gemsEarnedToday
        }
        
        print("🔮 GemsManager - Loaded Data for user \(userId):")
        print("   Total Gems: \(totalGems)")
        print("   Gems Earned Today: \(gemsEarnedToday)")
        print("   Last Run Date: \(lastRunDate?.description ?? "None")")
        print("   Daily Seconds Completed: \(dailySecondsCompleted)")
        print("   Daily Minutes Goal: \(dailyMinutesGoal)")
    }
    
    func saveGemsData() {
        let userId = DataManager.shared.getUserId() ?? "guest"
        let prefix = "gems_\(userId)_"
        
        UserDefaults.standard.set(totalGems, forKey: prefix + "totalGems")
        UserDefaults.standard.set(gemsEarnedToday, forKey: prefix + "gemsEarnedToday")
        UserDefaults.standard.set(lastRunDate, forKey: prefix + "lastRunDate")
        UserDefaults.standard.set(dailySecondsCompleted, forKey: prefix + "dailySecondsCompleted")
        UserDefaults.standard.set(dailyMinutesGoal, forKey: prefix + "dailyMinutesGoal")
        
        // Also sync with UserPreferences
        let preferencesManager = UserPreferencesManager.shared
        preferencesManager.preferences.totalGems = totalGems
        preferencesManager.preferences.gemsEarnedToday = gemsEarnedToday
        
        print("💾 GemsManager - Saved Data for user \(userId):")
        print("   Total Gems: \(totalGems)")
        print("   Gems Earned Today: \(gemsEarnedToday)")
        print("   Last Run Date: \(lastRunDate?.description ?? "None")")
        print("   Daily Seconds Completed: \(dailySecondsCompleted)")
        print("   Daily Minutes Goal: \(dailyMinutesGoal)")
    }
    
    private func checkDailyReset() {
        let calendar = Calendar.current
        let today = Date()
        
        if let lastRun = lastRunDate {
            if !calendar.isDate(lastRun, inSameDayAs: today) {
                // New day, reset daily progress
                gemsEarnedToday = 0
                dailySecondsCompleted = 0
                lastRunDate = today
                saveGemsData()
                print("🔄 Daily progress reset for new day")
            }
        } else {
            // First time running, set today as last run date
            lastRunDate = today
            saveGemsData()
        }
    }
    
    func addDailyProgress(seconds: Int) {
        let wasGoalCompleted = dailyProgressPercentage >= 1.0
        dailySecondsCompleted += seconds
        checkDailyReset() // Check if it's a new day
        saveGemsData()
        
        // If goal was just completed, update streak
        if !wasGoalCompleted && dailyProgressPercentage >= 1.0 {
            updateStreakForGoalCompletion()
        }
        
        print("⏱️ Added \(seconds) seconds to daily progress. Total: \(dailySecondsCompleted)")
    }
    
    private func updateStreakForGoalCompletion() {
        // Create a virtual run entry for today to maintain streak
        let today = Date()
        let calendar = Calendar.current
        
        // Check if we already have a run for today
        guard let runManager = RunManager.currentInstance else {
            print("⚠️ RunManager not available for streak update")
            return
        }
        
        let hasRunToday = runManager.recentRuns.contains { run in
            calendar.isDate(run.startTime, inSameDayAs: today)
        }
        
        if !hasRunToday {
            // Create a virtual run entry for streak purposes
            var virtualRun = RunSession()
            virtualRun.startTime = today
            virtualRun.endTime = today
            virtualRun.distance = 0 // Virtual run for streak only
            virtualRun.duration = TimeInterval(dailySecondsCompleted)
            virtualRun.isActive = false
            
            // Add to recent runs
            runManager.recentRuns.insert(virtualRun, at: 0)
            runManager.saveRecentRuns()
            
            print("🔥 Streak updated - virtual run created for goal completion")
        }
    }
    
    func setDailyGoal(minutes: Int) {
        dailyMinutesGoal = minutes
        saveGemsData()
        print("🎯 Daily goal set to \(minutes) minutes")
    }
    
    var dailyProgressPercentage: Double {
        let goalSeconds = dailyMinutesGoal * 60
        return goalSeconds > 0 ? Double(dailySecondsCompleted) / Double(goalSeconds) : 0.0
    }
    
    var dailyProgressText: String {
        let goalSeconds = dailyMinutesGoal * 60
        let remainingSeconds = max(0, goalSeconds - dailySecondsCompleted)
        let remainingMinutes = remainingSeconds / 60
        let remainingSecs = remainingSeconds % 60
        
        if remainingSeconds == 0 {
            return "Goal completed! 🎉"
        } else {
            return "\(remainingMinutes)m \(remainingSecs)s remaining"
        }
    }
    
    func calculateGemsForRun(distance: Double, averageSpeed: Double) -> Int {
        var gems = 10 // Base gems per run
        
        print("🔍 Gem Calculation Details:")
        print("   Input Distance: \(distance) meters")
        print("   Input Average Speed: \(averageSpeed) mph")
        
        // Speed bonus: +1 gem per mph over 6 mph (up to 10 mph)
        let speedMph = averageSpeed
        if speedMph > 6 {
            let speedBonus = min(speedMph - 6, 4) // Max 4 gems from speed (6-10 mph)
            gems += Int(speedBonus)
            print("   Speed Bonus: +\(Int(speedBonus)) gems")
        } else {
            print("   Speed Bonus: +0 gems (speed \(speedMph) mph <= 6 mph)")
        }
        
        // Distance bonus: +1 gem per mile
        let distanceMiles = distance / 1609.34 // Convert meters to miles
        let distanceBonus = Int(distanceMiles)
        gems += distanceBonus
        print("   Distance Bonus: +\(distanceBonus) gems (\(distanceMiles) miles)")
        
        // Streak bonus: +5 gems for consecutive days
        if let lastRun = lastRunDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(lastRun) || calendar.isDateInYesterday(lastRun) {
                gems += 5
                print("   Streak Bonus: +5 gems")
            } else {
                print("   Streak Bonus: +0 gems (no consecutive days)")
            }
        } else {
            print("   Streak Bonus: +0 gems (no previous run)")
        }
        
        print("   Total Gems: \(gems)")
        return gems
    }
    
    func awardGemsForRun(_ gems: Int) {
        print("💎 Awarding \(gems) gems for run")
        totalGems += gems
        gemsEarnedToday += gems
        
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        saveGemsData()
        print("💎 Total gems now: \(totalGems), earned today: \(gemsEarnedToday)")
    }
    
    func spendGems(_ amount: Int) -> Bool {
        guard totalGems >= amount else {
            print("❌ Not enough gems to spend \(amount). Current: \(totalGems)")
            return false
        }
        
        print("💎 Spending \(amount) gems")
        totalGems -= amount
        
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        saveGemsData()
        print("💎 Gems spent. Remaining: \(totalGems)")
        return true
    }
    
    func resetDailyGems() {
        print("💎 Resetting daily gems")
        gemsEarnedToday = 0
        
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            self.objectWillChange.send()
            UserPreferencesManager.shared.objectWillChange.send()
        }
        
        saveGemsData()
        print("💎 Daily gems reset")
    }
    
    func refreshGemsData() {
        loadGemsData()
        // Sync with UserPreferences
        let preferencesManager = UserPreferencesManager.shared
        preferencesManager.preferences.totalGems = totalGems
        preferencesManager.preferences.gemsEarnedToday = gemsEarnedToday
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
            preferencesManager.objectWillChange.send()
        }
    }
}

enum UnitSystem: String, CaseIterable, Codable {
    case imperial = "imperial"
    case metric = "metric"
    
    var distanceUnit: String {
        switch self {
        case .imperial: return "mi"
        case .metric: return "km"
        }
    }
    
    var speedUnit: String {
        switch self {
        case .imperial: return "mph"
        case .metric: return "kph"
        }
    }
    
    var paceUnit: String {
        switch self {
        case .imperial: return "min/mi"
        case .metric: return "min/km"
        }
    }
}

// MARK: - Run Data Models

struct RunSession: Codable, Identifiable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var distance: Double // in meters
    var duration: TimeInterval
    var averagePace: Double // seconds per unit
    var maxPace: Double
    var route: [CLLocationCoordinate2D]
    var isActive: Bool
    
    init() {
        self.id = UUID()
        self.startTime = Date()
        self.endTime = nil
        self.distance = 0.0
        self.duration = 0.0
        self.averagePace = 0.0
        self.maxPace = 0.0
        self.route = []
        self.isActive = true
    }
    
    // Custom Codable implementation to handle CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, distance, duration, averagePace, maxPace, isActive
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        distance = try container.decode(Double.self, forKey: .distance)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        averagePace = try container.decode(Double.self, forKey: .averagePace)
        maxPace = try container.decode(Double.self, forKey: .maxPace)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        route = [] // Initialize empty route
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(distance, forKey: .distance)
        try container.encode(duration, forKey: .duration)
        try container.encode(averagePace, forKey: .averagePace)
        try container.encode(maxPace, forKey: .maxPace)
        try container.encode(isActive, forKey: .isActive)
        // Note: route is not encoded/decoded since CLLocationCoordinate2D is not Codable
    }
}

// MARK: - Mock Data Models

struct MockFriend: Identifiable, Codable {
    let id = UUID()
    let name: String
    let email: String
    let avatar: String
    let status: FriendStatus
    let lastActive: Date
    let totalRuns: Int
    let totalDistance: Double
    let averagePace: Double
    let bio: String // New field for friend bio
}

enum FriendStatus: Codable {
    case online
    case offline
    case running
}



// MARK: - Chart Data Models

struct WeeklyProgressData: Identifiable {
    let id = UUID()
    let date: Date
    let distance: Double
    let duration: TimeInterval
    let averagePace: Double
}

struct PaceTrendData: Identifiable {
    let id = UUID()
    let date: Date
    let averagePace: Double
    let maxPace: Double
}

// MARK: - UI Models

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 2)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            
            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.gray.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.15))
        .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
        )
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct CompactStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) { // Increased spacing for better proportions
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .monospaced)) // Much larger text
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 3)
                .minimumScaleFactor(0.8) // Better scaling
                .lineLimit(1)
            
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .monospaced)) // Larger title
                .foregroundColor(.white.opacity(0.9))
                .textCase(.uppercase)
                .tracking(1.0) // Better letter spacing
        }
        .padding(.horizontal, 24) // Much more padding
        .padding(.vertical, 20) // Much more padding
        .frame(minHeight: 100) // Minimum height to ensure consistency
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.6), lineWidth: 2.0) // Thicker border
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4) // Better shadow
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Unit Conversion

struct UnitConverter {
    static func metersToMiles(_ meters: Double) -> Double {
        return meters / 1609.34
    }
    
    static func metersToKilometers(_ meters: Double) -> Double {
        return meters / 1000.0
    }
    
    static func secondsPerMeterToMinutesPerMile(_ secondsPerMeter: Double) -> Double {
        return secondsPerMeter * 1609.34 / 60.0
    }
    
    static func secondsPerMeterToMinutesPerKilometer(_ secondsPerMeter: Double) -> Double {
        return secondsPerMeter * 1000.0 / 60.0
    }
    
    static func metersPerSecondToMilesPerHour(_ metersPerSecond: Double) -> Double {
        return metersPerSecond * 2.237
    }
    
    static func metersPerSecondToKilometersPerHour(_ metersPerSecond: Double) -> Double {
        return metersPerSecond * 3.6
    }
    
    static func formatDistance(_ meters: Double, unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .imperial:
            let miles = metersToMiles(meters)
            if miles < 0.1 {
                // Show feet for distances less than 0.1 miles, rounded to nearest foot
                let feet = meters * 3.28084 // Convert meters to feet
                return String(format: "%.0f ft", round(feet))
            } else {
                // Show miles rounded to nearest hundredth
                let roundedMiles = round(miles * 100) / 100
                return String(format: "%.2f mi", roundedMiles)
            }
        case .metric:
            let kilometers = metersToKilometers(meters)
            if kilometers < 1.0 {
                // Show meters rounded to nearest meter for distances less than 1 km
                return String(format: "%.0f m", round(meters))
            } else if kilometers < 10.0 {
                // Show kilometers rounded to nearest tenth for distances between 1-10 km
                let roundedKm = round(kilometers * 10) / 10
                return String(format: "%.1f km", roundedKm)
            } else {
                // Show kilometers rounded to nearest km for distances 10+ km
                let roundedKm = round(kilometers)
                return String(format: "%.0f km", roundedKm)
            }
        }
    }
    
    static func formatPace(_ pace: Double, unitSystem: UnitSystem) -> String {
        // Handle invalid pace values
        guard pace.isFinite && pace > 0 else {
            return "0:00"
        }
        
        switch unitSystem {
        case .metric:
            // Convert pace from min/mile to min/km
            let pacePerKm = pace * 0.621371 // Convert min/mile to min/km
            let minutes = Int(pacePerKm)
            let seconds = Int((pacePerKm - Double(minutes)) * 60)
            return String(format: "%d:%02d", minutes, seconds)
        case .imperial:
            // Keep pace as min/mile
            let minutes = Int(pace)
            let seconds = Int((pace - Double(minutes)) * 60)
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    static func formatSpeed(_ metersPerSecond: Double, unitSystem: UnitSystem) -> String {
        switch unitSystem {
        case .imperial:
            let mph = metersPerSecondToMilesPerHour(metersPerSecond)
            return String(format: "%.1f mph", mph)
        case .metric:
            let kph = metersPerSecondToKilometersPerHour(metersPerSecond)
            return String(format: "%.1f kph", kph)
        }
    }
    
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
} 

// MARK: - Custom Shapes

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Building Types

enum BuildingType: String, CaseIterable, Codable {
    case house = "House"
    case park = "Park"
    case office = "Office"
    case mall = "Mall"
    case skyscraper = "Skyscraper"
    case monument = "Monument"
    
    var cost: Int {
        switch self {
        case .house: return 50
        case .park: return 100
        case .office: return 200
        case .mall: return 300
        case .skyscraper: return 500
        case .monument: return 1000
        }
    }
    
    var color: Color {
        switch self {
        case .house: return .orange
        case .park: return .green
        case .office: return .blue
        case .mall: return .purple
        case .skyscraper: return .gray
        case .monument: return .gold
        }
    }
    
    var icon: String {
        switch self {
        case .house: return "house.fill"
        case .park: return "leaf.fill"
        case .office: return "building.2.fill"
        case .mall: return "cart.fill"
        case .skyscraper: return "building.fill"
        case .monument: return "crown.fill"
        }
    }
    
    var description: String {
        switch self {
        case .house: return "Cozy home"
        case .park: return "Green space"
        case .office: return "Work place"
        case .mall: return "Shopping center"
        case .skyscraper: return "Tall tower"
        case .monument: return "Landmark"
        }
    }
    
    var realisticIcon: String {
        switch self {
        case .house: return "house1"
        case .park: return "park1"
        case .office: return "office1"
        case .mall: return "mall1"
        case .skyscraper: return "skyscraper1"
        case .monument: return "monument1"
        }
    }
    
    var size: CGSize {
        switch self {
        case .house: return CGSize(width: 40, height: 40)
        case .park: return CGSize(width: 50, height: 50)
        case .office: return CGSize(width: 45, height: 45)
        case .mall: return CGSize(width: 55, height: 55)
        case .skyscraper: return CGSize(width: 60, height: 60)
        case .monument: return CGSize(width: 70, height: 70)
        }
    }
    
    var buildingGraphic: some View {
        switch self {
        case .house:
            AnyView(
                VStack(spacing: 2) {
                    // Roof
                    Triangle()
                        .fill(Color.brown)
                        .frame(width: 30, height: 15)
                    // House body
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 25, height: 20)
                        .overlay(
                            // Windows
                            HStack(spacing: 8) {
                                Circle().fill(Color.blue).frame(width: 6, height: 6)
                                Circle().fill(Color.blue).frame(width: 6, height: 6)
                            }
                        )
                }
            )
        case .park:
            AnyView(
                VStack(spacing: 2) {
                    // Trees
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 12, height: 12)
                        Circle().fill(Color.green).frame(width: 12, height: 12)
                        Circle().fill(Color.green).frame(width: 12, height: 12)
                    }
                    // Ground
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 30, height: 8)
                }
            )
        case .office:
            AnyView(
                VStack(spacing: 2) {
                    // Office building
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 25, height: 25)
                        .overlay(
                            // Windows grid
                            VStack(spacing: 2) {
                                HStack(spacing: 2) {
                                    Rectangle().fill(Color.white).frame(width: 4, height: 4)
                                    Rectangle().fill(Color.white).frame(width: 4, height: 4)
                                    Rectangle().fill(Color.white).frame(width: 4, height: 4)
                                }
                                HStack(spacing: 2) {
                                    Rectangle().fill(Color.white).frame(width: 4, height: 4)
                                    Rectangle().fill(Color.white).frame(width: 4, height: 4)
                                    Rectangle().fill(Color.white).frame(width: 4, height: 4)
                                }
                                HStack(spacing: 2) {
                                    Rectangle().fill(Color.white).frame(width: 4, height: 4)
                                    Rectangle().fill(Color.white).frame(width: 4, height: 4)
                                    Rectangle().fill(Color.white).frame(width: 4, height: 4)
                                }
                            }
                        )
                }
            )
        case .mall:
            AnyView(
                VStack(spacing: 2) {
                    // Mall building
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: 30, height: 20)
                        .overlay(
                            // Storefronts
                            HStack(spacing: 4) {
                                Rectangle().fill(Color.yellow).frame(width: 6, height: 8)
                                Rectangle().fill(Color.yellow).frame(width: 6, height: 8)
                                Rectangle().fill(Color.yellow).frame(width: 6, height: 8)
                                Rectangle().fill(Color.yellow).frame(width: 6, height: 8)
                            }
                        )
                }
            )
        case .skyscraper:
            AnyView(
                VStack(spacing: 2) {
                    // Tall building
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 20, height: 35)
                        .overlay(
                            // Windows
                            VStack(spacing: 1) {
                                ForEach(0..<7, id: \.self) { _ in
                                    HStack(spacing: 1) {
                                        Rectangle().fill(Color.white).frame(width: 3, height: 2)
                                        Rectangle().fill(Color.white).frame(width: 3, height: 2)
                                    }
                                }
                            }
                        )
                }
            )
        case .monument:
            AnyView(
                VStack(spacing: 2) {
                    // Monument base
                    Rectangle()
                        .fill(Color.gold)
                        .frame(width: 15, height: 8)
                    // Monument top
                    Triangle()
                        .fill(Color.gold)
                        .frame(width: 20, height: 25)
                }
            )
        }
    }
}

struct Building: Identifiable, Codable {
    let id: UUID
    let type: BuildingType
    var position: CGPoint
    let purchaseDate: Date
    
    init(type: BuildingType, position: CGPoint) {
        self.id = UUID()
        self.type = type
        self.position = position
        self.purchaseDate = Date()
    }
}

class CityManager: ObservableObject {
    static let shared = CityManager()
    
    @Published var buildings: [Building] = []
    @Published var selectedBuildingType: BuildingType?
    @Published var isPlacingBuilding = false
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    
    // Undo/Redo stacks
    private var undoStack: [[Building]] = []
    private var redoStack: [[Building]] = []
    private let maxUndoSteps = 20
    
    private init() {
        loadCityData()
        // Save initial state for undo
        if !buildings.isEmpty {
            saveStateForUndo()
        }
    }
    
    func purchaseBuilding(_ type: BuildingType, at position: CGPoint) -> Bool {
        let gemsManager = GemsManager.shared
        
        if gemsManager.spendGems(type.cost) {
            // Save current state for undo
            saveStateForUndo()
            
            let building = Building(type: type, position: position)
            buildings.append(building)
            saveCityData()
            
            // Clear redo stack when new action is performed
            redoStack.removeAll()
            canRedo = false
            canUndo = true
            
            return true
        }
        return false
    }
    
    func removeBuilding(_ building: Building) {
        // Save current state for undo
        saveStateForUndo()
        
        buildings.removeAll { $0.id == building.id }
        saveCityData()
        
        // Clear redo stack when new action is performed
        redoStack.removeAll()
        canRedo = false
        canUndo = true
    }
    
    func undo() {
        guard !undoStack.isEmpty else { return }
        
        // Save current state for redo
        redoStack.append(buildings)
        
        // Restore previous state
        buildings = undoStack.removeLast()
        saveCityData()
        
        canUndo = !undoStack.isEmpty
        canRedo = true
        
        print("🔄 Undo performed. Buildings: \(buildings.count), Undo stack: \(undoStack.count), Redo stack: \(redoStack.count)")
    }
    
    func redo() {
        guard !redoStack.isEmpty else { return }
        
        // Save current state for undo
        undoStack.append(buildings)
        
        // Restore next state
        buildings = redoStack.removeLast()
        saveCityData()
        
        canRedo = !redoStack.isEmpty
        canUndo = true
        
        print("🔄 Redo performed. Buildings: \(buildings.count), Undo stack: \(undoStack.count), Redo stack: \(redoStack.count)")
    }
    
    private func saveStateForUndo() {
        undoStack.append(buildings)
        
        // Limit undo stack size
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
        
        canUndo = true
        print("💾 State saved for undo. Buildings: \(buildings.count), Undo stack: \(undoStack.count)")
    }
    
    func canPurchaseBuilding(_ type: BuildingType) -> Bool {
        return GemsManager.shared.totalGems >= type.cost
    }
    
    func saveCity() {
        saveCityData()
        print("🏙️ City saved successfully!")
    }
    
    func saveCityData() {
        if let data = try? JSONEncoder().encode(buildings) {
            UserDefaults.standard.set(data, forKey: "cityData")
        }
    }
    
    private func loadCityData() {
        if let data = UserDefaults.standard.data(forKey: "cityData"),
           let buildings = try? JSONDecoder().decode([Building].self, from: data) {
            self.buildings = buildings
        }
    }
} 



// MARK: - Achievement Models

struct Achievement: Identifiable, Codable {
    var id = UUID()
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    var isUnlocked: Bool
    var unlockedDate: Date?
    var progress: Double // 0.0 to 1.0
    let target: Int
    var current: Int
}

enum AchievementCategory: String, CaseIterable, Codable {
    case distance = "Distance"
    case speed = "Speed"
    case consistency = "Consistency"
    case social = "Social"
    case special = "Special"
    case frequency = "Frequency"
    case milestone = "Milestone"
    case challenge = "Challenge"
    case unique = "Unique"
    case community = "Community"
    case seasonal = "Seasonal"
    case records = "Records"
    case app = "App"
    
    var color: Color {
        switch self {
        case .distance: return .blue
        case .speed: return .orange
        case .consistency: return .green
        case .social: return .purple
        case .special: return .gold
        case .frequency: return .indigo
        case .milestone: return .mint
        case .challenge: return .red
        case .unique: return .pink
        case .community: return .teal
        case .seasonal: return .brown
        case .records: return .yellow
        case .app: return .gray
        }
    }
} 

// MARK: - Achievement System

class AchievementManager: ObservableObject {
    static let shared = AchievementManager()
    
    @Published var achievements: [Achievement] = []
    @Published var unlockedAchievements: Set<String> = []
    
    private init() {
        loadAchievements()
        calculateAchievements()
    }
    
    private func loadAchievements() {
        // Initialize all achievements with default values
        achievements = [
            // Distance Achievements
            Achievement(
                title: "First Steps",
                description: "Complete your first run",
                icon: "figure.run",
                category: .distance,
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.0,
                target: 1,
                current: 0
            ),
            Achievement(
                title: "5K Runner",
                description: "Run 5 kilometers in a single session",
                icon: "flag.checkered",
                category: .distance,
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.0,
                target: 5000,
                current: 0
            ),
            Achievement(
                title: "10K Runner",
                description: "Run 10 kilometers in a single session",
                icon: "flag.checkered.2",
                category: .distance,
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.0,
                target: 10000,
                current: 0
            ),
            
            // Speed Achievements
            Achievement(
                title: "Speed Demon",
                description: "Achieve a pace faster than 7:00 min/mi",
                icon: "bolt.fill",
                category: .speed,
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.0,
                target: 420, // 7:00 min/mi in seconds
                current: 0
            ),
            Achievement(
                title: "Sprint King",
                description: "Achieve a pace faster than 6:00 min/mi",
                icon: "bolt.circle.fill",
                category: .speed,
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.0,
                target: 360, // 6:00 min/mi in seconds
                current: 0
            ),
            
            // Consistency Achievements
            Achievement(
                title: "Consistency King",
                description: "Run 7 days in a row",
                icon: "calendar",
                category: .consistency,
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.0,
                target: 7,
                current: 0
            ),
            Achievement(
                title: "Streak Master",
                description: "Run 30 days in a row",
                icon: "calendar.badge.plus",
                category: .consistency,
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.0,
                target: 30,
                current: 0
            ),
            
            // Frequency Achievements
            Achievement(
                title: "Frequent Runner",
                description: "Complete 10 runs",
                icon: "number.circle",
                category: .frequency,
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.0,
                target: 10,
                current: 0
            ),
            Achievement(
                title: "Dedicated Runner",
                description: "Complete 50 runs",
                icon: "number.circle.fill",
                category: .frequency,
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.0,
                target: 50,
                current: 0
            ),
            
            // Social Achievements
            Achievement(
                title: "Social Butterfly",
                description: "Add 5 friends",
                icon: "person.2.fill",
                category: .social,
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.0,
                target: 5,
                current: 0
            )
        ]
        
        // Load unlocked achievements from UserDefaults
        if let unlockedData = UserDefaults.standard.array(forKey: "unlockedAchievements") as? [String] {
            unlockedAchievements = Set(unlockedData)
        }
    }
    
    func calculateAchievements() {
        // Get the RunManager instance from the main app
        guard let runManager = RunManager.currentInstance else {
            print("❌ Could not find RunManager instance, using empty data")
            // Use empty data if RunManager is not available
            updateAchievementsWithData(recentRuns: [])
            return
        }
        let recentRuns = runManager.recentRuns
        updateAchievementsWithData(recentRuns: recentRuns)
    }
    
    private func updateAchievementsWithData(recentRuns: [RunSession]) {
        // Calculate total runs
        let totalRuns = recentRuns.count
        
        // Calculate total distance (unused for now but kept for future use)
        _ = recentRuns.reduce(0.0) { $0 + $1.distance }
        
        // Calculate best single run distance
        let bestSingleRunDistance = recentRuns.map { $0.distance }.max() ?? 0.0
        
        // Calculate best pace
        let bestPace = recentRuns.map { $0.averagePace }.min() ?? Double.infinity
        
        // Calculate streak
        let currentStreak = calculateCurrentStreak(runs: recentRuns)
        
        // Update achievements based on real data
        for i in 0..<achievements.count {
            var achievement = achievements[i]
            
            switch achievement.title {
            case "First Steps":
                achievement.current = totalRuns
                achievement.progress = min(Double(totalRuns), 1.0)
                achievement.isUnlocked = totalRuns >= 1
                if achievement.isUnlocked && achievement.unlockedDate == nil {
                    achievement.unlockedDate = Date()
                    unlockedAchievements.insert(achievement.title)
                }
                
            case "5K Runner":
                achievement.current = Int(bestSingleRunDistance)
                achievement.progress = min(bestSingleRunDistance / 5000.0, 1.0)
                achievement.isUnlocked = bestSingleRunDistance >= 5000
                if achievement.isUnlocked && achievement.unlockedDate == nil {
                    achievement.unlockedDate = Date()
                    unlockedAchievements.insert(achievement.title)
                }
                
            case "10K Runner":
                achievement.current = Int(bestSingleRunDistance)
                achievement.progress = min(bestSingleRunDistance / 10000.0, 1.0)
                achievement.isUnlocked = bestSingleRunDistance >= 10000
                if achievement.isUnlocked && achievement.unlockedDate == nil {
                    achievement.unlockedDate = Date()
                    unlockedAchievements.insert(achievement.title)
                }
                
            case "Speed Demon":
                // Convert pace to seconds (lower is faster)
                let paceInSeconds = bestPace == Double.infinity ? Double.infinity : bestPace
                achievement.current = paceInSeconds == Double.infinity ? 0 : Int(paceInSeconds)
                achievement.progress = paceInSeconds == Double.infinity ? 0.0 : max(0.0, (420.0 - paceInSeconds) / 420.0)
                achievement.isUnlocked = paceInSeconds <= 420.0
                if achievement.isUnlocked && achievement.unlockedDate == nil {
                    achievement.unlockedDate = Date()
                    unlockedAchievements.insert(achievement.title)
                }
                
            case "Sprint King":
                let paceInSeconds = bestPace == Double.infinity ? Double.infinity : bestPace
                achievement.current = paceInSeconds == Double.infinity ? 0 : Int(paceInSeconds)
                achievement.progress = paceInSeconds == Double.infinity ? 0.0 : max(0.0, (360.0 - paceInSeconds) / 360.0)
                achievement.isUnlocked = paceInSeconds <= 360.0
                if achievement.isUnlocked && achievement.unlockedDate == nil {
                    achievement.unlockedDate = Date()
                    unlockedAchievements.insert(achievement.title)
                }
                
            case "Consistency King":
                achievement.current = currentStreak
                achievement.progress = min(Double(currentStreak) / 7.0, 1.0)
                achievement.isUnlocked = currentStreak >= 7
                if achievement.isUnlocked && achievement.unlockedDate == nil {
                    achievement.unlockedDate = Date()
                    unlockedAchievements.insert(achievement.title)
                }
                
            case "Streak Master":
                achievement.current = currentStreak
                achievement.progress = min(Double(currentStreak) / 30.0, 1.0)
                achievement.isUnlocked = currentStreak >= 30
                if achievement.isUnlocked && achievement.unlockedDate == nil {
                    achievement.unlockedDate = Date()
                    unlockedAchievements.insert(achievement.title)
                }
                
            case "Frequent Runner":
                achievement.current = totalRuns
                achievement.progress = min(Double(totalRuns) / 10.0, 1.0)
                achievement.isUnlocked = totalRuns >= 10
                if achievement.isUnlocked && achievement.unlockedDate == nil {
                    achievement.unlockedDate = Date()
                    unlockedAchievements.insert(achievement.title)
                }
                
            case "Dedicated Runner":
                achievement.current = totalRuns
                achievement.progress = min(Double(totalRuns) / 50.0, 1.0)
                achievement.isUnlocked = totalRuns >= 50
                if achievement.isUnlocked && achievement.unlockedDate == nil {
                    achievement.unlockedDate = Date()
                    unlockedAchievements.insert(achievement.title)
                }
                
            case "Social Butterfly":
                // For now, set to 0 - would need friend system integration
                achievement.current = 0
                achievement.progress = 0.0
                achievement.isUnlocked = false
                
            default:
                break
            }
            
            achievements[i] = achievement
        }
        
        // Save unlocked achievements
        UserDefaults.standard.set(Array(unlockedAchievements), forKey: "unlockedAchievements")
    }
    
    private func calculateCurrentStreak(runs: [RunSession]) -> Int {
        guard !runs.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let today = Date()
        var streak = 0
        
        // Sort runs by date (most recent first)
        let sortedRuns = runs.sorted { $0.startTime > $1.startTime }
        
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
    
    func refreshAchievements() {
        calculateAchievements()
    }
} 

// MARK: - Workout Models
struct Workout: Identifiable, Codable {
    var id: UUID
    let startTime: Date
    let endTime: Date
    let distance: Double // in meters
    let duration: TimeInterval
    let averageSpeed: Double // in m/s
    let peakSpeed: Double // in m/s
    let route: [Coordinate]
    let category: WorkoutCategory
    
    init(startTime: Date, endTime: Date, distance: Double, duration: TimeInterval, averageSpeed: Double, peakSpeed: Double, route: [Coordinate], category: WorkoutCategory) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.duration = duration
        self.averageSpeed = averageSpeed
        self.peakSpeed = peakSpeed
        self.route = route
        self.category = category
    }
}

struct Coordinate: Codable {
    let latitude: Double
    let longitude: Double
    
    var clLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

enum WorkoutCategory: String, CaseIterable, Codable {
    case running = "Running"
    case walking = "Walking"
    case cycling = "Cycling"
    
    var icon: String {
        switch self {
        case .running:
            return "figure.run"
        case .walking:
            return "figure.walk"
        case .cycling:
            return "figure.outdoor.cycle"
        }
    }
}

class WorkoutStore: ObservableObject {
    @Published var workouts: [Workout] = []
    private let userDefaults = UserDefaults.standard
    
    // Shared instance for app-wide access
    static let shared = WorkoutStore()
    
    init() {
        loadWorkouts()
        
        // Listen for user changes to reload data
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadWorkouts()
        }
    }
    
    func saveWorkout(_ workout: Workout) {
        print("💾 WorkoutStore.saveWorkout called with workout ID: \(workout.id)")
        print("💾 Current workouts count before save: \(workouts.count)")
        
        workouts.append(workout)
        saveWorkouts()
        
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            self.objectWillChange.send() // Explicitly trigger UI update
        }
        
        // Save to Supabase
        Task {
            await SupabaseManager.shared.saveWorkout(workout)
        }
        
        print("💾 Workout saved to store. Total workouts: \(workouts.count)")
        print("💾 WorkoutStore.objectWillChange.send() called")
    }
    
    func deleteWorkout(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
        saveWorkouts()
    }
    
    func clearAllWorkouts() {
        workouts.removeAll()
        saveWorkouts()
    }
    
    private func getWorkoutsKey() -> String {
        let userId = DataManager.shared.getUserId() ?? "guest"
        return "workouts_\(userId)"
    }
    
    private func loadWorkouts() {
        let key = getWorkoutsKey()
        print("📱 loadWorkouts called with key: \(key)")
        
        if let data = userDefaults.data(forKey: key),
           let decodedWorkouts = try? JSONDecoder().decode([Workout].self, from: data) {
            workouts = decodedWorkouts
            print("📱 Successfully loaded \(workouts.count) workouts from UserDefaults")
        } else {
            print("📱 No saved workouts found for user")
        }
    }
    
    private func saveWorkouts() {
        let key = getWorkoutsKey()
        print("💾 saveWorkouts called with key: \(key)")
        print("💾 Attempting to save \(workouts.count) workouts")
        
        if let encoded = try? JSONEncoder().encode(workouts) {
            userDefaults.set(encoded, forKey: key)
            print("💾 Successfully saved \(workouts.count) workouts to UserDefaults")
        } else {
            print("❌ Failed to encode workouts for saving")
        }
    }
} 

// MARK: - User Stats

struct UserStats: Codable {
    let totalDistance: Double
    let totalTime: TimeInterval
    let averagePace: Double
    let longestRun: Double
    let currentStreak: Int
    let longestStreak: Int
    let totalRuns: Int
    let totalGems: Int
    let achievements: [String]
    
    init(totalDistance: Double = 0, totalTime: TimeInterval = 0, averagePace: Double = 0, longestRun: Double = 0, currentStreak: Int = 0, longestStreak: Int = 0, totalRuns: Int = 0, totalGems: Int = 0, achievements: [String] = []) {
        self.totalDistance = totalDistance
        self.totalTime = totalTime
        self.averagePace = averagePace
        self.longestRun = longestRun
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.totalRuns = totalRuns
        self.totalGems = totalGems
        self.achievements = achievements
    }
} 