//
//  DataManager.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Data manager for backend integration
//

import Foundation
import Combine
import CoreLocation

// MARK: - Data Manager

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    private let networkService = NetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    // User data
    @Published var currentUser: User?
    @Published var userStats: StatsData?
    @Published var streak: StreakData?
    @Published var gems: GemsData?
    @Published var friends: [Friend] = []
    
    // Local storage keys
    private let userIdKey = "userId"
    private let authTokenKey = "authToken"
    private let lastSyncKey = "lastSyncDate"
    private let pendingRunsKey = "pendingRuns"
    
    private init() {
        loadLocalData()
        setupAutoSync()
    }
    
    // MARK: - Authentication
    
    func signup(email: String, password: String, firstName: String, lastName: String) -> AnyPublisher<Bool, Error> {
        return networkService.signup(email: email, password: password, firstName: firstName, lastName: lastName)
            .handleEvents(receiveOutput: { [weak self] response in
                if let session = response.session {
                    self?.saveAuthData(token: session.access_token ?? "", userId: response.user?.id ?? "")
                    
                    // Save user data
                    if let user = response.user {
                        self?.currentUser = user
                        if let userData = try? JSONEncoder().encode(user) {
                            UserDefaults.standard.set(userData, forKey: "userData")
                        }
                    }
                }
            })
            .map { _ in true }
            .eraseToAnyPublisher()
    }
    
    func login(email: String, password: String) -> AnyPublisher<Bool, Error> {
        return networkService.login(email: email, password: password)
            .handleEvents(receiveOutput: { [weak self] response in
                if let session = response.session {
                    self?.saveAuthData(token: session.access_token ?? "", userId: response.user?.id ?? "")
                    
                    // Save user data
                    if let user = response.user {
                        self?.currentUser = user
                        if let userData = try? JSONEncoder().encode(user) {
                            UserDefaults.standard.set(userData, forKey: "userData")
                        }
                    }
                }
            })
            .map { _ in true }
            .eraseToAnyPublisher()
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: authTokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        currentUser = nil
        userStats = nil
    }
    
    // MARK: - Running
    
    func startRun() -> AnyPublisher<String, Error> {
        return networkService.startRun()
            .map { $0.runId }
            .eraseToAnyPublisher()
    }
    
    func finishRun(runId: String, distance: Double, duration: TimeInterval, averageSpeed: Double, peakSpeed: Double) -> AnyPublisher<FinishRunResponse, Error> {
        return networkService.finishRun(runId: runId, distance: distance, duration: duration, averageSpeed: averageSpeed, peakSpeed: peakSpeed)
            .eraseToAnyPublisher()
    }
    
    func getUserStats() {
        isSyncing = true
        syncError = nil
        
        networkService.getUserStats()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSyncing = false
                    if case .failure(let error) = completion {
                        self?.syncError = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    if let stats = response.stats {
                        self?.updateLocalStats(with: stats)
                    }
                    if let streak = response.streak {
                        self?.updateLocalStreak(with: streak)
                    }
                    self?.lastSyncDate = Date()
                    UserDefaults.standard.set(Date(), forKey: self?.lastSyncKey ?? "")
                }
            )
            .store(in: &cancellables)
    }
    
    func getDashboard() {
        networkService.getDashboard()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.syncError = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    // Update dashboard data
                    if let streak = response.streak {
                        self?.updateLocalStreak(with: streak)
                    }
                    if let gems = response.gems {
                        self?.updateLocalGems(with: gems)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func syncUserData() {
        getUserStats()
        getDashboard()
    }
    
    func updateUserPreferences(_ preferences: UserPreferences) {
        // TODO: Implement user preferences update when backend supports it
        // For now, just store locally
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "userPreferences")
        }
    }
    
    // MARK: - Social Features
    
    func sendFriendRequest(friendEmail: String) -> AnyPublisher<Bool, Error> {
        return networkService.sendFriendRequest(friendEmail: friendEmail)
            .map { _ in true }
            .eraseToAnyPublisher()
    }
    
    func respondToFriendRequest(requestId: String, action: String) -> AnyPublisher<Bool, Error> {
        return networkService.respondToFriendRequest(requestId: requestId, action: action)
            .map { _ in true }
            .eraseToAnyPublisher()
    }
    
    func getFriends() {
        networkService.getFriends()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.syncError = error.localizedDescription
                    }
                },
                receiveValue: { _ in
                    // Update friends data
                    // self?.friends = response.friends ?? []
                }
            )
            .store(in: &cancellables)
    }
    
    func fetchLeaderboard() {
        // TODO: Implement leaderboard when backend supports it
    }
    
    func fetchChallenges() {
        // TODO: Implement challenges when backend supports it
    }
    
    // MARK: - Local Data Management
    
    private func loadLocalData() {
        // Load local data - simplified for now
        lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }
    
    private func updateLocalStats(with stats: StatsData) {
        // Update local stats with backend data
        // This would update the RunManager's stats
    }
    
    private func updateLocalStreak(with streak: StreakData) {
        // Update local streak with backend data
        // This would update the RunManager's streak
    }
    
    private func updateLocalGems(with gems: GemsData) {
        // Update local gems with backend data
    }
    
    private func saveAuthData(token: String, userId: String) {
        UserDefaults.standard.set(token, forKey: authTokenKey)
        UserDefaults.standard.set(userId, forKey: userIdKey)
    }
    
    // MARK: - Pending Data Management
    
    private func storePendingRun(_ runData: Any) {
        // TODO: Implement pending run storage
    }
    
    private func removePendingRun(_ runData: Any) {
        // TODO: Implement pending run removal
    }
    
    private func getPendingRuns() -> [Any] {
        // TODO: Implement pending runs retrieval
        return []
    }
    
    func uploadPendingRuns() {
        // TODO: Implement pending runs upload when proper types are available
        // For now, this is commented out due to type issues
        /*
        let pendingRuns = getPendingRuns()
        
        for run in pendingRuns {
            // Convert to Supabase format and upload
            let distanceInMiles = run.distance / 1609.34
            let averageSpeedMph = (run.distance / run.duration) * 2.237
            let peakSpeedMph = run.maxPace > 0 ? (1000 / run.maxPace) * 2.237 : 0
            
            finishRun(
                runId: run.id.uuidString,
                distance: distanceInMiles,
                duration: run.duration,
                averageSpeed: averageSpeedMph,
                peakSpeed: peakSpeedMph
            )
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to upload pending run: \(error)")
                    }
                },
                receiveValue: { _ in
                    // Remove from pending runs on success
                    self.removePendingRun(run)
                }
            )
            .store(in: &cancellables)
        }
        */
    }
    
    // MARK: - Auto Sync
    
    private func setupAutoSync() {
        // Disable automatic syncing to prevent data mixing between users
        // Users will need to manually sync their data when needed
        /*
        // Sync every 5 minutes if connected
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                if self?.networkService.isConnected == true {
                    self?.syncUserData()
                }
            }
            .store(in: &cancellables)
        */
    }
    
    // MARK: - Utility Methods
    
    var isConnected: Bool {
        return networkService.isConnected
    }
    
    func isAuthenticated() -> Bool {
        return UserDefaults.standard.string(forKey: authTokenKey) != nil
    }
    
    func getUserId() -> String? {
        // Check if we're in guest mode
        if UserDefaults.standard.bool(forKey: "isGuestMode") {
            return UserDefaults.standard.string(forKey: "guestUserId")
        }
        return UserDefaults.standard.string(forKey: userIdKey)
    }
    
    func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: authTokenKey)
    }
    
    func saveAuthToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: authTokenKey)
    }
    
    func clearAuthToken() {
        UserDefaults.standard.removeObject(forKey: authTokenKey)
    }
    
    func setUserId(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: userIdKey)
    }
    
    func getCurrentUserId() -> String {
        return getUserId() ?? "unknown"
    }
    
    func loadUserData() {
        // Load user-specific data
        // Note: WorkoutStore and UserPreferencesManager handle their own loading
        GemsManager.shared.loadGemsData()
        AchievementManager.shared.calculateAchievements()
    }
    
    func hasPendingData() -> Bool {
        return !getPendingRuns().isEmpty
    }
} 