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
    var showSpeed: Bool = true
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
        dailySecondsCompleted += seconds
        checkDailyReset() // Check if it's a new day
        saveGemsData()
        print("⏱️ Added \(seconds) seconds to daily progress. Total: \(dailySecondsCompleted)")
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
        
        // Speed bonus: +1 gem per mph over 6 mph (up to 10 mph)
        let speedMph = averageSpeed
        if speedMph > 6 {
            let speedBonus = min(speedMph - 6, 4) // Max 4 gems from speed (6-10 mph)
            gems += Int(speedBonus)
        }
        
        // Distance bonus: +1 gem per mile
        let distanceMiles = distance / 1609.34 // Convert meters to miles
        gems += Int(distanceMiles)
        
        // Streak bonus: +5 gems for consecutive days
        if let lastRun = lastRunDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(lastRun) || calendar.isDateInYesterday(lastRun) {
                gems += 5
            }
        }
        
        return gems
    }
    
    func awardGemsForRun(distance: Double, averageSpeed: Double, duration: TimeInterval) {
        let gemsEarned = calculateGemsForRun(distance: distance, averageSpeed: averageSpeed)
        
        print("🎯 Gems Calculation:")
        print("   Distance: \(distance) meters (\(distance / 1609.34) miles)")
        print("   Average Speed: \(averageSpeed) mph")
        print("   Gems Earned: \(gemsEarned)")
        print("   Previous Total: \(totalGems)")
        
        // Check if this is a new day
        let today = Date()
        if let lastRun = lastRunDate {
            let calendar = Calendar.current
            if !calendar.isDate(lastRun, inSameDayAs: today) {
                gemsEarnedToday = 0 // Reset daily gems
                print("   New day - resetting daily gems")
            }
        }
        
        totalGems += gemsEarned
        gemsEarnedToday += gemsEarned
        lastRunDate = today
        
        print("   New Total: \(totalGems)")
        print("   Daily Gems: \(gemsEarnedToday)")
        print("   Last Run Date: \(lastRunDate?.description ?? "None")")
        
        saveGemsData()
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func spendGems(_ amount: Int) -> Bool {
        if totalGems >= amount {
            totalGems -= amount
            saveGemsData()
            return true
        }
        return false
    }
    
    func refreshGemsData() {
        loadGemsData()
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

struct MockFriend: Identifiable {
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

enum FriendStatus {
    case online
    case offline
    case running
}

struct MockLeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let distance: Double
    let duration: TimeInterval
    let averagePace: Double
    let totalRuns: Int
    let points: Int
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct CompactStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
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
                // Show feet for distances less than 0.1 miles
                let feet = meters * 3.28084 // Convert meters to feet
                return String(format: "%.0f ft", feet)
            } else {
                // Show miles rounded to nearest hundredth
                let roundedMiles = round(miles * 100) / 100
                return String(format: "%.2f mi", roundedMiles)
            }
        case .metric:
            let kilometers = metersToKilometers(meters)
            return String(format: "%.2f km", kilometers)
        }
    }
    
    static func formatPace(_ pace: Double, unitSystem: UnitSystem) -> String {
        // Handle invalid pace values
        guard pace.isFinite && pace > 0 else {
            return "0:00"
        }
        
        switch unitSystem {
        case .metric:
            let minutes = Int(pace)
            let seconds = Int((pace - Double(minutes)) * 60)
            return String(format: "%d:%02d", minutes, seconds)
        case .imperial:
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
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let isUnlocked: Bool
    let unlockedDate: Date?
    let progress: Double // 0.0 to 1.0
    let target: Int
    let current: Int
}

enum AchievementCategory: String, CaseIterable, Codable {
    case distance = "Distance"
    case speed = "Speed"
    case consistency = "Consistency"
    case social = "Social"
    case special = "Special"
    
    var color: Color {
        switch self {
        case .distance: return .blue
        case .speed: return .orange
        case .consistency: return .green
        case .social: return .purple
        case .special: return .gold
        }
    }
} 