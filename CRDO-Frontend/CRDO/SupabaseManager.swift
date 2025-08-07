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
            
            let body = [
                "email": email,
                "password": password,
                "firstName": firstName,
                "lastName": lastName
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    currentUser = authResponse.user
                    isAuthenticated = true
                    errorMessage = nil
                    
                    // Save auth token
                    if let session = authResponse.session {
                        DataManager.shared.saveAuthToken(session.access_token ?? "")
                    }
                } else {
                    let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                    errorMessage = errorResponse.error
                    isAuthenticated = false
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
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
            
            let body = [
                "email": email,
                "password": password
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    currentUser = authResponse.user
                    isAuthenticated = true
                    errorMessage = nil
                    
                    // Save auth token
                    if let session = authResponse.session {
                        DataManager.shared.saveAuthToken(session.access_token ?? "")
                    }
                } else {
                    let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                    errorMessage = errorResponse.error
                    isAuthenticated = false
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
        
        isLoading = false
    }
    
    @MainActor
    func signOut() async {
        // Clear local data
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
        
        // Clear auth token
        DataManager.shared.clearAuthToken()
        
        // Clear UserDefaults
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "userData")
    }
    
    @MainActor
    private func checkCurrentUser() async {
        // Check if we have a stored auth token
        if let token = DataManager.shared.getAuthToken() {
            // Validate token with backend
            do {
                let url = URL(string: "\(baseURL)/validate-token")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    currentUser = user
                    isAuthenticated = true
                } else {
                    // Token is invalid, clear it
                    DataManager.shared.clearAuthToken()
                    isAuthenticated = false
                }
            } catch {
                // Token validation failed, clear it
                DataManager.shared.clearAuthToken()
                isAuthenticated = false
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
            
            let workoutData = try JSONEncoder().encode(workout)
            request.httpBody = workoutData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
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
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
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
            
            let statsData = try JSONEncoder().encode(stats)
            request.httpBody = statsData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
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
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
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

// MARK: - Response Models

struct ErrorResponse: Codable {
    let error: String
} 