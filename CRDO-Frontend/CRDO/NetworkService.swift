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
    
    private let baseURL = BackendConfig.currentEnvironment.baseURL
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isConnected = false
    @Published var lastError: String?
    
    private init() {
        checkConnectivity()
    }
    
    // MARK: - Authentication
    
    func signup(email: String, password: String, firstName: String, lastName: String) -> AnyPublisher<AuthResponse, Error> {
        let endpoint = APIEndpoint.signup(email: email, password: password, firstName: firstName, lastName: lastName)
        return makeRequest(endpoint: endpoint)
            .decode(type: AuthResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func login(email: String, password: String) -> AnyPublisher<AuthResponse, Error> {
        let endpoint = APIEndpoint.login(email: email, password: password)
        return makeRequest(endpoint: endpoint)
            .handleEvents(
                receiveOutput: { data in
                    print("🔍 Raw login response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                },
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Login error: \(error)")
                        
                        // Check for specific network errors
                        if let urlError = error as? URLError {
                            switch urlError.code {
                            case .cannotConnectToHost:
                                print("❌ Cannot connect to backend server. Please check if the server is running.")
                            case .timedOut:
                                print("❌ Connection timed out. Please check your network connection.")
                            case .notConnectedToInternet:
                                print("❌ No internet connection. Please check your network.")
                            default:
                                print("❌ Network error: \(urlError.localizedDescription)")
                            }
                        }
                        
                        if let decodingError = error as? DecodingError {
                            switch decodingError {
                            case .keyNotFound(let key, let context):
                                print("❌ Missing key: \(key.stringValue) at path: \(context.codingPath)")
                            case .typeMismatch(let type, let context):
                                print("❌ Type mismatch: expected \(type) at path: \(context.codingPath)")
                            case .valueNotFound(let type, let context):
                                print("❌ Value not found: expected \(type) at path: \(context.codingPath)")
                            case .dataCorrupted(let context):
                                print("❌ Data corrupted at path: \(context.codingPath)")
                            @unknown default:
                                print("❌ Unknown decoding error")
                            }
                        }
                    }
                }
            )
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
        let endpoint = APIEndpoint.deleteAccount(password: password)
        return makeRequest(endpoint: endpoint)
            .handleEvents(receiveOutput: { data in
                print("🔍 Delete account raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
            })
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