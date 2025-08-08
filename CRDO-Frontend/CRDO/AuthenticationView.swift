//
//  AuthenticationView.swift
//  CRDO
//
//  Created by Ethan Yip on 7/25/25.
//  Authentication view with sign up and login functionality
//

import SwiftUI
import Combine

// MARK: - Authentication Tracker

class AuthenticationTracker: ObservableObject {
    static let shared = AuthenticationTracker()
    
    @Published var isAuthenticated = false
    @Published var isGuestMode = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var cancellables = Set<AnyCancellable>()
    
    init() {
        // Check if user was previously authenticated
        let isAuth = UserDefaults.standard.bool(forKey: "isAuthenticated")
        print("🔐 AuthenticationTracker init - isAuthenticated: \(isAuth)")
        
        if isAuth {
            self.isAuthenticated = true
            if let userData = UserDefaults.standard.data(forKey: "userData"),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                self.currentUser = user
                print("🔐 AuthenticationTracker init - loaded user: \(user.email)")
                
                // CRITICAL FIX: Set user ID context for data isolation
                DataManager.shared.setUserId(user.id)
                
                // CRITICAL FIX: Reload all data for this user
                DispatchQueue.main.async {
                    self.reloadLocalData()
                    // Notify all managers that user context is set
                    NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: nil)
                }
            } else {
                print("🔐 AuthenticationTracker init - no user data found")
            }
        }
        // Check if user was in guest mode
        else if UserDefaults.standard.bool(forKey: "isGuestMode") {
            self.isGuestMode = true
            print("🔐 AuthenticationTracker init - guest mode enabled")
            
            // CRITICAL FIX: Set guest user ID context
            let guestUserId = UserDefaults.standard.string(forKey: "guestUserId") ?? "guest_\(UUID().uuidString)"
            UserDefaults.standard.set(guestUserId, forKey: "guestUserId")
            DataManager.shared.setUserId(guestUserId)
            
            // CRITICAL FIX: Reload all data for guest user
            DispatchQueue.main.async {
                self.reloadLocalData()
                NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: nil)
            }
        } else {
            print("🔐 AuthenticationTracker init - not authenticated, not guest mode")
        }
    }
    
    func enterGuestMode() {
        // Clear all existing data first
        clearAllUserData()
        
        // Generate a unique guest ID
        let guestId = "guest_\(UUID().uuidString)"
        
        isGuestMode = true
        isAuthenticated = false
        UserDefaults.standard.set(true, forKey: "isGuestMode")
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
        UserDefaults.standard.set(guestId, forKey: "guestUserId")
        
        print("🔐 Entered guest mode with ID: \(guestId)")
        
        // CRITICAL FIX: Set guest user ID context for data isolation
        DataManager.shared.setUserId(guestId)
        
        // CRITICAL FIX: Reload all data for guest user
        self.reloadLocalData()
        
        // Notify other components that user changed
        NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: nil)
    }
    
    func exitGuestMode() {
        isGuestMode = false
        UserDefaults.standard.set(false, forKey: "isGuestMode")
        UserDefaults.standard.removeObject(forKey: "guestUserId")
        
        print("🔐 Exited guest mode and cleared all data")
        
        // Notify other components that user changed
        NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: nil)
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) {
        // Use real Supabase authentication
        self.isLoading = true
        self.errorMessage = nil
        
        Task {
            await SupabaseManager.shared.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
            
            await MainActor.run {
                if SupabaseManager.shared.isAuthenticated {
                    self.isAuthenticated = true
                    self.isGuestMode = false
                    self.currentUser = SupabaseManager.shared.currentUser
                    
                    // Save authentication data
                    UserDefaults.standard.set(true, forKey: "isAuthenticated")
                    UserDefaults.standard.set(false, forKey: "isGuestMode")
                    
                    if let userData = try? JSONEncoder().encode(self.currentUser) {
                        UserDefaults.standard.set(userData, forKey: "userData")
                    }
                    
                    // Set user ID for data isolation
                    if let userId = self.currentUser?.id {
                        DataManager.shared.setUserId(userId)
                    }
                    
                    // For new accounts, ensure we start with clean data
                    self.clearDataForNewUser()
                    self.reloadLocalData()
                    
                    // Notify other components that user changed
                    NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: nil)
                    
                    print("✅ Real signup successful for: \(email)")
                } else {
                    self.errorMessage = SupabaseManager.shared.errorMessage ?? "Signup failed"
                }
                
                self.isLoading = false
            }
        }
    }
    
    func login(email: String, password: String) {
        // Use real Supabase authentication
        self.isLoading = true
        self.errorMessage = nil
        
        // CRITICAL FIX: Force reload mock database before attempting login
        let mockDatabase = MockUserDatabase.shared
        mockDatabase.forceReloadFromUserDefaults()
        
        Task {
            await SupabaseManager.shared.signIn(email: email, password: password)
            
            await MainActor.run {
                if SupabaseManager.shared.isAuthenticated {
                    self.isAuthenticated = true
                    self.isGuestMode = false
                    self.currentUser = SupabaseManager.shared.currentUser
                    
                    // Save authentication data
                    UserDefaults.standard.set(true, forKey: "isAuthenticated")
                    UserDefaults.standard.set(false, forKey: "isGuestMode")
                    
                    if let userData = try? JSONEncoder().encode(self.currentUser) {
                        UserDefaults.standard.set(userData, forKey: "userData")
                    }
                    
                    // Set user ID for data isolation
                    if let userId = self.currentUser?.id {
                        DataManager.shared.setUserId(userId)
                    }
                    
                    // Reload data for the current user
                    self.reloadLocalData()
                    
                    // Notify other components that user changed
                    NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: nil)
                    
                    print("✅ Real login successful for: \(email)")
                } else {
                    self.errorMessage = SupabaseManager.shared.errorMessage ?? "Login failed"
                }
                
                self.isLoading = false
            }
        }
    }
    
    func signOut() {
        // Use real Supabase sign out
        Task {
            await SupabaseManager.shared.signOut()
            
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                
                // DO NOT clear user data - preserve it for when user logs back in
                // Only clear authentication state
                UserDefaults.standard.set(false, forKey: "isAuthenticated")
                UserDefaults.standard.removeObject(forKey: "userData")
                
                // Clear current user ID to ensure data isolation
                DataManager.shared.setUserId("")
                
                print("🔐 User signed out - data preserved for next login")
                
                // Notify other components that user changed
                NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: nil)
            }
        }
    }
    
    private func clearLocalData() {
        // Clear RunManager data
        let runManager = RunManager.shared
        runManager.recentRuns.removeAll()
        runManager.saveRecentRuns()
        
        // Reset GemsManager data
        let gemsManager = GemsManager.shared
        gemsManager.totalGems = 0
        gemsManager.gemsEarnedToday = 0
        gemsManager.dailySecondsCompleted = 0
        gemsManager.saveGemsData()
        
        // Clear DataManager cached data
        DataManager.shared.userStats = nil
        DataManager.shared.streak = nil
        DataManager.shared.gems = nil
        DataManager.shared.friends = []
        
        print("🧹 Cleared local data for user switch")
    }
    
    func clearAllData() {
        // Clear all UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Clear RunManager data
        let runManager = RunManager.shared
        runManager.recentRuns.removeAll()
        runManager.saveRecentRuns()
        
        // Reset GemsManager data
        let gemsManager = GemsManager.shared
        gemsManager.totalGems = 0
        gemsManager.gemsEarnedToday = 0
        gemsManager.dailySecondsCompleted = 0
        gemsManager.saveGemsData()
        
        // Clear DataManager cached data
        DataManager.shared.userStats = nil
        DataManager.shared.streak = nil
        DataManager.shared.gems = nil
        DataManager.shared.friends = []
        
        // Clear AchievementManager data
        let achievementManager = AchievementManager.shared
        achievementManager.achievements.removeAll()
        UserDefaults.standard.removeObject(forKey: "unlockedAchievements")
        
        // Clear UserPreferencesManager data
        let preferencesManager = UserPreferencesManager.shared
        UserDefaults.standard.removeObject(forKey: "userPreferences")
        
        print("🗑️ Cleared ALL data for account deletion")
    }
    
    private func reloadLocalData() {
        // Reload RunManager data for the new user
        let runManager = RunManager.shared
        runManager.loadRecentRuns()
        
        // Reload GemsManager data for the new user
        let gemsManager = GemsManager.shared
        gemsManager.loadGemsData()
        
        // Reload WorkoutStore data for the new user
        WorkoutStore.shared.loadWorkouts()
        
        // Reload DataManager data for the new user
        DataManager.shared.loadUserData()
        
        // Reload AchievementManager data for the new user
        let achievementManager = AchievementManager.shared
        achievementManager.calculateAchievements()
        
        // Reload CityManager data for the new user
        CityManager.shared.loadCityData()
        
        print("🔄 Reloaded local data for user switch")
    }
    
    private func clearDataForNewUser() {
        // Clear data specifically for the new user to ensure clean start
        let userId = DataManager.shared.getUserId() ?? "unknown"
        let userDefaults = UserDefaults.standard
        
        // Clear user-specific data for this user only
        let allKeys = userDefaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.contains("_\(userId)_") || key.hasSuffix("_\(userId)") {
                userDefaults.removeObject(forKey: key)
                print("🗑️ Cleared new user data: \(key)")
            }
        }
        
        // Reset managers for new user
        GemsManager.shared.totalGems = 0
        GemsManager.shared.gemsEarnedToday = 0
        GemsManager.shared.dailySecondsCompleted = 0
        GemsManager.shared.saveGemsData()
        
        WorkoutStore.shared.workouts.removeAll()
        WorkoutStore.shared.saveWorkouts()
        
        AchievementManager.shared.achievements.removeAll()
        UserDefaults.standard.removeObject(forKey: "unlockedAchievements")
        
        CityManager.shared.resetCity()
        
        print("🧹 Cleared all data for new user: \(userId)")
    }
    
    private func clearAllUserData() {
        // Clear all user-specific data
        let userDefaults = UserDefaults.standard
        
        // Clear ALL user data (for any user)
        let allKeys = userDefaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix("gems_") || 
               key.hasPrefix("workouts_") || 
               key.hasPrefix("recentRuns_") ||
               key.hasPrefix("friends_") ||
               key.hasPrefix("achievements_") ||
               key.hasPrefix("userPreferences_") ||
               key.hasPrefix("userStats_") ||
               key.hasPrefix("streak_") ||
               key.hasPrefix("city_") ||
               key.hasPrefix("dailyProgress_") ||
               key.hasPrefix("profile_") ||
               key.hasPrefix("bio_") ||
               key.hasPrefix("description_") ||
               key.hasPrefix("buildings_") ||
               key.hasPrefix("cityBuildings_") ||
               key.hasPrefix("userProfile_") ||
               key.hasPrefix("userBio_") ||
               key.hasPrefix("userDescription_") {
                userDefaults.removeObject(forKey: key)
                print("🗑️ Removed key: \(key)")
            }
        }
        
        // Clear specific keys that might not follow the pattern
        userDefaults.removeObject(forKey: "userData")
        userDefaults.removeObject(forKey: "userPreferences")
        userDefaults.removeObject(forKey: "unlockedAchievements")
        userDefaults.removeObject(forKey: "userBio")
        userDefaults.removeObject(forKey: "userDescription")
        userDefaults.removeObject(forKey: "cityBuildings")
        userDefaults.removeObject(forKey: "userProfile")
        
        print("🗑️ Cleared all user-specific data")
    }
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @ObservedObject var authTracker: AuthenticationTracker
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showPassword = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // App title
                    VStack(spacing: 15) {
                        Text("CRDO")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.yellow)
                        
                        Text("Track your runs, build your city")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.yellow.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    
                    // Authentication form
                    VStack(spacing: 30) {
                        // Toggle between sign up and login
                        Picker("Authentication Mode", selection: $isSignUp) {
                            Text("Sign In").tag(false)
                            Text("Sign Up").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 40)
                        
                        VStack(spacing: 25) {
                            if isSignUp {
                                // First Name and Last Name fields for signup
                                HStack(spacing: 15) {
                                    TextField("First Name", text: $firstName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .autocapitalization(.words)
                                        .foregroundColor(.yellow)
                                        .background(Color.black)
                                    
                                    TextField("Last Name", text: $lastName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .autocapitalization(.words)
                                        .foregroundColor(.yellow)
                                        .background(Color.black)
                                }
                            }
                            
                            // Email field
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .foregroundColor(.yellow)
                                .background(Color.black)
                                .frame(height: 50)
                                .padding(.horizontal, 15)
                            
                            // Password field
                            HStack(spacing: 15) {
                                if showPassword {
                                    TextField("Password", text: $password)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .foregroundColor(.yellow)
                                        .background(Color.black)
                                        .frame(height: 50)
                                        .padding(.horizontal, 15)
                                } else {
                                    SecureField("Password", text: $password)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .foregroundColor(.yellow)
                                        .background(Color.black)
                                        .frame(height: 50)
                                        .padding(.horizontal, 15)
                                }
                                
                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.yellow)
                                        .font(.system(size: 18))
                                }
                            }
                            
                            // Error message
                            if let errorMessage = authTracker.errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.system(size: 14, weight: .medium))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                            
                            // Action button
                            Button(action: {
                                if isSignUp {
                                    authTracker.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
                                } else {
                                    authTracker.login(email: email, password: password)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    if authTracker.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: isSignUp ? "person.badge.plus" : "person.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                    }
                                    
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.yellow)
                                .cornerRadius(12)
                                .shadow(color: .yellow.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(authTracker.isLoading)
                            .padding(.horizontal, 40)
                        }
                        .padding(.vertical, 30)
                        .padding(.horizontal, 20)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 30)
                    }
                    
                    // Guest mode button
                    VStack(spacing: 20) {
                        Divider()
                            .background(Color.yellow.opacity(0.3))
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            authTracker.enterGuestMode()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 18, weight: .semibold))
                                
                                Text("Continue as Guest")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.yellow)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 50)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AuthenticationView(authTracker: AuthenticationTracker.shared)
} 