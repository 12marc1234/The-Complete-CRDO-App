//
//  ContentView.swift
//  CRDO
//
//  Created by Ethan Yip on 7/25/25.
//  Refactored for running-focused experience
//

import SwiftUI
import UserNotifications
import CoreLocation
import MapKit
import Combine

// MARK: - RunManager

class RunManager: NSObject, ObservableObject {
    static let shared = RunManager()
    
    @Published var isRunActive = false
    @Published var currentRun: RunSession?
    @Published var runHistory: [RunSession] = []
    @Published var currentLocation: CLLocation?
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0
    @Published var calories: Int = 0
    @Published var averagePace: Double = 0
    @Published var currentPace: Double = 0
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var freezeTokensRemaining: Int = 3
    @Published var dailyMinutesGoal: Int = 15
    @Published var dailySecondsCompleted: Int = 0
    @Published var lastRunDate: Date?
    
    let locationManager = CLLocationManager()
    private var timer: Timer?
    private var startLocation: CLLocation?
    private var lastLocation: CLLocation?
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        setupLocationManager()
        loadRunHistory()
        loadStreakData()
        loadDailyGoalData()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1 // Update every 1 meter for maximum precision
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Request authorization immediately
        let authStatus = locationManager.authorizationStatus
        print("📍 Initial location authorization status: \(authStatus.rawValue)")
        
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            // Start location updates immediately if already authorized
            locationManager.startUpdatingLocation()
            print("🚀 Location updates started immediately")
        }
    }
    
    func startRun() {
        guard !isRunActive else { return }
        
        print("Starting run")
        
        isRunActive = true
        elapsedTime = 0
        distance = 0
        calories = 0
        averagePace = 0
        currentPace = 0
        routeCoordinates.removeAll()
        
        // Check location authorization status first
        let authStatus = locationManager.authorizationStatus
        print("Current location authorization status: \(authStatus.rawValue)")
        
        // Request location permission and start tracking
        locationManager.requestWhenInUseAuthorization()
        
        // Add a small delay to ensure authorization is processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.locationManager.startUpdatingLocation()
            print("Location updates requested")
        }
        
        // Start timer
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.elapsedTime += 1
            self.updateCalories()
            self.updatePace()
        }
        
        startLocation = currentLocation
        
        // Call backend to create run session
        DataManager.shared.startRun()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to start run on backend: \(error)")
                    }
                },
                receiveValue: { runId in
                    print("✅ Run started on backend with ID: \(runId)")
                    // Store the runId for later use in endRun
                    UserDefaults.standard.set(runId, forKey: "currentRunId")
                }
            )
            .store(in: &cancellables)
    }
    
    func pauseRun() {
        isRunActive = false
        timer?.invalidate()
        timer = nil
        locationManager.stopUpdatingLocation()
    }
    
    func endRun() {
        guard isRunActive else { return }
        
        isRunActive = false
        self.timer?.invalidate()
        self.timer = nil
        locationManager.stopUpdatingLocation()
        
        // Create and save run session
        let run = RunSession(
            id: UUID(),
            startTime: Date().addingTimeInterval(-elapsedTime),
            endTime: Date(),
            duration: elapsedTime,
            distance: distance,
            calories: calories,
            averagePace: averagePace,
            maxPace: currentPace,
            route: routeCoordinates.map { RunSession.Coordinate(coordinate: $0) },
            isCompleted: true
        )
        
        runHistory.append(run)
        saveRunHistory()
        updateStreak()
        updateDailyProgress()
        
        // Upload to Supabase backend
        let distanceInMiles = distance / 1609.34 // Convert meters to miles
        let averageSpeedMph = (distance / elapsedTime) * 2.237 // Convert m/s to mph
        let peakSpeedMph = currentPace > 0 ? (1000 / currentPace) * 2.237 : 0 // Convert pace to mph
        
        // Get the runId from backend (stored when run started)
        let runId = UserDefaults.standard.string(forKey: "currentRunId") ?? UUID().uuidString
        
        DataManager.shared.finishRun(
            runId: runId,
            distance: distanceInMiles,
            duration: elapsedTime,
            averageSpeed: averageSpeedMph,
            peakSpeed: peakSpeedMph
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Failed to finish run on backend: \(error)")
                }
            },
            receiveValue: { response in
                print("✅ Run finished on backend")
            }
        )
        .store(in: &cancellables)
    }
    
    private func updateCalories() {
        // Simple calorie calculation based on time and pace
        let caloriesPerMinute = 10.0 // Base rate
        let paceMultiplier = max(0.5, min(2.0, 1.0 / max(currentPace, 1.0)))
        calories = Int(elapsedTime / 60 * caloriesPerMinute * paceMultiplier)
    }
    
    private func updatePace() {
        guard distance > 0 else { return }
        let paceInMinutesPerMile = (elapsedTime / 60) / (distance / 1609.34)
        currentPace = paceInMinutesPerMile
        averagePace = paceInMinutesPerMile
    }
    
    private func loadRunHistory() {
        if let data = UserDefaults.standard.data(forKey: "runHistory"),
           let history = try? JSONDecoder().decode([RunSession].self, from: data) {
            runHistory = history
        }
    }
    
    private func saveRunHistory() {
        if let data = try? JSONEncoder().encode(runHistory) {
            UserDefaults.standard.set(data, forKey: "runHistory")
        }
    }
    
    private func loadStreakData() {
        currentStreak = UserDefaults.standard.integer(forKey: "currentStreak")
        longestStreak = UserDefaults.standard.integer(forKey: "longestStreak")
        freezeTokensRemaining = UserDefaults.standard.integer(forKey: "freezeTokensRemaining")
    }
    
    private func loadDailyGoalData() {
        dailySecondsCompleted = UserDefaults.standard.integer(forKey: "dailySecondsCompleted")
        lastRunDate = UserDefaults.standard.object(forKey: "lastRunDate") as? Date
        
        // Reset daily progress if it's a new day
        if let lastRun = lastRunDate {
            let calendar = Calendar.current
            if !calendar.isDate(lastRun, inSameDayAs: Date()) {
                dailySecondsCompleted = 0
                UserDefaults.standard.set(dailySecondsCompleted, forKey: "dailySecondsCompleted")
            }
        }
    }
    
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get the last run date from UserDefaults
        let lastRunDate = UserDefaults.standard.object(forKey: "lastRunDate") as? Date
        
        // Check if we already counted today's streak
        let lastStreakDate = UserDefaults.standard.object(forKey: "lastStreakDate") as? Date
        let lastStreakDay = lastStreakDate != nil ? calendar.startOfDay(for: lastStreakDate!) : nil
        
        // Only update streak if we haven't already counted today's streak
        if lastStreakDay != today {
            // Check if we completed 15 minutes today
            let todaySeconds = UserDefaults.standard.integer(forKey: "dailySecondsCompleted")
            let hasCompleted15Minutes = todaySeconds >= 15 * 60 // 15 minutes = 900 seconds
            
            if hasCompleted15Minutes {
                if lastStreakDay == nil {
                    // First run ever
                    currentStreak = 1
                } else if let lastStreak = lastStreakDate,
                          calendar.isDate(lastStreak, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today)!) {
                    // Continuous streak (last run was yesterday)
                    currentStreak += 1
                } else {
                    // Gap in streak, reset to 1
                    currentStreak = 1
                }
                
                if currentStreak > longestStreak {
                    longestStreak = currentStreak
                }
                
                // Mark today's streak as counted
                UserDefaults.standard.set(today, forKey: "lastStreakDate")
                UserDefaults.standard.set(currentStreak, forKey: "currentStreak")
                UserDefaults.standard.set(longestStreak, forKey: "longestStreak")
                
                print("🔥 Streak updated: \(currentStreak) days (15+ minutes completed)")
            } else {
                print("⏰ Not enough time today: \(todaySeconds/60) minutes (need 15 for streak)")
            }
        }
    }
    
    private func updateDailyProgress() {
        let runSeconds = Int(elapsedTime)
        dailySecondsCompleted += runSeconds
        
        // Cap at daily goal to avoid overflow (15 minutes = 900 seconds)
        let dailyGoalSeconds = dailyMinutesGoal * 60
        if dailySecondsCompleted > dailyGoalSeconds {
            dailySecondsCompleted = dailyGoalSeconds
        }
        
        lastRunDate = Date()
        
        UserDefaults.standard.set(dailySecondsCompleted, forKey: "dailySecondsCompleted")
        UserDefaults.standard.set(lastRunDate, forKey: "lastRunDate")
        
        print("⏱️ Daily progress updated: \(dailySecondsCompleted)s / \(dailyGoalSeconds)s")
    }
    
    func useFreezeToken() {
        guard freezeTokensRemaining > 0 else { return }
        freezeTokensRemaining -= 1
        UserDefaults.standard.set(freezeTokensRemaining, forKey: "freezeTokensRemaining")
    }
}

// MARK: - AuthenticationTracker

class AuthenticationTracker: ObservableObject {
    static let shared = AuthenticationTracker()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Load authentication state from UserDefaults
        if let userId = UserDefaults.standard.string(forKey: "userId"),
           let token = UserDefaults.standard.string(forKey: "authToken") {
            isAuthenticated = true
            // Load user data if available
            if let userData = UserDefaults.standard.data(forKey: "userData"),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                currentUser = user
            }
        }
    }
    
    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        DataManager.shared.login(email: email, password: password)
            .sink(
                receiveCompletion: { completion in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { success in
                    DispatchQueue.main.async {
                        self.isAuthenticated = true
                        self.errorMessage = nil
                        
                        // Save authentication data
                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func signUp(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        DataManager.shared.signup(email: email, password: password)
            .sink(
                receiveCompletion: { completion in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { success in
                    DispatchQueue.main.async {
                        self.isAuthenticated = true
                        self.errorMessage = nil
                        
                        // Save authentication data
                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func signOut() {
        isAuthenticated = false
        currentUser = nil
        
        // Clear authentication data
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "userData")
    }
}

// MARK: - Models

struct RunSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var distance: Double // in meters
    var calories: Int
    var averagePace: Double // minutes per mile
    var maxPace: Double
    var route: [Coordinate]?
    var isCompleted: Bool
    
    // Custom coordinate struct for Codable support
    struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double
        
        init(coordinate: CLLocationCoordinate2D) {
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
        }
        
        var clCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
}

struct Option: Identifiable, Equatable {
    let id: Int
    let icon: String
    let text: String
}

struct UserPreferences: Codable {
    var runningExperience: Int?
    var weeklyMileage: Int?
    var preferredPace: Int?
    var runningGoals: Int?
    var onboardingCompleted: Bool = false
    var freezeTokensRemaining: Int = 3
    
    static func load() -> UserPreferences {
        if let data = UserDefaults.standard.data(forKey: "userPreferences"),
           let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            return preferences
        }
        return UserPreferences()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "userPreferences")
        }
    }
}

struct ExportData: Codable {
    let runHistory: [RunSession]
    let currentStreak: Int
    let longestStreak: Int
    let dailyGoal: Int
    let freezeTokens: Int
    let exportDate: Date
}

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case experience
    case mileage
    case pace
    case goals
    case final

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .experience:   return "What's your running experience?"
        case .mileage:      return "How much do you run weekly?"
        case .pace:         return "What's your preferred pace?"
        case .goals:        return "What are your running goals?"
        case .final:        return "Ready to start your streak?"
        }
    }

    var subtitle: String? {
        switch self {
        case .experience:
            return "This helps us tailor your experience"
        case .mileage:
            return "We'll use this to suggest challenges"
        case .pace:
            return "For personalized pace recommendations"
        case .goals:
            return "Let's build a plan together"
        case .final:
            return "Your running journey starts now."
        }
    }

    var titleFont: Font {
        switch self {
        case .experience, .final:
            return .system(size: 28, weight: .bold, design: .rounded)
        case .mileage:
            return .system(size: 24, weight: .bold, design: .rounded)
        case .pace:
            return .system(size: 22, weight: .bold, design: .rounded)
        case .goals:
            return .system(size: 20, weight: .bold, design: .rounded)
        }
    }

    /// Options shown for the step (nil for the last one)
    var options: [Option]? {
        switch self {
        case .experience:
            return [
                .init(id: 0, icon: "🆕", text: "Just starting out"),
                .init(id: 1, icon: "🏃‍♂️", text: "Been running for a few months"),
                .init(id: 2, icon: "🏃‍♀️", text: "Regular runner for over a year"),
                .init(id: 3, icon: "⚡", text: "Experienced runner")
            ]
        case .mileage:
            return [
                .init(id: 0, icon: "🐌", text: "0-5 miles per week"),
                .init(id: 1, icon: "🚶‍♂️", text: "5-15 miles per week"),
                .init(id: 2, icon: "🏃‍♂️", text: "15-30 miles per week"),
                .init(id: 3, icon: "🏃‍♀️", text: "30+ miles per week")
            ]
        case .pace:
            return [
                .init(id: 0, icon: "🐌", text: "Easy pace (10+ min/mile)"),
                .init(id: 1, icon: "🚶‍♂️", text: "Moderate (8-10 min/mile)"),
                .init(id: 2, icon: "🏃‍♂️", text: "Good pace (6-8 min/mile)"),
                .init(id: 3, icon: "⚡", text: "Fast (under 6 min/mile)")
            ]
        case .goals:
            return [
                .init(id: 0, icon: "🎯", text: "Build consistency"),
                .init(id: 1, icon: "📈", text: "Improve pace"),
                .init(id: 2, icon: "🏃‍♀️", text: "Increase distance"),
                .init(id: 3, icon: "🏆", text: "Train for a race")
            ]
        case .final:
            return nil
        }
    }

    static var total: Int { Self.allCases.count }
}

// MARK: - ViewModel

final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .experience
    @Published var selected: [OnboardingStep: Int] = [:]
    @Published var showingMainApp = false
    @Published var isTransitioning = false
    @Published var userPreferences: UserPreferences = UserPreferences.load()

    func select(_ optionID: Int, in step: OnboardingStep) {
        guard !isTransitioning else { return }
        selected[step] = optionID
        selectAndAdvance()
    }

    private func selectAndAdvance() {
        isTransitioning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                if let next = OnboardingStep(rawValue: self.currentStep.rawValue + 1) {
                    self.currentStep = next
                }
                self.isTransitioning = false
            }
        }
    }

    func back() {
        guard currentStep.rawValue > 0 else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .experience
        }
    }

    func next() {
        guard currentStep.rawValue < OnboardingStep.total - 1 else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .final
        }
    }

    func startApp() {
        // Save user preferences before starting the app
        saveUserPreferences()
        
        withAnimation(.easeInOut(duration: 0.8)) {
            showingMainApp = true
        }
    }
    
    private func saveUserPreferences() {
        var preferences = UserPreferences()
        preferences.runningExperience = selected[.experience]
        preferences.weeklyMileage = selected[.mileage]
        preferences.preferredPace = selected[.pace]
        preferences.runningGoals = selected[.goals]
        preferences.onboardingCompleted = true
        
        preferences.save()
        userPreferences = preferences
    }
}

// MARK: - Root View

struct ContentView: View {
    @StateObject private var vm = OnboardingViewModel()
    @StateObject private var authTracker = AuthenticationTracker.shared
    @State private var cancellables = Set<AnyCancellable>()

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
            } else if vm.showingMainApp || vm.userPreferences.onboardingCompleted {
                MainAppView(userPreferences: vm.userPreferences, authTracker: authTracker)
                    .transition(.opacity.combined(with: .scale))
            } else {
                VStack(spacing: 0) {
                    ProgressIndicator(currentIndex: vm.currentStep.rawValue, total: OnboardingStep.total)
                        .padding(.top, 40)
                        .padding(.horizontal, 20)

                    TabView(selection: $vm.currentStep) {
                        ForEach(OnboardingStep.allCases) { step in
                            Group {
                                if let options = step.options {
                                    OnboardingPanel(
                                        step: step,
                                        options: options,
                                        selectedID: Binding(
                                            get: { vm.selected[step] },
                                            set: { _ in } // selection handled inside select()
                                        ),
                                        onSelect: { id in vm.select(id, in: step) }
                                    )
                                } else {
                                    FinalPanel()
                                }
                            }
                            .tag(step)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: vm.currentStep)

                    NavigationButtons(
                        currentIndex: vm.currentStep.rawValue,
                        total: OnboardingStep.total,
                        onBack: vm.back,
                        onNext: vm.next,
                        onStart: vm.startApp
                    )
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    let currentIndex: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= currentIndex ? Color.gold : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            }
        }
    }
}

// MARK: - Generic Onboarding Panel

struct OnboardingPanel: View {
    let step: OnboardingStep
    let options: [Option]
    @Binding var selectedID: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 25) {
            Spacer()

            VStack(spacing: 15) {
                Text(step.title)
                    .font(step.titleFont)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                if let subtitle = step.subtitle {
                    if step == .experience {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.gold)
                            .tracking(2)
                    } else {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.gold)
                            .italic()
                    }
                }

                if step == .experience {
                    Text("What kind of progress are you secretly hoping to see?")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }

            VStack(spacing: 12) {
                ForEach(options) { option in
                    SelectionOption(
                        icon: option.icon,
                        text: option.text,
                        isSelected: selectedID == option.id,
                        action: { onSelect(option.id) }
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: - Final Panel

struct FinalPanel: View {
    var body: some View {
        VStack(spacing: 25) {
            Spacer()

            VStack(spacing: 15) {
                Text("Ready to build your city?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Your journey starts now.")
                    .font(.title3)
                    .foregroundColor(.gold)
            }

            GlassCard {
                VStack(spacing: 20) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gold)

                    Text("Every step counts. Every run builds. Every streak matters.")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Let's make discipline feel different.")
                        .font(.headline)
                        .foregroundColor(.gold)
                        .italic()
                }
                .padding(25)
            }

            Spacer()
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Navigation

struct NavigationButtons: View {
    let currentIndex: Int
    let total: Int
    let onBack: () -> Void
    let onNext: () -> Void
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            if currentIndex > 0 {
                Button("Back", action: onBack)
                    .buttonStyle(GlassButtonStyle())
            }

            Spacer()

            if currentIndex < total - 1 {
                Button("Next", action: onNext)
                    .buttonStyle(GlassButtonStyle())
            } else {
                Button("Start Building", action: onStart)
                    .buttonStyle(GlassButtonStyle())
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Reusable bits

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.gold.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: .gold.opacity(0.3), radius: 10, x: 0, y: 5)
            )
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.gold, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SelectionOption: View {
    let icon: String
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Text(icon)
                    .font(.title2)

                Text(text)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.gold)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? Color.gold.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}

// MARK: - User Preferences Summary

struct UserPreferencesSummary: View {
    let preferences: UserPreferences
    
    private func getOptionText(for step: OnboardingStep, optionID: Int?) -> String {
        guard let optionID = optionID,
              let options = step.options else { return "Not selected" }
        
        return options.first { $0.id == optionID }?.text ?? "Not selected"
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                Text("Your Preferences")
                    .font(.headline)
                    .foregroundColor(.gold)
                
                VStack(spacing: 12) {
                    PreferenceRow(
                        title: "Fitness Goal",
                        text: getOptionText(for: .experience, optionID: preferences.runningExperience),
                        icon: "🎯"
                    )
                    
                    PreferenceRow(
                        title: "Motivation",
                        text: getOptionText(for: .mileage, optionID: preferences.weeklyMileage),
                        icon: "💪"
                    )
                    
                    PreferenceRow(
                        title: "Streak Style",
                        text: getOptionText(for: .pace, optionID: preferences.preferredPace),
                        icon: "🔥"
                    )
                    
                    PreferenceRow(
                        title: "Goals",
                        text: getOptionText(for: .goals, optionID: preferences.runningGoals),
                        icon: "🎯"
                    )
                }
            }
            .padding(20)
        }
    }
}

struct PreferenceRow: View {
    let title: String
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gold)
                    .fontWeight(.semibold)
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

// MARK: - Top Navigation Bar

struct TopNavigationBar: View {
    @Binding var showingUserSettings: Bool
    @State private var menuAnimation = false
    
    var body: some View {
        HStack {
            // App Title
            Text("CRDO")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.gold)
            
            Spacer()
            
            // User Profile Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingUserSettings = true
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.gold.opacity(0.4), lineWidth: 1)
                        )
                    
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gold)
                        .scaleEffect(menuAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: menuAnimation)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Settings Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingUserSettings = true
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.gold.opacity(0.4), lineWidth: 1)
                        )
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gold)
                        .scaleEffect(menuAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: menuAnimation)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .overlay(
                    Rectangle()
                        .stroke(Color.gold.opacity(0.2), lineWidth: 0.5)
                )
        )
        .ignoresSafeArea(.all, edges: .top)
        .onAppear {
            menuAnimation = true
        }
    }
}

// MARK: - Progress Section

struct ProgressSection: View {
    let progress: Double
    let timeElapsed: Int
    let isActive: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onWorkoutMap: () -> Void
    let currentStreak: Int
    @Binding var showingUserSettings: Bool
    @Binding var userSettingsInitialTab: Int
    
    @State private var glowAnimation = false
    @State private var pulseAnimation = false
    
    private var timeString: String {
        let minutes = timeElapsed / 60
        let seconds = timeElapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var progressTitle: String {
        if isActive {
            return "WORKOUT IN PROGRESS"
        } else {
            return "DAILY GOAL: 15 MIN"
        }
    }
    
    private var progressPercentage: Int {
        Int(progress * 100)
    }
    
    private var dynamicTitle: String {
        let dayNumber = currentStreak + 1 // Add 1 because we're on the current day
        let suffix = getDaySuffix(dayNumber)
        return "\(dayNumber)\(suffix) DAILY CRDO"
    }
    
    private func getDaySuffix(_ day: Int) -> String {
        if day >= 11 && day <= 13 {
            return "TH"
        }
        
        switch day % 10 {
        case 1:
            return "ST"
        case 2:
            return "ND"
        case 3:
            return "RD"
        default:
            return "TH"
        }
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Header
            VStack(spacing: 8) {
                Text(progressTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
            }
            
            // Progress Circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                    .frame(width: 200, height: 200)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
            LinearGradient(
                            gradient: Gradient(colors: [.gold, .orange]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Glow effect
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.gold.opacity(0.3), lineWidth: 20)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .blur(radius: glowAnimation ? 8 : 4)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowAnimation)
                
                // Center content
                VStack(spacing: 8) {
                    Text(timeString)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("\(progressPercentage)%")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.gold)
                    
                    Text("STREAK MAINTAINED: \(currentStreak)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gold.opacity(0.8))
                        .tracking(1)
                    
                    if isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                            
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            

            
            // Compact Glassy Button Grid
            VStack(spacing: 12) {
                // Main Workout Button
                Button(action: {
                    if isActive {
                        onStop()
                    } else {
                        onStart()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: isActive ? "pause.fill" : "play.fill")
                            .font(.title2)
                        
                        Text(isActive ? "Pause Workout" : "Start Workout")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(isActive ? Color.red.opacity(0.3) : Color.gold.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(isActive ? Color.red.opacity(0.6) : Color.gold.opacity(0.6), lineWidth: 1.5)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.black.opacity(0.2))
                                    .blur(radius: 10)
                            )
                    )
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: pulseAnimation)
                }
                
                // Secondary Buttons Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    // Workout History
                    Button(action: {
                        userSettingsInitialTab = 0
                        showingUserSettings = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title3)
                                .foregroundColor(.gold)
                            
                            Text("HISTORY")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gold.opacity(0.4), lineWidth: 1)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.black.opacity(0.1))
                                        .blur(radius: 5)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Personal Stats
                    Button(action: {
                        // Placeholder action for personal stats
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.bar.fill")
                                .font(.title3)
                                .foregroundColor(.gold)
                            
                            Text("STATS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gold.opacity(0.4), lineWidth: 1)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.black.opacity(0.1))
                                        .blur(radius: 5)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Personal Development
                    Button(action: {
                        // Placeholder action for personal development
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "brain.head.profile")
                                .font(.title3)
                                .foregroundColor(.gold)
                            
                            Text("DEVELOPMENT")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gold.opacity(0.4), lineWidth: 1)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.black.opacity(0.1))
                                        .blur(radius: 5)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Placeholder for future button or spacing
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            
        }
        .onAppear {
            glowAnimation = true
            pulseAnimation = true
        }
    }
}

// MARK: - Streaks Section

struct StreaksSection: View {
    let currentStreak: Int
    @StateObject private var runManager = RunManager.shared
    @State private var streakAnimation = false
    @State private var flameAnimation = false
    
    var body: some View {
        VStack(spacing: 10) {
            // Header
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
                    value: runManager.longestStreak,
                    subtitle: "days",
                    icon: "🏆",
                    color: .gold,
                    isAnimated: false
                )
                
                // Total Runs
                StreakCard(
                    title: "Total",
                    value: runManager.runHistory.count,
                    subtitle: "runs",
                    icon: "💪",
                    color: .green,
                    isAnimated: false
                )
            }
            
            // Weekly Progress
            WeeklyProgressView()
        }
        .onAppear {
            streakAnimation = true
            flameAnimation = true
        }
    }
}

struct StreakCard: View {
    let title: String
    let value: Int
    let subtitle: String
    let icon: String
    let color: Color
    let isAnimated: Bool
    
    @State private var scaleAnimation = false
    
    var body: some View {
        VStack(spacing: 6) {
            // Icon
            Text(icon)
                .font(.title3)
                .scaleEffect(scaleAnimation ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: scaleAnimation)
            
            // Value
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            // Title
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .fontWeight(.medium)
            
            // Subtitle
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            if isAnimated {
                scaleAnimation = true
            }
        }
    }
}

struct WeeklyProgressView: View {
    // Sample data for 3 months (12 weeks) - 0 = no workout, 1-4 = workout intensity
    @State private var heatmapData: [[Int]] = [
        [0, 1, 2, 3, 1, 0, 2], // Week 1
        [1, 3, 2, 4, 1, 2, 0], // Week 2
        [2, 1, 3, 2, 1, 0, 1], // Week 3
        [0, 2, 1, 3, 2, 1, 0], // Week 4
        [1, 0, 2, 1, 3, 2, 1], // Week 5
        [2, 1, 0, 2, 1, 3, 2], // Week 6
        [1, 2, 1, 0, 2, 1, 3], // Week 7
        [0, 1, 2, 1, 0, 2, 1], // Week 8
        [2, 0, 1, 2, 1, 0, 2], // Week 9
        [1, 2, 0, 1, 2, 1, 0], // Week 10
        [0, 1, 2, 0, 1, 2, 1], // Week 11
        [2, 1, 0, 2, 1, 0, 1]  // Week 12 (current week)
    ]
    @State private var animationDelay = 0.0
    @State private var selectedDay: (week: Int, day: Int)? = nil
    
    private var maxValue: Int {
        heatmapData.flatMap { $0 }.max() ?? 1
    }
    
    private func getColorForValue(_ value: Int) -> Color {
        switch value {
        case 0:
            return Color.gray.opacity(0.2)
        case 1:
            return Color.gold.opacity(0.3)
        case 2:
            return Color.gold.opacity(0.5)
        case 3:
            return Color.gold.opacity(0.7)
        case 4:
            return Color.gold.opacity(0.9)
        default:
            return Color.gray.opacity(0.2)
        }
    }
    
    private func getDayLabel(_ weekIndex: Int, _ dayIndex: Int) -> String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return dayNames[dayIndex]
    }
    
    private func getMonthLabel(_ weekIndex: Int) -> String {
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        // Calculate which month this week belongs to (simplified)
        let monthIndex = weekIndex / 4
        return monthNames[monthIndex % 12]
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Last 3 Months")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("\(heatmapData.flatMap { $0 }.filter { $0 > 0 }.count) workouts")
                    .font(.caption2)
                    .foregroundColor(.gold)
            }
            
            // GitHub-style heatmap with 3 months (horizontal layout)
            HStack(spacing: 3) {
                ForEach(Array(heatmapData.enumerated()), id: \.offset) { weekIndex, week in
                    VStack(spacing: 3) {
                        ForEach(Array(week.enumerated()), id: \.offset) { dayIndex, value in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(getColorForValue(value))
                                .frame(width: 10, height: 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                                .scaleEffect(animationDelay > Double(weekIndex * 7 + dayIndex) * 0.05 ? 1.0 : 0.8)
                                .animation(.easeInOut(duration: 0.3).delay(Double(weekIndex * 7 + dayIndex) * 0.01), value: animationDelay)
                                .onTapGesture {
                                    selectedDay = (weekIndex, dayIndex)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(selectedDay?.week == weekIndex && selectedDay?.day == dayIndex ? Color.gold : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
            }
            
            // Selected day info
            if let selected = selectedDay {
                let value = heatmapData[selected.week][selected.day]
                let dayLabel = getDayLabel(selected.week, selected.day)
                let monthLabel = getMonthLabel(selected.week)
                
                HStack {
                    Text("\(monthLabel) \(dayLabel)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text(value > 0 ? "\(value) workout\(value == 1 ? "" : "s")" : "No workout")
                        .font(.caption2)
                        .foregroundColor(value > 0 ? .gold : .gray)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Legend
            HStack(spacing: 8) {
                Text("Less")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(getColorForValue(intensity))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text("More")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 2)
        .onAppear {
            animationDelay = 1.0
        }
    }
}

// MARK: - User Settings View

struct UserSettingsView: View {
    let userPreferences: UserPreferences
    let authTracker: AuthenticationTracker
    let initialTab: Int
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int
    
    init(userPreferences: UserPreferences, authTracker: AuthenticationTracker, initialTab: Int = 0) {
        self.userPreferences = userPreferences
        self.authTracker = authTracker
        self.initialTab = initialTab
        self._selectedTab = State(initialValue: initialTab)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.gold)
                    .font(.headline)
                    
                Spacer()

                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible button for balance
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.clear)
                    .font(.headline)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                
                // Tab Bar
                HStack(spacing: 0) {
                    TabButton(
                        title: "Profile Statistics",
                        isSelected: selectedTab == 0,
                        action: { selectedTab = 0 }
                    )
                    
                    TabButton(
                        title: "User Settings",
                        isSelected: selectedTab == 1,
                        action: { selectedTab = 1 }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Tab Content
                TabView(selection: $selectedTab) {
                    ProfileStatisticsTab(userPreferences: userPreferences)
                        .tag(0)
                    
                    UserSettingsTab(authTracker: authTracker)
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .gold : .gray)
                    .fontWeight(isSelected ? .bold : .medium)
                
                Rectangle()
                    .fill(isSelected ? Color.gold : Color.clear)
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.3), value: isSelected)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// MARK: - User Settings Tab

struct UserSettingsTab: View {
    let authTracker: AuthenticationTracker
    @State private var dailyGoalMinutes = 15
    @State private var notificationsEnabled = true
    @State private var locationAccuracy = "High"
    @State private var showConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingExportOptions = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Daily Goal Setting
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.gold)
                            Text("Daily Goal")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Minutes per day")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Button(action: {
                                    if dailyGoalMinutes > 5 {
                                        dailyGoalMinutes -= 5
                                        RunManager.shared.dailyMinutesGoal = dailyGoalMinutes
                                        UserDefaults.standard.set(dailyGoalMinutes, forKey: "dailyMinutesGoal")
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.gold)
                                }
                                
                                Text("\(dailyGoalMinutes) min")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(minWidth: 80)
                                
                                Button(action: {
                                    if dailyGoalMinutes < 60 {
                                        dailyGoalMinutes += 5
                                        RunManager.shared.dailyMinutesGoal = dailyGoalMinutes
                                        UserDefaults.standard.set(dailyGoalMinutes, forKey: "dailyMinutesGoal")
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.gold)
                                }
                            }
                        }
                    }
                }
                
                // Notifications Setting
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "bell")
                                .foregroundColor(.gold)
                            Text("Notifications")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        Toggle("Enable Notifications", isOn: $notificationsEnabled)
                            .foregroundColor(.white)
                            .tint(.gold)
                            .onChange(of: notificationsEnabled) { oldValue, newValue in
                                if newValue {
                                    NotificationManager.shared.requestPermission()
                                } else {
                                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                                }
                            }
                    }
                }
                
                // Location Accuracy Setting
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.gold)
                            Text("Location Accuracy")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        Picker("Accuracy", selection: $locationAccuracy) {
                            Text("High").tag("High")
                            Text("Medium").tag("Medium")
                            Text("Low").tag("Low")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .tint(.gold)
                        .onChange(of: locationAccuracy) { oldValue, newValue in
                            let runManager = RunManager.shared
                            switch newValue {
                            case "High":
                                runManager.locationManager.desiredAccuracy = kCLLocationAccuracyBest
                            case "Medium":
                                runManager.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                            case "Low":
                                runManager.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                            default:
                                break
                            }
                            UserDefaults.standard.set(newValue, forKey: "locationAccuracy")
                        }
                    }
                }
                
                // Account Actions
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundColor(.gold)
                            Text("Account")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                showingExportOptions = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.gold)
                                    Text("Export Data")
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                            }
                            
                            Divider()
                                .background(Color.gray.opacity(0.3))
                            
                            Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                    Text("Delete Account")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                
                // Sign Out Button
                Button(action: {
                    authTracker.signOut()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Text("Sign Out")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Implement account deletion
                authTracker.signOut()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
        .alert("Export Data", isPresented: $showingExportOptions) {
            Button("Cancel", role: .cancel) { }
            Button("Export Run History") {
                exportRunHistory()
            }
            Button("Export All Data") {
                exportAllData()
            }
        } message: {
            Text("Choose what data to export:")
        }
        .onAppear {
            // Load current daily goal
            dailyGoalMinutes = RunManager.shared.dailyMinutesGoal
            
            // Check notification permission status
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    notificationsEnabled = settings.authorizationStatus == .authorized
                }
            }
            
            // Load current location accuracy setting
            locationAccuracy = UserDefaults.standard.string(forKey: "locationAccuracy") ?? "High"
        }
    }
    
    private func exportRunHistory() {
        // Export run history to JSON
        let runManager = RunManager.shared
        if let data = try? JSONEncoder().encode(runManager.runHistory) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let timestamp = formatter.string(from: Date())
            let filename = "CRDO_RunHistory_\(timestamp).json"
            
            // Save to documents directory
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsPath.appendingPathComponent(filename)
                try? data.write(to: fileURL)
                print("✅ Run history exported to: \(fileURL)")
            }
        }
    }
    
    private func exportAllData() {
        // Export all user data including preferences, streaks, etc.
        let runManager = RunManager.shared
        let exportData = ExportData(
            runHistory: runManager.runHistory,
            currentStreak: runManager.currentStreak,
            longestStreak: runManager.longestStreak,
            dailyGoal: runManager.dailyMinutesGoal,
            freezeTokens: runManager.freezeTokensRemaining,
            exportDate: Date()
        )
        
        if let data = try? JSONEncoder().encode(exportData) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let timestamp = formatter.string(from: Date())
            let filename = "CRDO_AllData_\(timestamp).json"
            
            // Save to documents directory
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let fileURL = documentsPath.appendingPathComponent(filename)
                try? data.write(to: fileURL)
                print("✅ All data exported to: \(fileURL)")
            }
        }
    }
}

// MARK: - Profile Statistics Tab

struct ProfileStatisticsTab: View {
    let userPreferences: UserPreferences
    @StateObject private var runManager = RunManager.shared
    @State private var selectedRun: RunSession?
    @State private var showingRunDetail = false
    
    private var sortedRuns: [RunSession] {
        runManager.runHistory.sorted(by: { $0.startTime > $1.startTime })
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // User Preferences Summary (moved from main view)
                if userPreferences.onboardingCompleted {
                    UserPreferencesSummary(preferences: userPreferences)
                        .padding(.horizontal, 20)
                }

                // Run History
                if !runManager.runHistory.isEmpty {
                    GlassCard {
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title2)
                                    .foregroundColor(.gold)
                                
                                Text("Run History")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(runManager.runHistory.count) runs")
                                    .font(.caption)
                                    .foregroundColor(.gold)
                            }
                            
                            LazyVStack(spacing: 12) {
                                ForEach(sortedRuns) { run in
                                    RunHistoryRow(run: run)
                                        .onTapGesture {
                                            selectedRun = run
                                            showingRunDetail = true
                                        }
                                }
                            }
                        }
                        .padding(20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 20)
        }
        .sheet(isPresented: $showingRunDetail) {
            if let run = selectedRun {
                RunDetailView(run: run)
            }
        }
    }
}

// MARK: - Run Models



// MARK: - Run Category

enum RunCategory: String, CaseIterable, Codable {
    case sprint = "Sprint"
    case shortRun = "Short Run"
    case mediumRun = "Medium Run"
    case longRun = "Long Run"
    case recoveryRun = "Recovery Run"
    case tempoRun = "Tempo Run"
    case easyRun = "Easy Run"
    
    var icon: String {
        switch self {
        case .sprint: return "bolt.fill"
        case .shortRun: return "figure.run"
        case .mediumRun: return "figure.run"
        case .longRun: return "figure.run"
        case .recoveryRun: return "heart.fill"
        case .tempoRun: return "speedometer"
        case .easyRun: return "figure.walk"
        }
    }
    
    var color: Color {
        switch self {
        case .sprint: return .red
        case .shortRun: return .orange
        case .mediumRun: return .yellow
        case .longRun: return .blue
        case .recoveryRun: return .green
        case .tempoRun: return .purple
        case .easyRun: return .mint
        }
    }
    
    var description: String {
        switch self {
        case .sprint: return "High intensity, short duration"
        case .shortRun: return "Quick cardio session"
        case .mediumRun: return "Moderate distance run"
        case .longRun: return "Endurance building"
        case .recoveryRun: return "Light, easy pace"
        case .tempoRun: return "Sustained effort"
        case .easyRun: return "Comfortable pace"
        }
    }
}

// MARK: - Run Manager Extensions
    
// MARK: - Run Manager Extensions

// MARK: - Location Manager Extension

extension RunManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Enhanced filtering for better GPS accuracy
        guard location.horizontalAccuracy <= 25 else { 
            print("⚠️ Rejecting location with poor accuracy: \(location.horizontalAccuracy)m")
            return 
        }
        
        // Filter out locations that are too close together (but be less restrictive)
        if let lastLocation = lastLocation {
            let distanceFromLast = location.distance(from: lastLocation)
            if distanceFromLast < 1 { 
                print("⚠️ Skipping location too close to last: \(distanceFromLast)m")
                return 
            }
        }
        
        print("✅ Location update: \(location.coordinate) - Accuracy: \(location.horizontalAccuracy)m")
        currentLocation = location
        
        if isRunActive {
            if let lastLocation = lastLocation {
                let newDistance = location.distance(from: lastLocation)
                
                // Enhanced distance filtering
                if newDistance > 0 && newDistance < 100 { // More permissive distance limit
                    distance += newDistance
                    
                    // Add to route with smoothing
                    if shouldAddToRoute(location: location) {
                        routeCoordinates.append(location.coordinate)
                        print("📍 Route point added: \(location.coordinate)")
                    }
                    print("📏 Distance updated: \(distance)m (added: \(newDistance)m)")
                } else {
                    print("⚠️ Skipping distance update: \(newDistance)m (outside valid range)")
                }
            }
            
            lastLocation = location
        }
    }
    
    private func shouldAddToRoute(location: CLLocation) -> Bool {
        // Only add to route if we have enough points or if it's significantly different
        if routeCoordinates.count < 2 {
            return true
        }
        
        guard let lastCoordinate = routeCoordinates.last else { return true }
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = location.distance(from: lastLocation)
        let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
        
        // Calculate speed in m/s
        let speed = timeInterval > 0 ? distance / timeInterval : 0
        
        // Add point if it's at least 5 meters away from the last point
        // and the speed is reasonable (between 0.5 and 10 m/s, which is roughly 1.8-36 km/h)
        return distance >= 5 && speed >= 0.5 && speed <= 10
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Location authorization changed to: \(status.rawValue)")
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission granted")
            if isRunActive {
                locationManager.startUpdatingLocation()
                print("🚀 Location updates started")
            }
        case .denied, .restricted:
            print("❌ Location permission denied or restricted")
        case .notDetermined:
            print("⏳ Location permission not determined")
        @unknown default:
            print("❓ Unknown authorization status")
        }
    }
}

// MARK: - Run History Row

struct RunHistoryRow: View {
    let run: RunSession
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: run.startTime)
    }
    
    private var formattedDuration: String {
        let minutes = Int(run.duration) / 60
        let seconds = Int(run.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var formattedDistance: String {
        if run.distance >= 1000 {
            return String(format: "%.1f km", run.distance / 1000)
        } else {
            return String(format: "%.0f m", run.distance)
        }
    }
    
    private var formattedPace: String {
        if run.duration > 0 && run.distance > 0 {
            let paceInSeconds = run.duration / (run.distance / 1000.0)
            let minutes = Int(paceInSeconds) / 60
            let seconds = Int(paceInSeconds) % 60
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "--:--"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Run Icon
            Image(systemName: "figure.run")
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            // Run Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Running")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gold)
                
                HStack(spacing: 8) {
                    Text(formattedDistance)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(formattedPace)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Category Filter Button

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(isSelected ? Color.gold.opacity(0.3) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(isSelected ? Color.gold : Color.gray.opacity(0.5), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Run Detail View

struct RunDetailView: View {
    let run: RunSession
    @Environment(\.dismiss) private var dismiss
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    private var routeCoordinates: [CLLocationCoordinate2D] {
        run.route?.map { $0.clCoordinate } ?? []
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.gold)
                    .font(.headline)
                    
                    Spacer()
                    
                    Text("Run Details")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible button for balance
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.clear)
                    .font(.headline)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Run Summary Card
                        GlassCard {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "figure.run")
                                        .font(.title)
                                        .foregroundColor(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text("Running")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        }
                                        
                                        Text(formatDate(run.startTime))
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                                
                                // Stats Grid
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    DetailStatCard(title: "Duration", value: formatDuration(run.duration), icon: "clock")
                                    DetailStatCard(title: "Distance", value: formatDistance(run.distance), icon: "location")
                                    DetailStatCard(title: "Pace", value: formatPace(run.duration, run.distance), icon: "speedometer")
                                }
                            }
                            .padding(20)
                        }
                        .padding(.horizontal, 20)
                        
                                                // Route Map (if available)
                        if !routeCoordinates.isEmpty {
                            GlassCard {
                                VStack(spacing: 16) {
                                    HStack {
                                        Image(systemName: "map")
                                            .font(.title2)
                                            .foregroundColor(.gold)
                                        
                                        Text("Route")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                    }
                                    
                                    Map(coordinateRegion: .constant(region))
                                        .frame(height: 200)
                                        .cornerRadius(12)
                                }
                                .padding(20)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 20)
                }
            }
        }
        .onAppear {
            // Set map region to show the entire route
            if !routeCoordinates.isEmpty {
                updateMapRegion()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    private func formatPace(_ duration: TimeInterval, _ distance: Double) -> String {
        if duration > 0 && distance > 0 {
            let paceInSeconds = duration / (distance / 1000.0)
            let minutes = Int(paceInSeconds) / 60
            let seconds = Int(paceInSeconds) % 60
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "--:--"
        }
    }
    

    
    private func updateMapRegion() {
        let latitudes = routeCoordinates.map { $0.latitude }
        let longitudes = routeCoordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = (maxLat - minLat) * 1.2
        let spanLon = (maxLon - minLon) * 1.2
        
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: max(spanLat, 0.01), longitudeDelta: max(spanLon, 0.01))
        )
    }
}

struct DetailStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.gold)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Workout Map View

struct RunMapView: View {
    @ObservedObject var runManager: RunManager
    @Environment(\.dismiss) private var dismiss
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var showUserLocation = true
    @State private var mapType: MKMapType = .standard
    
    var body: some View {
        ZStack {
            // Map View with Route
            Map(coordinateRegion: $region, showsUserLocation: showUserLocation, userTrackingMode: .constant(.follow))
            .mapStyle(mapType == .standard ? .standard : .hybrid)
            .ignoresSafeArea()
            .onTapGesture {
                // Hide keyboard if any
            }
            
            // Overlay UI
            VStack {
                // Top Bar
                HStack {
                    Button(action: {
                        // End run before dismissing
                        if runManager.isRunActive {
                            runManager.endRun()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("Running")
                            .font(.headline)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                        
                        Text(formatTime(runManager.elapsedTime))
                            .font(.subheadline)
                            .foregroundColor(.gold)
                    }
                    
                    Spacer()
                    
                    // Zoom Controls
                    VStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                region.span.latitudeDelta *= 0.5
                                region.span.longitudeDelta *= 0.5
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                region.span.latitudeDelta *= 2.0
                                region.span.longitudeDelta *= 2.0
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        
                        Button(action: {
                            if let location = runManager.currentLocation {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    region.center = location.coordinate
                                }
                            }
                        }) {
                            Image(systemName: "location.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gold)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        
                        Button(action: {
                            mapType = mapType == .standard ? .satellite : .standard
                        }) {
                            Image(systemName: mapType == .standard ? "map" : "map.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if runManager.isRunActive {
                            runManager.pauseRun()
                        } else {
                            runManager.startRun()
                        }
                    }) {
                        Image(systemName: runManager.isRunActive ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(runManager.isRunActive ? .red : .green)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                    }
                }
                .padding()
                .background(
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .ignoresSafeArea()
                )
                
                Spacer()
                
                // Bottom Stats
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        StatCard(title: "Distance", value: formatDistance(runManager.distance), icon: "location")
                        StatCard(title: "Time", value: formatTime(runManager.elapsedTime), icon: "clock")
                        StatCard(title: "Pace", value: formatPace(runManager.currentPace), icon: "speedometer")
                    }
                    
                    // End Run Button
                    Button(action: {
                        runManager.endRun()
                        dismiss()
                    }) {
                        Text("End Run")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.red.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Color.red, lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal, 20)
                }
                .padding()
                .background(
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .ignoresSafeArea()
                )
            }
        }
        .onAppear {
            // Update region to user's current location
            if let location = runManager.currentLocation {
                withAnimation(.easeInOut(duration: 0.5)) {
                    region.center = location.coordinate
                }
                print("📍 Map centered on user location: \(location.coordinate)")
            } else {
                // Request location permission if not available
                runManager.locationManager.requestWhenInUseAuthorization()
                print("⚠️ No user location available for map")
            }
        }
        .onChange(of: runManager.currentLocation) { oldValue, newValue in
            if let location = newValue {
                // Smooth region updates to reduce map jumping
                withAnimation(.easeInOut(duration: 0.5)) {
                    region.center = location.coordinate
                }
            }
        }
        .onReceive(runManager.$routeCoordinates) { coordinates in
            // Update route coordinates from run manager
            routeCoordinates = coordinates
        }
        .onChange(of: runManager.isRunActive) { oldValue, newValue in
            if newValue {
                // Start new route when run begins
                routeCoordinates.removeAll()
                if let location = runManager.currentLocation {
                    routeCoordinates.append(location.coordinate)
                }
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        if pace > 0 {
            let minutes = Int(pace)
            let seconds = Int((pace - Double(minutes)) * 60)
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "--:--"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.gold)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                )
        )
    }
}



// MARK: - Main App View (Running-Focused)

struct MainAppView: View {
    let userPreferences: UserPreferences
    let authTracker: AuthenticationTracker
    @StateObject private var dataManager = DataManager.shared
    @State private var showingUserSettings = false
    @State private var showingRunMap = false
    @State private var selectedTab = 0
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var runManager = RunManager.shared

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0.85)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Navigation Bar
                TopNavigationBar(
                    showingUserSettings: $showingUserSettings
                )
                
                // Network Status Indicator
                if !dataManager.isConnected {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.red)
                        Text("Offline Mode")
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                }
                
                // Main Content
                TabView(selection: $selectedTab) {
                    // Home Tab - Streak & Quick Start
                    HomeTabView(
                        runManager: runManager,
                        showingRunMap: $showingRunMap,
                        showingUserSettings: $showingUserSettings
                    )
                    .tag(0)
                    
                    // Stats Tab - Running Analytics
                    StatsTabView(runManager: runManager)
                        .tag(1)
                    
                    // Community Tab - Friends & Leaderboards
                    CommunityTabView()
                        .tag(2)
                    
                    // Challenges Tab - Weekly/Monthly Challenges
                    ChallengesTabView()
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
                
                // Bottom Tab Bar
                RunningTabBar(selectedTab: $selectedTab)
            }
        }
        .onAppear {
            notificationManager.requestPermission()
            
            // Fetch backend data
            if dataManager.isAuthenticated() {
                dataManager.syncUserData()
                dataManager.fetchLeaderboard()
                dataManager.fetchChallenges()
            }
        }
        .sheet(isPresented: $showingUserSettings) {
            UserSettingsView(userPreferences: userPreferences, authTracker: authTracker)
        }
        .fullScreenCover(isPresented: $showingRunMap) {
            RunMapView(runManager: runManager)
        }
        .statusBarHidden(true)
    }
}

// MARK: - Home Tab View

struct HomeTabView: View {
    @ObservedObject var runManager: RunManager
    @Binding var showingRunMap: Bool
    @Binding var showingUserSettings: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Streak Section
                StreakSection(
                    currentStreak: runManager.currentStreak,
                    longestStreak: runManager.longestStreak,
                    freezeTokens: runManager.freezeTokensRemaining,
                    isRunActive: runManager.isRunActive,
                    onStartRun: {
                        if runManager.isRunActive {
                            runManager.pauseRun()
                        } else {
                            runManager.startRun()
                            showingRunMap = true
                        }
                    },
                    onEndRun: {
                        if runManager.isRunActive {
                            runManager.endRun()
                        }
                    },
                    runManager: runManager
                )
                
                // Quick Stats Section
                QuickStatsSection(runManager: runManager)
                    .padding(.horizontal, 30)
                
                // Extra spacing for better scrolling
                Spacer(minLength: 100)
            }
            .padding(.top, 20)
        }
        .scrollIndicators(.hidden) // Hide scroll indicators for cleaner look
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
                     .trim(from: 0, to: min(Double(runManager.dailySecondsCompleted) / Double(runManager.dailyMinutesGoal * 60), 1.0))
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
                        .animation(.easeInOut(duration: 0.5), value: runManager.dailySecondsCompleted)
                    
                                     // Center content
                 VStack(spacing: 4) {
                     let totalSeconds = runManager.dailySecondsCompleted
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
                Text("🔥 STREAK")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("\(currentStreak)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.gold)
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                
                Text("days")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
                
                if currentStreak > 0 {
                    Text("Longest: \(longestStreak) days")
                        .font(.caption)
                        .foregroundColor(.gold.opacity(0.8))
                }
            }
            
            // Freeze Tokens
            HStack(spacing: 20) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < freezeTokens ? "snowflake.fill" : "snowflake")
                        .font(.title2)
                        .foregroundColor(index < freezeTokens ? .blue : .gray)
                }
            }
            .padding(.vertical, 10)
            
            // Start Run Button
            Button(action: onStartRun) {
                HStack(spacing: 12) {
                    Image(systemName: isRunActive ? "pause.fill" : "play.fill")
                        .font(.title2)
                    
                    Text(isRunActive ? "Pause Run" : "Start Run")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(isRunActive ? Color.red.opacity(0.3) : Color.gold.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(isRunActive ? Color.red.opacity(0.6) : Color.gold.opacity(0.6), lineWidth: 1.5)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.top, 50)
        .onAppear {
            pulseAnimation = true
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
            
            HStack(spacing: 20) {
                StatCard(title: "This Week", value: "\(runManager.runHistory.filter { Calendar.current.isDate($0.startTime, equalTo: Date(), toGranularity: .weekOfYear) }.count)", icon: "calendar")
                StatCard(title: "Total Runs", value: "\(runManager.runHistory.count)", icon: "figure.run")
                StatCard(title: "Avg Pace", value: formatPace(runManager.averagePace), icon: "speedometer")
            }
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        if pace > 0 {
            let minutes = Int(pace)
            let seconds = Int((pace - Double(minutes)) * 60)
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return "--:--"
        }
    }
}



// MARK: - Stats Tab View

struct StatsTabView: View {
    @ObservedObject var runManager: RunManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Weekly Progress Chart
                WeeklyProgressChart(runManager: runManager)
                
                // Pace Trends
                PaceTrendsChart(runManager: runManager)
                
                // Recent Runs
                RecentRunsList(runManager: runManager)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

// MARK: - Community Tab View

struct CommunityTabView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Friends Section
                FriendsSection()
                
                // Leaderboards
                LeaderboardsSection()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

// MARK: - Challenges Tab View

struct ChallengesTabView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Active Challenges
                ActiveChallengesSection()
                
                // Completed Challenges
                CompletedChallengesSection()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

// MARK: - Running Tab Bar

struct RunningTabBar: View {
    @Binding var selectedTab: Int
    
    private let tabs = [
        TabItem(title: "Home", icon: "house.fill", selectedIcon: "house.fill"),
        TabItem(title: "Stats", icon: "chart.bar.fill", selectedIcon: "chart.bar.fill"),
        TabItem(title: "Community", icon: "person.2.fill", selectedIcon: "person.2.fill"),
        TabItem(title: "Challenges", icon: "trophy.fill", selectedIcon: "trophy.fill")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == index ? tabs[index].selectedIcon : tabs[index].icon)
                            .font(.system(size: 20))
                            .foregroundColor(selectedTab == index ? .gold : .gray)
                        
                        Text(tabs[index].title)
                            .font(.caption2)
                            .foregroundColor(selectedTab == index ? .gold : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.9))
                .overlay(
                    Rectangle()
                        .stroke(Color.gold.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Placeholder Components

struct WeeklyProgressChart: View {
    @ObservedObject var runManager: RunManager
    
    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.gold)
                    
                    Text("Weekly Progress")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text("Chart placeholder - Weekly mileage and run frequency")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
    }
}

struct PaceTrendsChart: View {
    @ObservedObject var runManager: RunManager
    
    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "speedometer")
                        .font(.title2)
                        .foregroundColor(.gold)
                    
                    Text("Pace Trends")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text("Chart placeholder - Pace improvements over time")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
    }
}

struct RecentRunsList: View {
    @ObservedObject var runManager: RunManager
    
    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundColor(.gold)
                    
                    Text("Recent Runs")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                if runManager.runHistory.isEmpty {
                    Text("No runs yet. Start your first run!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                } else {
                    ForEach(runManager.runHistory.prefix(3)) { run in
                        RunHistoryRow(run: run)
                    }
                }
            }
            .padding(20)
        }
    }
}



struct FriendsSection: View {
    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundColor(.gold)
                    
                    Text("Friends")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text("Friends feature placeholder - Add friends to see their progress")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
    }
}

struct LeaderboardsSection: View {
    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .font(.title2)
                        .foregroundColor(.gold)
                    
                    Text("Leaderboards")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text("Leaderboards placeholder - See top runners and achievements")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
    }
}

struct ActiveChallengesSection: View {
    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "target")
                        .font(.title2)
                        .foregroundColor(.gold)
                    
                    Text("Active Challenges")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text("Challenges placeholder - Weekly and monthly running challenges")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
    }
}

struct CompletedChallengesSection: View {
    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gold)
                    
                    Text("Completed Challenges")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text("Completed challenges placeholder - View your achievements")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
    }
}

// MARK: - Supporting Components

struct TabItem {
    let title: String
    let icon: String
    let selectedIcon: String
}



// MARK: - Run Manager Extensions

// MARK: - Preview

#Preview {
    ContentView()
}

// MARK: - Notification Manager

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private let morningMessages = [
        "Somehow you've worked out 3 days in a row. Who even are you?? Don't break the illusion—get today's session in.",
        "Day 7 of cardio?! You're basically an athlete. Time to start looking down on the rest of us. One more rep, one more flex.",
        "You just beat your streak of 5 days! Experts are confused. Your couch is devastated. Don't let the couch win. Again.",
        "New record: 8 days. Is this growth or a glitch in the matrix? Test reality—go move your body.",
        "7-day streak unlocked! Please accept this imaginary badge. It's emotionally fulfilling and absolutely worthless. Still better than any NFT. Keep going.",
        "30 days straight? Do you even have rest days or are you powered by caffeine and existential dread? Whatever works. Just log today's cardio.",
        "You're 1 missed workout away from losing your streak. Not saying we'll cry, but… we'll cry. Spare us the emotional damage—just 10 minutes of movement today.",
        "That streak isn't going to save itself. You've come this far, don't let us down like our high school gym teachers did. Open CRDO. Be the gym class hero you never were.",
        "Rise and cardio, legend. Or snooze and lose. Your move. Just one small step for your body, one giant leap for your self-esteem.",
        "Still time to do cardio! Or sit in guilt and scroll memes. Honestly, both are exercise-adjacent. Do the one that helps your heart.",
        "You've done 15 workouts this month. That's more consistent than your skincare routine. Make it 16 and glow inside out.",
        "Your cardio stats are up 40%. We're scared. Are you okay? Channel the chaos. Keep the streak alive.",
        "Yes, we know these notifications are annoying. But so is starting over. Save future-you the stress. Move it.",
        "CRDO: reminding you to move so your future self doesn't file a complaint. Seriously. Avoid the lawsuit. Do some cardio.",
        "Congrats on your 10-day streak. NASA called. They want to study your discipline. Show them you're consistent, not just weird.",
        "Not to alarm you, but you're one workout away from being legally considered \"fit-ish.\" Lock it in. Hit start.",
        "Legend has it if you hit 14 days, a protein bar spawns in your kitchen. One more workout and you might find out.",
        "Don't let your streak become just another broken dream. Like your podcast. Do it for the streak. Do it for the dignity.",
        "The streak is strong with you. Unlike your knees, probably. Warm up. Then unleash chaos.",
        "CRDO streak: 11 days. Ego streak: infinity. Keep feeding both.",
        "You're making the rest of us look bad. Please stop. Or don't. Actually, keep going. Let's see 12.",
        "Is this discipline or just you running from your problems at 6mph? Either way, don't stop now."
    ]
    
    private let eveningMessages = [
        "You missed yesterday. Tragic. But not unrecoverable. Like your last relationship. Reignite the spark—with cardio.",
        "Your streak is dead… unless you pretend yesterday didn't happen. We won't tell. Do today's workout. We'll lie for you.",
        "Still time to do cardio! Or sit in guilt and scroll memes. Honestly, both are exercise-adjacent. Do the one that helps your heart.",
        "You've done 15 workouts this month. That's more consistent than your skincare routine. Make it 16 and glow inside out.",
        "Your cardio stats are up 40%. We're scared. Are you okay? Channel the chaos. Keep the streak alive.",
        "Yes, we know these notifications are annoying. But so is starting over. Save future-you the stress. Move it.",
        "CRDO: reminding you to move so your future self doesn't file a complaint. Seriously. Avoid the lawsuit. Do some cardio.",
        "Congrats on your 10-day streak. NASA called. They want to study your discipline. Show them you're consistent, not just weird.",
        "Not to alarm you, but you're one workout away from being legally considered \"fit-ish.\" Lock it in. Hit start.",
        "Legend has it if you hit 14 days, a protein bar spawns in your kitchen. One more workout and you might find out.",
        "Don't let your streak become just another broken dream. Like your podcast. Do it for the streak. Do it for the dignity.",
        "The streak is strong with you. Unlike your knees, probably. Warm up. Then unleash chaos.",
        "CRDO streak: 11 days. Ego streak: infinity. Keep feeding both.",
        "You're making the rest of us look bad. Please stop. Or don't. Actually, keep going. Let's see 12.",
        "Is this discipline or just you running from your problems at 6mph? Either way, don't stop now."
    ]
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
                self.scheduleNotifications()
            } else {
                print("Notification permission denied")
            }
        }
    }
    
    func scheduleNotifications() {
        // Clear existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Schedule morning notification (7 AM)
        scheduleNotification(
            title: "CRDO",
            body: morningMessages.randomElement() ?? "Time to move!",
            hour: 7,
            minute: 0,
            identifier: "morning-crdo"
        )
        
        // Schedule late morning notification (11 AM)
        scheduleNotification(
            title: "CRDO",
            body: morningMessages.randomElement() ?? "Still time to workout!",
            hour: 11,
            minute: 0,
            identifier: "late-morning-crdo"
        )
        
        // Schedule afternoon notification (3 PM)
        scheduleNotification(
            title: "CRDO",
            body: eveningMessages.randomElement() ?? "Afternoon energy boost!",
            hour: 15,
            minute: 0,
            identifier: "afternoon-crdo"
        )
        
        // Schedule evening notification (7 PM)
        scheduleNotification(
            title: "CRDO",
            body: eveningMessages.randomElement() ?? "Evening workout time!",
            hour: 19,
            minute: 0,
            identifier: "evening-crdo"
        )
    }
    
    private func scheduleNotification(title: String, body: String, hour: Int, minute: Int, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled for \(hour):\(minute)")
            }
        }
    }
    
    func scheduleStreakNotification(streak: Int) {
        let content = UNMutableNotificationContent()
        content.title = "CRDO Streak Update"
        
        let messages = [
            "🔥 \(streak)-day streak! You're on fire!",
            "💪 \(streak) days strong! Keep it up!",
            "🏆 \(streak) days in a row! You're unstoppable!",
            "⚡ \(streak) day streak! You're crushing it!",
            "🌟 \(streak) days! You're becoming a legend!"
        ]
        
        content.body = messages.randomElement() ?? "Amazing streak!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "streak-\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Authentication View

struct AuthenticationView: View {
    let authTracker: AuthenticationTracker
    @StateObject private var dataManager = DataManager.shared
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingPassword = false
    @State private var showingConfirmPassword = false
    @State private var rememberMe = false
    @State private var animationOffset: CGFloat = 1000
    @State private var keyboardHeight: CGFloat = 0
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.black.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 15) {
                    // App Logo/Title
                    VStack(spacing: 12) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gold)
                            .scaleEffect(animationOffset == 0 ? 1.0 : 0.5)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animationOffset)
                        
                        Text("CRDO")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.gold)
                            .opacity(animationOffset == 0 ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.8).delay(0.2), value: animationOffset)
                        
                        Text("Discipline built differently. Welcome to your new habit: CRDO.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .opacity(animationOffset == 0 ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.8).delay(0.4), value: animationOffset)
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // Auth Form
                    VStack(spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.gold)
                                .fontWeight(.semibold)
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(AuthTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(.gold)
                                .fontWeight(.semibold)
                            
                            HStack {
                                if showingPassword {
                                    TextField("Enter your password", text: $password)
                                        .textFieldStyle(AuthTextFieldStyle())
                                } else {
                                    SecureField("Enter your password", text: $password)
                                        .textFieldStyle(AuthTextFieldStyle())
                                }
                                
                                Button(action: {
                                    showingPassword.toggle()
                                }) {
                                    Image(systemName: showingPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.gray)
                                        .font(.title3)
                                }
                            }
                        }
                        
                        // Confirm Password Field (Sign Up only)
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.caption)
                                    .foregroundColor(.gold)
                                    .fontWeight(.semibold)
                                
                                HStack {
                                    if showingConfirmPassword {
                                        TextField("Confirm your password", text: $confirmPassword)
                                            .textFieldStyle(AuthTextFieldStyle())
                                    } else {
                                        SecureField("Confirm your password", text: $confirmPassword)
                                            .textFieldStyle(AuthTextFieldStyle())
                                    }
                                    
                                    Button(action: {
                                        showingConfirmPassword.toggle()
                                    }) {
                                        Image(systemName: showingConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.gray)
                                            .font(.title3)
                                    }
                                }
                            }
                        }
                        
                        // Remember Me Toggle
                        HStack {
                            Button(action: {
                                rememberMe.toggle()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                        .foregroundColor(rememberMe ? .gold : .gray)
                                        .font(.title3)
                                    
                                    Text("Remember me for 2 weeks")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                        
                        // Action Button
                        Button(action: {
                            performAuthentication()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(isLoading ? Color.gray.opacity(0.5) : Color.gold.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Color.gold, lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(isLoading)
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 10)
                        
                        // Error Message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                                .padding(.top, 10)
                        }
                        
                        // Toggle Sign In/Sign Up
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSignUp.toggle()
                                email = ""
                                password = ""
                                confirmPassword = ""
                                rememberMe = false
                            }
                        }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.caption)
                                .foregroundColor(.gold.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 30)
                    .opacity(animationOffset == 0 ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.8).delay(0.6), value: animationOffset)
                    
                    Spacer()
                }
                .offset(y: -keyboardHeight * 0.3) // Shift content up when keyboard appears
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animationOffset = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeInOut(duration: 0.3)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                keyboardHeight = 0
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    private func performAuthentication() {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        if isSignUp {
            guard password == confirmPassword else {
                errorMessage = "Passwords don't match"
                return
            }
            
            guard password.count >= 6 else {
                errorMessage = "Password must be at least 6 characters"
                return
            }
        }
        
        isLoading = true
        errorMessage = ""
        
        let publisher: AnyPublisher<Bool, Error>
        
        if isSignUp {
            publisher = dataManager.signup(email: email, password: password)
        } else {
            publisher = dataManager.login(email: email, password: password)
        }
        
        publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { success in
                    if success {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            authTracker.signIn(email: email, password: password)
                        }
                        // Sync user data after successful authentication
                        dataManager.syncUserData()
                    } else {
                        errorMessage = "Authentication failed"
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Auth Text Field Style

struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
    }
}

// MARK: - Authentication Tracker Extensions

