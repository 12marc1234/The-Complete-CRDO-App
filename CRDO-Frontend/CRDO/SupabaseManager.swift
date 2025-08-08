//
//  SupabaseManager.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Supabase backend integration
//

import Foundation
import Combine

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    // Use the real backend URL from BackendConfig
    private let baseURL = BackendConfig.baseURL
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // Configure URLSession with proper timeouts
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = BackendConfig.requestTimeout
        config.timeoutIntervalForResource = BackendConfig.uploadTimeout
        return URLSession(configuration: config)
    }()
    
    private init() {
        // Check if user is already signed in
        Task {
            await checkCurrentUser()
        }
    }
    
    @MainActor
    func signUp(email: String, password: String, firstName: String, lastName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let url = URL(string: "\(baseURL)/signup")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = BackendConfig.requestTimeout
            
            let body = [
                "email": email,
                "password": password,
                "firstName": firstName,
                "lastName": lastName
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            print("🔐 Attempting signup to: \(url)")
            
            let (data, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔐 Signup response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    currentUser = authResponse.user
                    isAuthenticated = true
                    errorMessage = nil
                    
                    // Save auth token
                    if let session = authResponse.session {
                        DataManager.shared.saveAuthToken(session.access_token ?? "")
                    }
                    
                    print("✅ Real signup successful")
                } else {
                    let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                    errorMessage = errorResponse.error
                    isAuthenticated = false
                    print("❌ Real signup failed: \(errorResponse.error)")
                }
            }
        } catch {
            print("❌ Signup network error: \(error.localizedDescription)")
            
            // FALLBACK: Use mock authentication when backend is unavailable
            await fallbackToMockSignUp(email: email, password: password, firstName: firstName, lastName: lastName)
        }
        
        isLoading = false
    }
    
    @MainActor
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let url = URL(string: "\(baseURL)/login")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = BackendConfig.requestTimeout
            
            let body = [
                "email": email,
                "password": password
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            print("🔐 Attempting login to: \(url)")
            
            let (data, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔐 Login response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    currentUser = authResponse.user
                    isAuthenticated = true
                    errorMessage = nil
                    
                    // Save auth token
                    if let session = authResponse.session {
                        DataManager.shared.saveAuthToken(session.access_token ?? "")
                    }
                    
                    print("✅ Real login successful")
                } else {
                    let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                    errorMessage = errorResponse.error
                    isAuthenticated = false
                    print("❌ Real login failed: \(errorResponse.error)")
                }
            }
        } catch {
            print("❌ Login network error: \(error.localizedDescription)")
            
            // FALLBACK: Use mock authentication when backend is unavailable
            await fallbackToMockSignIn(email: email, password: password)
        }
        
        isLoading = false
    }
    
    // MARK: - Fallback Mock Authentication
    
    @MainActor
    private func fallbackToMockSignUp(email: String, password: String, firstName: String, lastName: String) async {
        print("🔄 Falling back to mock signup")
        
        // Validate input
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required"
            isAuthenticated = false
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            isAuthenticated = false
            return
        }
        
        // Check if user already exists
        let mockDatabase = MockUserDatabase.shared
        if mockDatabase.getUser(email: email) != nil {
            errorMessage = "An account with this email already exists"
            isAuthenticated = false
            return
        }
        
        // Create new user
        let newUser = User(
            id: UUID().uuidString,
            email: email,
            firstName: firstName,
            lastName: lastName,
            fullName: "\(firstName) \(lastName)"
        )
        
        // Add to mock database
        mockDatabase.addUser(user: newUser, password: password)
        
        // Set authentication state
        currentUser = newUser
        isAuthenticated = true
        errorMessage = nil
        
        // Save mock auth token
        DataManager.shared.saveAuthToken("mock_token_\(newUser.id)")
        
        print("✅ Mock signup successful for: \(email)")
    }
    
    @MainActor
    private func fallbackToMockSignIn(email: String, password: String) async {
        print("🔄 Falling back to mock signin")
        
        // Validate input
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Email and password are required"
            isAuthenticated = false
            return
        }
        
        // CRITICAL FIX: Force reload mock database before checking
        let mockDatabase = MockUserDatabase.shared
        mockDatabase.forceReloadFromUserDefaults()
        
        // Debug: List all users in mock database
        mockDatabase.listAllUsers()
        
        // Check if user exists in mock database
        guard let existingUser = mockDatabase.getUser(email: email) else {
            errorMessage = "No account found with this email"
            isAuthenticated = false
            print("❌ Mock signin failed: No account found for \(email)")
            
            // CRITICAL FIX: Try to repair database and check again
            print("🔧 Attempting database repair...")
            mockDatabase.repairDatabase()
            
            // Check again after repair
            if let repairedUser = mockDatabase.getUser(email: email) {
                print("✅ Found user after database repair!")
                
                // Verify password
                guard mockDatabase.verifyPassword(email: email, password: password) else {
                    errorMessage = "Incorrect password"
                    isAuthenticated = false
                    print("❌ Mock signin failed: Incorrect password for \(email)")
                    return
                }
                
                // Set authentication state
                currentUser = repairedUser
                isAuthenticated = true
                errorMessage = nil
                
                // Save mock auth token
                DataManager.shared.saveAuthToken("mock_token_\(repairedUser.id)")
                
                print("✅ Mock signin successful for: \(email) after database repair")
                return
            } else {
                print("❌ User still not found after database repair")
            }
            return
        }
        
        // Verify password
        guard mockDatabase.verifyPassword(email: email, password: password) else {
            errorMessage = "Incorrect password"
            isAuthenticated = false
            print("❌ Mock signin failed: Incorrect password for \(email)")
            return
        }
        
        // Set authentication state
        currentUser = existingUser
        isAuthenticated = true
        errorMessage = nil
        
        // Save mock auth token
        DataManager.shared.saveAuthToken("mock_token_\(existingUser.id)")
        
        print("✅ Mock signin successful for: \(email)")
    }
    
    // MARK: - Debug Methods
    
    func debugAuthentication() {
        print("🔍 DEBUG: Authentication Status")
        print("  - Is Authenticated: \(isAuthenticated)")
        print("  - Current User: \(currentUser?.email ?? "None")")
        print("  - Auth Token: \(DataManager.shared.getAuthToken() ?? "None")")
        
        let mockDatabase = MockUserDatabase.shared
        print("  - Mock Database Users: \(mockDatabase.getUserCount())")
        mockDatabase.listAllUsers()
    }
    
    func clearMockDatabase() {
        let mockDatabase = MockUserDatabase.shared
        mockDatabase.clearAllUsers()
        print("🗑️ Mock database cleared")
    }
    
    func testMockAuthentication(email: String, password: String) {
        print("🧪 Testing mock authentication for: \(email)")
        let mockDatabase = MockUserDatabase.shared
        
        let userExists = mockDatabase.userExists(email: email)
        print("  - User exists: \(userExists)")
        
        if userExists {
            let passwordValid = mockDatabase.verifyPassword(email: email, password: password)
            print("  - Password valid: \(passwordValid)")
        }
    }
    
    // MARK: - Multi-Account Testing
    
    func testMultiAccountScenario() {
        print("🧪 Testing multi-account scenario...")
        let mockDatabase = MockUserDatabase.shared
        
        print("📋 Current users in database:")
        mockDatabase.listAllUsers()
        
        print("🔍 Testing database integrity...")
        mockDatabase.debugUserDefaults()
        
        print("🧪 Multi-account test complete")
    }
    
    func simulateSignOutAndSignIn(email: String, password: String) {
        print("🧪 Simulating sign out and sign in for: \(email)")
        
        // Step 1: Check if user exists before sign out
        let mockDatabase = MockUserDatabase.shared
        print("📋 Users before sign out:")
        mockDatabase.listAllUsers()
        
        let userExistsBefore = mockDatabase.userExists(email: email)
        print("  - User exists before sign out: \(userExistsBefore)")
        
        // Step 2: Simulate sign out
        print("🔐 Simulating sign out...")
        currentUser = nil
        isAuthenticated = false
        DataManager.shared.clearAuthToken()
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "userData")
        
        // Step 3: Ensure database preservation
        mockDatabase.ensureDatabasePreservation()
        
        // Step 4: Check if user still exists after sign out
        print("📋 Users after sign out:")
        mockDatabase.listAllUsers()
        
        let userExistsAfter = mockDatabase.userExists(email: email)
        print("  - User exists after sign out: \(userExistsAfter)")
        
        // Step 5: Simulate sign in attempt
        print("🔐 Simulating sign in attempt...")
        mockDatabase.forceReloadFromUserDefaults()
        
        let userExistsAfterReload = mockDatabase.userExists(email: email)
        print("  - User exists after reload: \(userExistsAfterReload)")
        
        if userExistsAfterReload {
            let passwordValid = mockDatabase.verifyPassword(email: email, password: password)
            print("  - Password valid: \(passwordValid)")
        }
        
        print("🧪 Simulation complete")
    }
    
    @MainActor
    func signOut() async {
        print("🔐 Starting sign out process...")
        
        // Debug: Check mock database before sign out
        let mockDatabase = MockUserDatabase.shared
        print("🔍 Mock database before sign out:")
        mockDatabase.listAllUsers()
        
        // CRITICAL FIX: Ensure mock database is preserved before clearing auth data
        mockDatabase.ensureDatabasePreservation()
        
        // Clear local data
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
        
        // Clear auth token
        DataManager.shared.clearAuthToken()
        
        // Clear UserDefaults (but preserve mock database)
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "userData")
        
        // CRITICAL FIX: Force reload to ensure mock database is still accessible
        mockDatabase.forceReloadFromUserDefaults()
        
        print("🔐 User signed out - mock database preserved")
        
        // Debug: Check mock database after sign out
        print("🔍 Mock database after sign out:")
        mockDatabase.listAllUsers()
    }
    
    @MainActor
    private func checkCurrentUser() async {
        // Check if we have a stored auth token
        if let token = DataManager.shared.getAuthToken() {
            // For mock tokens, just validate locally
            if token.hasPrefix("mock_token_") {
                // Mock token validation - just check if it exists
                isAuthenticated = true
                print("✅ Mock token validated")
                return
            }
            
            // Real token validation with backend
            do {
                let url = URL(string: "\(baseURL)/validate-token")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = BackendConfig.requestTimeout
                
                let (data, response) = try await urlSession.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    currentUser = user
                    isAuthenticated = true
                    print("✅ Real token validated")
                } else {
                    // Token is invalid, clear it
                    DataManager.shared.clearAuthToken()
                    isAuthenticated = false
                    print("❌ Real token invalid")
                }
            } catch {
                // Token validation failed, clear it
                DataManager.shared.clearAuthToken()
                isAuthenticated = false
                print("❌ Token validation failed: \(error.localizedDescription)")
            }
        }
    }
    
    func saveWorkout(_ workout: Workout) async {
        guard let token = DataManager.shared.getAuthToken() else { return }
        
        do {
            let url = URL(string: "\(baseURL)/save-workout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = BackendConfig.requestTimeout
            
            let workoutData = try JSONEncoder().encode(workout)
            request.httpBody = workoutData
            
            let (_, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Workout saved to backend")
                } else {
                    print("❌ Failed to save workout to backend")
                }
            }
        } catch {
            print("❌ Error saving workout to backend: \(error)")
        }
    }
    
    func loadWorkouts() async -> [Workout] {
        guard let token = DataManager.shared.getAuthToken() else { return [] }
        
        do {
            let url = URL(string: "\(baseURL)/load-workouts")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = BackendConfig.requestTimeout
            
            let (data, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let workouts = try JSONDecoder().decode([Workout].self, from: data)
                return workouts
            }
        } catch {
            print("❌ Error loading workouts from backend: \(error)")
        }
        
        return []
    }
    
    func saveUserStats(_ stats: UserStats) async {
        guard let token = DataManager.shared.getAuthToken() else { return }
        
        do {
            let url = URL(string: "\(baseURL)/save-user-stats")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = BackendConfig.requestTimeout
            
            let statsData = try JSONEncoder().encode(stats)
            request.httpBody = statsData
            
            let (_, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ User stats saved to backend")
                } else {
                    print("❌ Failed to save user stats to backend")
                }
            }
        } catch {
            print("❌ Error saving user stats to backend: \(error)")
        }
    }
    
    func loadUserStats() async -> UserStats? {
        guard let token = DataManager.shared.getAuthToken() else { return nil }
        
        do {
            let url = URL(string: "\(baseURL)/load-user-stats")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = BackendConfig.requestTimeout
            
            let (data, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let stats = try JSONDecoder().decode(UserStats.self, from: data)
                return stats
            }
        } catch {
            print("❌ Error loading user stats from backend: \(error)")
        }
        
        return nil
    }
}

// MARK: - User Model

struct User: Codable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let fullName: String?
    var bio: String? // New field for user bio
    
    // Custom initializer to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        // These fields are optional and may not be present in backend response
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName) ?? nil
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName) ?? nil
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? nil
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? nil
    }
    
    // Convenience initializer for creating User from backend data
    init(id: String, email: String, firstName: String? = nil, lastName: String? = nil, fullName: String? = nil, bio: String? = nil) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.fullName = fullName
        self.bio = bio
    }
}

// MARK: - Authentication Errors

enum AuthError: LocalizedError {
    case invalidEmail
    case invalidPassword
    case userNotFound
    case wrongPassword
    case emailAlreadyExists
    case weakPassword
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidPassword:
            return "Password must be at least 6 characters"
        case .userNotFound:
            return "No account found with this email"
        case .wrongPassword:
            return "Incorrect password"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .weakPassword:
            return "Password is too weak"
        }
    }
}

// MARK: - Response Models

struct ErrorResponse: Codable {
    let error: String
}

struct AuthResponse: Codable {
    let message: String
    let user: User?
    let session: Session?
}

struct Session: Codable {
    let access_token: String?
    let refresh_token: String?
    let token_type: String?
    let expires_in: Int?
    let expires_at: Int?
    let user: SessionUser?
}

struct SessionUser: Codable {
    let id: String?
    let aud: String?
    let role: String?
    let email: String?
    let email_confirmed_at: String?
    let phone: String?
    let last_sign_in_at: String?
    let app_metadata: AppMetadata?
    let user_metadata: UserMetadata?
    let identities: [Identity]?
    let created_at: String?
    let updated_at: String?
    let is_anonymous: Bool?
}

struct Identity: Codable {
    let identity_id: String?
    let id: String?
    let user_id: String?
    let identity_data: IdentityData?
    let provider: String?
    let last_sign_in_at: String?
    let created_at: String?
    let updated_at: String?
    let email: String?
}

struct IdentityData: Codable {
    let email: String?
    let email_verified: Bool?
    let first_name: String?
    let full_name: String?
    let last_name: String?
    let phone_verified: Bool?
    let sub: String?
}

struct AppMetadata: Codable {
    let provider: String?
    let providers: [String]?
}

struct UserMetadata: Codable {
    let email: String?
    let email_verified: Bool?
    let first_name: String?
    let full_name: String?
    let last_name: String?
    let phone_verified: Bool?
    let sub: String?
} 