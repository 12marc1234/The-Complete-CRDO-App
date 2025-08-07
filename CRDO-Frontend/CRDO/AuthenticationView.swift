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
            } else {
                print("🔐 AuthenticationTracker init - no user data found")
            }
        }
        // Check if user was in guest mode
        else if UserDefaults.standard.bool(forKey: "isGuestMode") {
            self.isGuestMode = true
            print("🔐 AuthenticationTracker init - guest mode enabled")
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
        Task {
            await SupabaseManager.shared.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
            
            DispatchQueue.main.async {
                self.isLoading = SupabaseManager.shared.isLoading
                
                if SupabaseManager.shared.isAuthenticated {
                    self.isAuthenticated = true
                    self.isGuestMode = false
                    self.errorMessage = nil
                    
                    // Save authentication data
                    UserDefaults.standard.set(true, forKey: "isAuthenticated")
                    UserDefaults.standard.set(false, forKey: "isGuestMode")
                    
                    // Set current user
                    if let user = SupabaseManager.shared.currentUser {
                        self.currentUser = user
                        DataManager.shared.setUserId(user.id)
                        
                        // For signup, always clear data since it's a new user
                        print("🆕 New user signup - clearing any existing data")
                        self.clearAllUserData()
                        self.reloadLocalData()
                        
                        // Notify other components that user changed
                        NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: nil)
                    }
                } else {
                    self.errorMessage = SupabaseManager.shared.errorMessage
                }
            }
        }
    }
    
    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        NetworkService.shared.login(email: email, password: password)
            .sink(
                receiveCompletion: { completion in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            if let authError = error as? AuthError {
                                self.errorMessage = authError.errorDescription
                            } else {
                                self.errorMessage = error.localizedDescription
                            }
                        }
                    }
                },
                receiveValue: { response in
                    DispatchQueue.main.async {
                        print("🔐 Login successful - setting authentication state")
                        self.isAuthenticated = true
                        self.isGuestMode = false
                        self.errorMessage = nil
                        
                        // Save authentication data
                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
                        UserDefaults.standard.set(false, forKey: "isGuestMode")
                        print("🔐 Saved authentication data to UserDefaults")
                        
                        // Set current user from response
                        if let user = response.user {
                            self.currentUser = user
                            print("🔐 Set current user: \(user.email)")
                            
                            if let userData = try? JSONEncoder().encode(user) {
                                UserDefaults.standard.set(userData, forKey: "userData")
                            }
                            
                            // Set user ID for data isolation
                            DataManager.shared.setUserId(user.id)
                            
                            // Check if this is a different user than before
                            if let previousUser = self.currentUser,
                               previousUser.id != user.id {
                                print("🔄 Switching users - clearing previous user data")
                                self.clearAllUserData()
                            } else {
                                print("🔐 Same user login - preserving data")
                            }
                            
                            // Reload data for the current user
                            self.reloadLocalData()
                            
                            // Notify other components that user changed
                            NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: nil)
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func signOut() {
        Task {
            await SupabaseManager.shared.signOut()
            
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
                
                // Clear all user data
                self.clearAllUserData()
                
                // Clear authentication data
                UserDefaults.standard.set(false, forKey: "isAuthenticated")
                UserDefaults.standard.removeObject(forKey: "userData")
                
                print("🔐 User signed out and all data cleared")
                
                // Notify other components that user changed
                NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: nil)
            }
        }
    }
    
    private func clearLocalData() {
        // Clear RunManager data
        let runManager = RunManager()
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
        let runManager = RunManager()
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
        let runManager = RunManager()
        runManager.loadRecentRuns()
        
        // Reload GemsManager data for the new user
        let gemsManager = GemsManager.shared
        gemsManager.loadGemsData()
        
        // Reload DataManager data for the new user
        DataManager.shared.loadUserData()
        
        // Reload AchievementManager data for the new user
        let achievementManager = AchievementManager.shared
        achievementManager.calculateAchievements()
        
        print("🔄 Reloaded local data for user switch")
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
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.05, green: 0.05, blue: 0.15)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Logo and title
                        VStack(spacing: 20) {
                            Image(systemName: "figure.run.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                                .shadow(color: .blue.opacity(0.5), radius: 10)
                            
                            Text("CRDO")
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.3), radius: 5)
                            
                            Text("Track your runs, build your city")
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                        
                        // Authentication form
                        VStack(spacing: 20) {
                            // Toggle between sign up and login
                            Picker("Authentication Mode", selection: $isSignUp) {
                                Text("Sign In").tag(false)
                                Text("Sign Up").tag(true)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal)
                            
                            VStack(spacing: 15) {
                                if isSignUp {
                                    // First Name and Last Name fields for signup
                                    HStack(spacing: 10) {
                                        TextField("First Name", text: $firstName)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.words)
                                        
                                        TextField("Last Name", text: $lastName)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.words)
                                    }
                                }
                                
                                // Email field
                                TextField("Email", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                
                                // Password field
                                HStack {
                                    if showPassword {
                                        TextField("Password", text: $password)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    } else {
                                        SecureField("Password", text: $password)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                    
                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                // Error message
                                if let errorMessage = authTracker.errorMessage {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                
                                // Action button
                                Button(action: {
                                    if isSignUp {
                                        authTracker.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
                                    } else {
                                        authTracker.login(email: email, password: password)
                                    }
                                }) {
                                    HStack {
                                        if authTracker.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: isSignUp ? "person.badge.plus" : "person.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        
                                        Text(isSignUp ? "Create Account" : "Sign In")
                                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                                }
                                .disabled(authTracker.isLoading)
                                .padding(.horizontal)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(red: 0.15, green: 0.15, blue: 0.25))
                                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Guest mode button
                        VStack(spacing: 15) {
                            Divider()
                                .background(Color.gray.opacity(0.3))
                                .padding(.horizontal)
                            
                            Button(action: {
                                authTracker.enterGuestMode()
                            }) {
                                HStack {
                                    Image(systemName: "person.crop.circle")
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    Text("Continue as Guest")
                                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.3))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    AuthenticationView(authTracker: AuthenticationTracker.shared)
} 