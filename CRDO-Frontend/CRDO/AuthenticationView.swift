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
        if UserDefaults.standard.bool(forKey: "isAuthenticated") {
            self.isAuthenticated = true
            if let userData = UserDefaults.standard.data(forKey: "userData"),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                self.currentUser = user
            }
        }
        // Check if user was in guest mode
        else if UserDefaults.standard.bool(forKey: "isGuestMode") {
            self.isGuestMode = true
        }
    }
    
    func enterGuestMode() {
        isGuestMode = true
        isAuthenticated = false
        UserDefaults.standard.set(true, forKey: "isGuestMode")
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
    }
    
    func exitGuestMode() {
        isGuestMode = false
        UserDefaults.standard.set(false, forKey: "isGuestMode")
    }
    
    func signUp(email: String, password: String, firstName: String, lastName: String) {
        isLoading = true
        errorMessage = nil
        
        DataManager.shared.signup(email: email, password: password, firstName: firstName, lastName: lastName)
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
                        self.isGuestMode = false
                        self.errorMessage = nil
                        
                        // Save authentication data
                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
                        UserDefaults.standard.set(false, forKey: "isGuestMode")
                        
                        // Create and save user data
                        let user = User(id: DataManager.shared.currentUser?.id ?? "", email: email, firstName: firstName, lastName: lastName, fullName: "\(firstName) \(lastName)")
                        self.currentUser = user
                        
                        if let userData = try? JSONEncoder().encode(user) {
                            UserDefaults.standard.set(userData, forKey: "userData")
                        }
                        
                        // Reload local data for the new user
                        self.reloadLocalData()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func login(email: String, password: String) {
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
                        self.isGuestMode = false
                        self.errorMessage = nil
                        
                        // Save authentication data
                        UserDefaults.standard.set(true, forKey: "isAuthenticated")
                        UserDefaults.standard.set(false, forKey: "isGuestMode")
                        
                        // Set current user from DataManager
                        if let currentUser = DataManager.shared.currentUser {
                            self.currentUser = currentUser
                            
                            if let userData = try? JSONEncoder().encode(currentUser) {
                                UserDefaults.standard.set(userData, forKey: "userData")
                            }
                        }
                        
                        // Reload local data for the new user
                        self.reloadLocalData()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func signOut() {
        isAuthenticated = false
        currentUser = nil
        
        // Clear local data for the current user
        clearLocalData()
        
        // Clear authentication data
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
        UserDefaults.standard.removeObject(forKey: "userData")
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
    
    private func reloadLocalData() {
        // Reload RunManager data for the new user
        let runManager = RunManager()
        runManager.loadRecentRuns()
        
        // Reload GemsManager data for the new user
        let gemsManager = GemsManager.shared
        gemsManager.loadGemsData()
        
        // Don't automatically sync backend data - let user do it manually
        // This prevents mixing data from different users
        
        print("🔄 Reloaded local data for new user")
    }
}

// MARK: - Authentication View

struct AuthenticationView: View {
    @ObservedObject var authTracker: AuthenticationTracker
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showingPassword = false
    @State private var showingConfirmPassword = false
    @State private var rememberMe = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    private let dataManager = DataManager.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.black.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Logo and title
                        VStack(spacing: 20) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 80))
                                .foregroundColor(.gold)
                            
                            Text("CRDO")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(isSignUp ? "Create your account" : "Welcome back")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 50)
                        
                        // Form fields
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
                            
                            // First Name Field (only for sign up)
                            if isSignUp {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("First Name")
                                        .font(.caption)
                                        .foregroundColor(.gold)
                                        .fontWeight(.semibold)
                                    
                                    TextField("Enter your first name", text: $firstName)
                                        .textFieldStyle(AuthTextFieldStyle())
                                        .autocapitalization(.words)
                                }
                            }
                            
                            // Last Name Field (only for sign up)
                            if isSignUp {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Last Name")
                                        .font(.caption)
                                        .foregroundColor(.gold)
                                        .fontWeight(.semibold)
                                    
                                    TextField("Enter your last name", text: $lastName)
                                        .textFieldStyle(AuthTextFieldStyle())
                                        .autocapitalization(.words)
                                }
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
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                    }
                                    
                                    Button(action: {
                                        showingPassword.toggle()
                                    }) {
                                        Image(systemName: showingPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .textFieldStyle(AuthTextFieldStyle())
                            }
                            
                            // Confirm Password Field (only for sign up)
                            if isSignUp {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Confirm Password")
                                        .font(.caption)
                                        .foregroundColor(.gold)
                                        .fontWeight(.semibold)
                                    
                                    HStack {
                                        if showingConfirmPassword {
                                            TextField("Confirm your password", text: $confirmPassword)
                                        } else {
                                            SecureField("Confirm your password", text: $confirmPassword)
                                        }
                                        
                                        Button(action: {
                                            showingConfirmPassword.toggle()
                                        }) {
                                            Image(systemName: showingConfirmPassword ? "eye.slash" : "eye")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .textFieldStyle(AuthTextFieldStyle())
                                }
                            }
                            
                            // Remember Me (only for login)
                            if !isSignUp {
                                HStack {
                                    Toggle("Remember me", isOn: $rememberMe)
                                        .toggleStyle(SwitchToggleStyle(tint: .gold))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        // Error message
                        if !errorMessage.isEmpty || authTracker.errorMessage != nil {
                            Text(authTracker.errorMessage ?? errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal, 30)
                        }
                        
                        // Action button
                        Button(action: performAuthentication) {
                            HStack {
                                if authTracker.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(isSignUp ? "Sign Up" : "Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.gold)
                            .cornerRadius(25)
                        }
                        .disabled(authTracker.isLoading)
                        .padding(.horizontal, 30)
                        
                        // Continue as Guest button
                        Button(action: {
                            authTracker.enterGuestMode()
                        }) {
                            HStack {
                                Image(systemName: "person.fill")
                                Text("Continue as Guest")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 10)
                        
                        // Toggle between sign up and sign in
                        HStack {
                            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isSignUp.toggle()
                                    email = ""
                                    password = ""
                                    confirmPassword = ""
                                    firstName = ""
                                    lastName = ""
                                    rememberMe = false
                                    errorMessage = ""
                                }
                            }) {
                                Text(isSignUp ? "Sign In" : "Sign Up")
                                    .foregroundColor(.gold)
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.caption)
                        
                        Spacer()
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
    }
    
    private func performAuthentication() {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        if isSignUp {
            guard !firstName.isEmpty && !lastName.isEmpty else {
                errorMessage = "Please fill in your first and last name"
                return
            }
            
            guard password == confirmPassword else {
                errorMessage = "Passwords don't match"
                return
            }
            
            guard password.count >= 6 else {
                errorMessage = "Password must be at least 6 characters"
                return
            }
        }
        
        // Don't set isLoading here, let the AuthenticationTracker handle it
        errorMessage = ""
        
        if isSignUp {
            authTracker.signUp(email: email, password: password, firstName: firstName, lastName: lastName)
        } else {
            // Handle login using AuthenticationTracker
            authTracker.login(email: email, password: password)
        }
    }
}

// MARK: - Custom Text Field Style

struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .foregroundColor(.white)
    }
}

#Preview {
    AuthenticationView(authTracker: AuthenticationTracker.shared)
} 