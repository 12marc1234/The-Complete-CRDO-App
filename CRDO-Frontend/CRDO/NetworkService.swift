//
//  NetworkService.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Network service for backend integration
//

import Foundation
import Combine

// MARK: - API Endpoints

enum APIEndpoint {
    case signup(email: String, password: String, firstName: String, lastName: String)
    case login(email: String, password: String)
    case logout
    case deleteAccount(password: String)
    case startRun
    case finishRun(runId: String, distance: Double, duration: TimeInterval, averageSpeed: Double, peakSpeed: Double)
    case getUserStats
    case getDashboard
    case sendFriendRequest(friendEmail: String)
    case respondToFriendRequest(requestId: String, action: String)
    case getFriends
    case speedValidation(runId: String, distance: Double, duration: TimeInterval, averageSpeed: Double, peakSpeed: Double)
    case health
    
    var path: String {
        switch self {
        case .signup:
            return "/signup"
        case .login:
            return "/login"
        case .logout:
            return "/logout"
        case .deleteAccount:
            return "/deleteAccount"
        case .startRun:
            return "/startRun"
        case .finishRun:
            return "/finishRun"
        case .getUserStats:
            return "/getUserStats"
        case .getDashboard:
            return "/getDashboard"
        case .sendFriendRequest:
            return "/sendFriendRequest"
        case .respondToFriendRequest:
            return "/respondToFriendRequest"
        case .getFriends:
            return "/getFriends"
        case .speedValidation:
            return "/speedValidation"
        case .health:
            return "/health"
        }
    }
    
    var method: String {
        switch self {
        case .signup, .login, .logout, .deleteAccount, .startRun, .finishRun, .sendFriendRequest, .respondToFriendRequest, .speedValidation:
            return "POST"
        case .getUserStats, .getDashboard, .getFriends, .health:
            return "GET"
        }
    }
    
    var body: Data? {
        switch self {
        case .signup(let email, let password, let firstName, let lastName):
            let signupData = ["email": email, "password": password, "firstName": firstName, "lastName": lastName]
            return try? JSONSerialization.data(withJSONObject: signupData)
            
        case .login(let email, let password):
            let loginData = ["email": email, "password": password]
            return try? JSONSerialization.data(withJSONObject: loginData)
            
        case .deleteAccount(let password):
            let deleteAccountData = ["password": password]
            return try? JSONSerialization.data(withJSONObject: deleteAccountData)
            
        case .finishRun(let runId, let distance, let duration, let averageSpeed, let peakSpeed):
            let finishRunData: [String: Any] = [
                "runId": runId,
                "distance": distance,
                "duration": duration,
                "averageSpeed": averageSpeed,
                "peakSpeed": peakSpeed
            ]
            return try? JSONSerialization.data(withJSONObject: finishRunData)
            
        case .sendFriendRequest(let friendEmail):
            let friendRequestData = ["friendEmail": friendEmail]
            return try? JSONSerialization.data(withJSONObject: friendRequestData)
            
        case .respondToFriendRequest(let requestId, let action):
            let responseData: [String: Any] = [
                "requestId": requestId,
                "action": action
            ]
            return try? JSONSerialization.data(withJSONObject: responseData)
            
        case .speedValidation(let runId, let distance, let duration, let averageSpeed, let peakSpeed):
            let validationData: [String: Any] = [
                "runId": runId,
                "distance": distance,
                "duration": duration,
                "averageSpeed": averageSpeed,
                "peakSpeed": peakSpeed
            ]
            return try? JSONSerialization.data(withJSONObject: validationData)
            
        default:
            return nil
        }
    }
}

// MARK: - Network Service

class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    // MARK: - Properties
    
    private let baseURL = BackendConfig.baseURL
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isConnected = false
    @Published var lastError: String?
    
    private init() {
        checkConnectivity()
    }
    
    // MARK: - Authentication
    
    func signup(email: String, password: String, firstName: String, lastName: String) -> AnyPublisher<AuthResponse, Error> {
        // Validate email format
        guard email.contains("@") && email.contains(".") else {
            return Fail(error: AuthError.invalidEmail)
                .eraseToAnyPublisher()
        }
        
        // Validate password length
        guard password.count >= 6 else {
            return Fail(error: AuthError.invalidPassword)
                .eraseToAnyPublisher()
        }
        
        // Make real network request to backend
        let endpoint = APIEndpoint.signup(email: email, password: password, firstName: firstName, lastName: lastName)
        return makeRequest(endpoint: endpoint)
            .decode(type: AuthResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func login(email: String, password: String) -> AnyPublisher<AuthResponse, Error> {
        // Validate email format
        guard email.contains("@") && email.contains(".") else {
            return Fail(error: AuthError.invalidEmail)
                .eraseToAnyPublisher()
        }
        
        // Validate password length
        guard password.count >= 6 else {
            return Fail(error: AuthError.invalidPassword)
                .eraseToAnyPublisher()
        }
        
        // Make real network request to backend
        let endpoint = APIEndpoint.login(email: email, password: password)
        return makeRequest(endpoint: endpoint)
            .decode(type: AuthResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func logout() -> AnyPublisher<LogoutResponse, Error> {
        let endpoint = APIEndpoint.logout
        return makeRequest(endpoint: endpoint)
            .decode(type: LogoutResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func deleteAccount(password: String) -> AnyPublisher<DeleteAccountResponse, Error> {
        // Make real network request to backend
        let endpoint = APIEndpoint.deleteAccount(password: password)
        return makeRequest(endpoint: endpoint)
            .decode(type: DeleteAccountResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Running
    
    func startRun() -> AnyPublisher<StartRunResponse, Error> {
        let endpoint = APIEndpoint.startRun
        return makeRequest(endpoint: endpoint)
            .decode(type: StartRunResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func finishRun(runId: String, distance: Double, duration: TimeInterval, averageSpeed: Double, peakSpeed: Double) -> AnyPublisher<FinishRunResponse, Error> {
        let endpoint = APIEndpoint.finishRun(runId: runId, distance: distance, duration: duration, averageSpeed: averageSpeed, peakSpeed: peakSpeed)
        return makeRequest(endpoint: endpoint)
            .decode(type: FinishRunResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func getUserStats() -> AnyPublisher<UserStatsResponse, Error> {
        let endpoint = APIEndpoint.getUserStats
        return makeRequest(endpoint: endpoint)
            .decode(type: UserStatsResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func getDashboard() -> AnyPublisher<DashboardResponse, Error> {
        let endpoint = APIEndpoint.getDashboard
        return makeRequest(endpoint: endpoint)
            .decode(type: DashboardResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Social Features
    
    func sendFriendRequest(friendEmail: String) -> AnyPublisher<FriendRequestResponse, Error> {
        let endpoint = APIEndpoint.sendFriendRequest(friendEmail: friendEmail)
        return makeRequest(endpoint: endpoint)
            .decode(type: FriendRequestResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func respondToFriendRequest(requestId: String, action: String) -> AnyPublisher<FriendResponseResponse, Error> {
        let endpoint = APIEndpoint.respondToFriendRequest(requestId: requestId, action: action)
        return makeRequest(endpoint: endpoint)
            .decode(type: FriendResponseResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func getFriends() -> AnyPublisher<FriendsResponse, Error> {
        let endpoint = APIEndpoint.getFriends
        return makeRequest(endpoint: endpoint)
            .decode(type: FriendsResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Validation
    
    func speedValidation(runId: String, distance: Double, duration: TimeInterval, averageSpeed: Double, peakSpeed: Double) -> AnyPublisher<SpeedValidationResponse, Error> {
        let endpoint = APIEndpoint.speedValidation(runId: runId, distance: distance, duration: duration, averageSpeed: averageSpeed, peakSpeed: peakSpeed)
        return makeRequest(endpoint: endpoint)
            .decode(type: SpeedValidationResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Health
    
    func health() -> AnyPublisher<HealthResponse, Error> {
        let endpoint = APIEndpoint.health
        return makeRequest(endpoint: endpoint)
            .decode(type: HealthResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func makeRequest(endpoint: APIEndpoint) -> AnyPublisher<Data, Error> {
        guard let url = URL(string: baseURL + endpoint.path) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication header
        // For signup/login, use anon key. For other requests, use stored token
        switch endpoint {
        case .signup, .login:
            // Use anon key for authentication endpoints
            let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        default:
            // Use stored token for other endpoints
            if let token = DataManager.shared.getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                // If no token, use anon key as fallback
                let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
                request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
            }
        }
        
        if let body = endpoint.body {
            request.httpBody = body
        }
        
        // Debug logging
        print("🌐 Making request to: \(url)")
        print("📤 Method: \(endpoint.method)")
        print("📤 Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = endpoint.body {
            print("📤 Body: \(String(data: body, encoding: .utf8) ?? "")")
        }
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(
                receiveSubscription: { _ in
                    DispatchQueue.main.async {
                        self.isConnected = true
                    }
                },
                receiveOutput: { data in
                    // Only log in debug builds to reduce overhead
                    #if DEBUG
                    print("📱 Response: \(String(data: data, encoding: .utf8) ?? "")")
                    #endif
                },
                receiveCompletion: { completion in
                    DispatchQueue.main.async {
                        if case .failure(let error) = completion {
                            self.lastError = error.localizedDescription
                            #if DEBUG
                            print("❌ Network error: \(error.localizedDescription)")
                            #endif
                        }
                    }
                }
            )
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    private func checkConnectivity() {
        guard let url = URL(string: baseURL + "/health") else { return }
        
        let request = URLRequest(url: url)
        session.dataTaskPublisher(for: request)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    DispatchQueue.main.async {
                        self.isConnected = true
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Response Models

struct MockUser: Codable {
    let id: String
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let fullName: String
}

// Note: AuthResponse, Session, SessionUser, Identity, IdentityData, AppMetadata, and UserMetadata 
// are now defined in SupabaseManager.swift to avoid duplicate definitions

// MARK: - Mock User Database

class MockUserDatabase {
    static let shared = MockUserDatabase()
    
    private var users: [MockUser] = []
    
    private init() {
        print("🏗️ MockUserDatabase singleton being initialized...")
        loadUsers()
        
        // Only add default test users if no users exist
        if users.isEmpty {
            print("📝 No users found, creating default test users...")
            // Create some test users
            users = [
                MockUser(
                    id: "user-1",
                    email: "test@example.com",
                    password: "password123",
                    firstName: "Test",
                    lastName: "User",
                    fullName: "Test User"
                ),
                MockUser(
                    id: "user-2", 
                    email: "demo@example.com",
                    password: "demo123",
                    firstName: "Demo",
                    lastName: "User",
                    fullName: "Demo User"
                )
            ]
            saveUsers()
        } else {
            print("📝 Found \(users.count) existing users in database")
        }
    }
    
    func addUser(_ user: MockUser) {
        users.append(user)
        saveUsers() // Save to UserDefaults immediately
        print("👤 Added user: \(user.email) - Total users: \(users.count)")
    }
    
    func addUser(user: User, password: String) {
        let mockUser = MockUser(
            id: user.id,
            email: user.email,
            password: password,
            firstName: user.firstName ?? "",
            lastName: user.lastName ?? "",
            fullName: user.fullName ?? ""
        )
        users.append(mockUser)
        saveUsers() // Save to UserDefaults immediately
        print("👤 Added user: \(user.email) - Total users: \(users.count)")
    }
    
    func verifyPassword(email: String, password: String) -> Bool {
        guard let mockUser = getMockUser(email: email) else {
            print("❌ Password verification failed: User not found")
            return false
        }
        
        let isValid = mockUser.password == password
        print("🔐 Password verification for \(email): \(isValid ? "✅ Valid" : "❌ Invalid")")
        return isValid
    }
    
    func getMockUser(email: String) -> MockUser? {
        print("🔍 Looking for user with email: \(email)")
        print("🔍 Email length: \(email.count)")
        print("🔍 Available users: \(users.map { $0.email })")
        
        // Check each user individually for debugging
        for user in users {
            let userEmailLower = user.email.lowercased()
            let inputEmailLower = email.lowercased()
            print("🔍 Comparing: '\(userEmailLower)' with '\(inputEmailLower)' - Match: \(userEmailLower == inputEmailLower)")
        }
        
        let user = users.first { $0.email.lowercased() == email.lowercased() }
        if let foundUser = user {
            print("✅ Found user: \(foundUser.email)")
        } else {
            print("❌ User not found for email: \(email)")
        }
        return user
    }
    
    func getUser(email: String) -> User? {
        guard let mockUser = getMockUser(email: email) else {
            return nil
        }
        
        return User(
            id: mockUser.id,
            email: mockUser.email,
            firstName: mockUser.firstName,
            lastName: mockUser.lastName,
            fullName: mockUser.fullName,
            bio: nil
        )
    }
    
    func userExists(email: String) -> Bool {
        let exists = getMockUser(email: email) != nil
        print("🔍 Checking if user exists: \(email) - \(exists)")
        return exists
    }
    
    func getUserCount() -> Int {
        return users.count
    }
    
    func debugUserDefaults() {
        print("🔍 DEBUG: Checking UserDefaults for mockUsers...")
        if let data = UserDefaults.standard.data(forKey: "mockUsers") {
            print("🔍 DEBUG: Found data in UserDefaults, size: \(data.count) bytes")
            if let loadedUsers = try? JSONDecoder().decode([MockUser].self, from: data) {
                print("🔍 DEBUG: Successfully decoded \(loadedUsers.count) users from UserDefaults")
                print("🔍 DEBUG: Users in UserDefaults: \(loadedUsers.map { $0.email })")
            } else {
                print("🔍 DEBUG: Failed to decode users from UserDefaults data")
            }
        } else {
            print("🔍 DEBUG: No data found in UserDefaults for key 'mockUsers'")
        }
        print("🔍 DEBUG: Current users in memory: \(users.count)")
        print("🔍 DEBUG: Users in memory: \(users.map { $0.email })")
    }
    
    // MARK: - Persistence Methods
    
    private func saveUsers() {
        print("💾 Attempting to save \(users.count) users...")
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: "mockUsers")
            UserDefaults.standard.synchronize() // Force immediate save
            print("💾 Successfully saved \(users.count) users to UserDefaults")
            print("💾 Users saved: \(users.map { $0.email })")
        } else {
            print("❌ Failed to encode users for saving")
        }
    }
    
    private func loadUsers() {
        print("📱 Attempting to load users from UserDefaults...")
        if let data = UserDefaults.standard.data(forKey: "mockUsers") {
            print("📱 Found data in UserDefaults, attempting to decode...")
            if let loadedUsers = try? JSONDecoder().decode([MockUser].self, from: data) {
                users = loadedUsers
                print("📱 Successfully loaded \(users.count) users from UserDefaults")
                print("📱 Users loaded: \(users.map { $0.email })")
            } else {
                print("❌ Failed to decode users from UserDefaults data")
                users = []
            }
        } else {
            print("📱 No saved users found in UserDefaults, starting with empty database")
            users = []
        }
    }
}

struct LogoutResponse: Codable {
    let message: String
}

struct DeleteAccountResponse: Codable {
    let message: String
}

struct StartRunResponse: Codable {
    let message: String
    let runId: String
    let startedAt: String
}

struct FinishRunResponse: Codable {
    let message: String
    let runId: String
    let streak: StreakData?
    let achievements: [String]?
}

struct StreakData: Codable {
    let current_streak: Int
    let longest_streak: Int
    let last_run_date: String
}

struct UserStatsResponse: Codable {
    let user: User?
    let stats: StatsData?
    let streak: StreakData?
    let achievements: [String]?
    let friends: FriendsData?
    let recentRuns: [RecentRun]?
}

struct StatsData: Codable {
    let totalRuns: Int
    let totalDistance: Double
    let totalDuration: Int
    let averageDistance: Double
    let averageDuration: Int
    let totalPoints: Int
    let totalGems: Int
    let weeklyRuns: Int
    let weeklyDistance: Double
    let weeklyDuration: Int
}



struct FriendsData: Codable {
    let accepted: Int
    let pendingRequests: Int
    let sentRequests: Int
    let total: Int
}

struct RecentRun: Codable {
    let id: String
    let distance: Double
    let duration: Int
    let average_speed: Double
    let peak_speed: Double
    let created_at: String
}

struct DashboardResponse: Codable {
    let streak: StreakData?
    let gems: GemsData?
    let recentRuns: [RecentRun]?
    let recentAchievements: [String]?
}

struct GemsData: Codable {
    let balance: Int
}

struct FriendRequestResponse: Codable {
    let message: String
    let friendRequest: FriendRequest?
}

struct FriendRequest: Codable {
    let id: String
    let user_id: String
    let friend_id: String
    let status: String
    let requested_at: String
}

struct FriendResponseResponse: Codable {
    let message: String
    let status: String
}

struct FriendsResponse: Codable {
    let friends: [Friend]?
    let pendingRequests: [FriendRequest]?
    let sentRequests: [FriendRequest]?
    let totalFriends: Int
    let totalPendingRequests: Int
    let totalSentRequests: Int
}

struct Friend: Codable {
    let id: String
    let email: String
    let relationshipId: String
    let status: String
    let requestedAt: String
    let respondedAt: String?
}

struct SpeedValidationResponse: Codable {
    let isLegitimate: Bool
    let confidence: Int
    let riskLevel: String
    let riskScore: Int
    let violations: [String]
    let warnings: [String]
    let evidence: ValidationEvidence?
    let recommendations: [String]
}

struct ValidationEvidence: Codable {
    let speedAnalysis: String
    let consistencyAnalysis: String
    let patternAnalysis: String
}

struct HealthResponse: Codable {
    let status: String
    let timestamp: String
    let version: String
    let database: DatabaseStatus?
    let functions: FunctionsStatus?
}

struct DatabaseStatus: Codable {
    let status: String
    let responseTime: Int
}

struct FunctionsStatus: Codable {
    let status: String
    let count: Int
}

// MARK: - Errors

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let message):
            return message
        }
    }
} 