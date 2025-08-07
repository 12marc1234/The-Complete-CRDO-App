//
//  ProfileView.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Profile view with settings and user info
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var authTracker: AuthenticationTracker
    @ObservedObject var preferencesManager = UserPreferencesManager.shared
    @ObservedObject var gemsManager = GemsManager.shared
    @State private var isEditingBio = false
    @State private var userBio = "Runner" // Default bio
    @State private var showingAchievements = false
    @State private var scrollOffset: CGFloat = 0
    
    // Real achievements data - will be loaded from backend
    @StateObject private var achievementManager = AchievementManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Enhanced background
                LinearGradient.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Profile header with fade-in animation
                        ProfileHeaderSection(
                            authTracker: authTracker,
                            userBio: $userBio,
                            isEditingBio: $isEditingBio,
                            scrollOffset: scrollOffset
                        )
                        .opacity(max(0.3, 1.0 - scrollOffset / 200))
                        .scaleEffect(max(0.8, 1.0 - scrollOffset / 400))
                        .padding(.horizontal, 20)
                        
                        // Stats summary removed - redundant with Quick Stats on home
                        
                        // Gems section with fade-in
                        ProfileGemsSection(gemsManager: gemsManager, scrollOffset: scrollOffset)
                            .opacity(max(0.3, 1.0 - scrollOffset / 250))
                            .padding(.horizontal, 20)
                        
                        // Achievements section with fade-in
                        AchievementsSection(
                            achievements: achievementManager.achievements,
                            showingAchievements: $showingAchievements,
                            scrollOffset: scrollOffset,
                            isLoading: false
                        )
                        .opacity(max(0.3, 1.0 - scrollOffset / 200))
                        .padding(.horizontal, 20)
                        
                        // Settings with fade-in
                        SettingsSection(
                            preferencesManager: preferencesManager,
                            scrollOffset: scrollOffset
                        )
                        .opacity(max(0.3, 1.0 - scrollOffset / 150))
                        .padding(.horizontal, 20)
                        
                        // Actions with fade-in
                        ActionsSection(authTracker: authTracker, scrollOffset: scrollOffset)
                            .opacity(max(0.3, 1.0 - scrollOffset / 100))
                            .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                    }
                )
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        isEditingBio = true
                    }
                    .foregroundColor(.gold)
                }
            }
            .sheet(isPresented: $showingAchievements) {
                AchievementsView(achievements: achievementManager.achievements)
            }
        }
        .onAppear {
            // Load user bio from UserDefaults
            userBio = UserDefaults.standard.string(forKey: "userBio") ?? "Runner"
            
            // Refresh achievements based on current data
            achievementManager.refreshAchievements()
        }
    }
    

}



// MARK: - Profile Header Section

struct ProfileHeaderSection: View {
    @ObservedObject var authTracker: AuthenticationTracker
    @Binding var userBio: String
    @Binding var isEditingBio: Bool
    let scrollOffset: CGFloat
    
    var body: some View {
        VStack(spacing: 20) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.gold.opacity(0.3))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.gold)
            }
            
            // User info
            VStack(spacing: 8) {
                Text(authTracker.currentUser?.fullName ?? (authTracker.currentUser?.firstName != nil ? "\(authTracker.currentUser?.firstName ?? "") \(authTracker.currentUser?.lastName ?? "")" : "User"))
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                if isEditingBio {
                    VStack(spacing: 8) {
                        TextField("Enter your bio", text: $userBio, axis: .vertical)
                            .textFieldStyle(CustomTextFieldStyle())
                            .foregroundColor(.white)
                            .onSubmit {
                                UserDefaults.standard.set(userBio, forKey: "userBio")
                                isEditingBio = false
                            }
                        
                        HStack {
                            Button("Cancel") {
                                isEditingBio = false
                            }
                            .foregroundColor(.gray)
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            Button("Done") {
                                UserDefaults.standard.set(userBio, forKey: "userBio")
                                isEditingBio = false
                            }
                            .foregroundColor(.gold)
                            .buttonStyle(PlainButtonStyle())
                        }
                        .font(.caption)
                    }
                } else {
                    Text(userBio)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .onTapGesture {
                            isEditingBio = true
                        }
                }
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Stats Section

// StatsSection removed - redundant with Quick Stats on home

// MARK: - Gems Section

struct ProfileGemsSection: View {
    @ObservedObject var gemsManager: GemsManager
    let scrollOffset: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Gems")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                StatCard(
                    title: "Total Gems",
                    value: "\(gemsManager.totalGems)",
                    subtitle: "Lifetime",
                    color: .yellow
                )
                
                StatCard(
                    title: "Today's Earnings",
                    value: "+\(gemsManager.gemsEarnedToday)",
                    subtitle: "Gems earned",
                    color: .green
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Achievements Section

struct AchievementsSection: View {
    let achievements: [Achievement]
    @Binding var showingAchievements: Bool
    let scrollOffset: CGFloat
    let isLoading: Bool
    
    var unlockedAchievements: [Achievement] {
        achievements.filter { $0.isUnlocked }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View All") {
                    showingAchievements = true
                }
                .foregroundColor(.gold)
            }
            .padding(.horizontal)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .gold))
                        .scaleEffect(0.8)
                    Text("Loading achievements...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(Array(unlockedAchievements.prefix(3))) { achievement in
                            AchievementCard(achievement: achievement)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(achievement.category.color.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                Image(systemName: achievement.icon)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(achievement.category.color)
            }
            
            Text(achievement.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(achievement.category.color.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Settings Section

struct SettingsSection: View {
    @ObservedObject var preferencesManager: UserPreferencesManager
    let scrollOffset: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Settings")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "ruler",
                    title: "Units",
                    value: preferencesManager.preferences.unitSystem == .imperial ? "Imperial" : "Metric"
                ) {
                    preferencesManager.preferences.unitSystem = preferencesManager.preferences.unitSystem == .imperial ? .metric : .imperial
                    // Force UI update
                    DispatchQueue.main.async {
                        preferencesManager.objectWillChange.send()
                    }
                }
                

            }
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Actions Section

struct ActionsSection: View {
    @ObservedObject var authTracker: AuthenticationTracker
    let scrollOffset: CGFloat
    @State private var showingDeleteConfirmation = false
    @State private var deletePassword = ""
    @State private var isDeletingAccount = false
    @State private var deleteError = ""
    
    var body: some View {
        VStack(spacing: 15) {
            Button(authTracker.isGuestMode ? "Exit Guest Mode" : "Sign Out") {
                if authTracker.isGuestMode {
                    authTracker.exitGuestMode()
                } else {
                    authTracker.signOut()
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(authTracker.isGuestMode ? Color.orange : Color.red)
            .cornerRadius(25)
            
            Button("DELETE ACCOUNT") {
                showingDeleteConfirmation = true
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.red, lineWidth: 2)
            )
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingDeleteConfirmation) {
            DeleteAccountConfirmationView(
                password: $deletePassword,
                isDeleting: $isDeletingAccount,
                error: $deleteError,
                onDelete: {
                    deleteAccount()
                },
                onCancel: {
                    showingDeleteConfirmation = false
                    deletePassword = ""
                    deleteError = ""
                }
            )
        }
    }
    
    private func deleteAccount() {
        guard !deletePassword.isEmpty else {
            deleteError = "Please enter your password"
            return
        }
        
        isDeletingAccount = true
        deleteError = ""
        
        // Mock delete account - works immediately without network timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("✅ Mock delete account success")
            self.isDeletingAccount = false
            self.showingDeleteConfirmation = false
            self.deletePassword = ""
            self.deleteError = ""
            
            // Clear all local data
            self.authTracker.clearAllData()
            
            // Sign out
            self.authTracker.signOut()
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.gold)
                    .frame(width: 25)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.gray)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    ProfileView(authTracker: AuthenticationTracker.shared)
}

// MARK: - Delete Account Confirmation View

struct DeleteAccountConfirmationView: View {
    @Binding var password: String
    @Binding var isDeleting: Bool
    @Binding var error: String
    let onDelete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.black.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Warning icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    // Title
                    Text("DELETE ACCOUNT")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    // Warning message
                    Text("This action cannot be undone. All your data will be permanently deleted.")
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your password to confirm:")
                            .font(.body)
                            .foregroundColor(.white)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.black)
                            .background(Color.white)
                            .cornerRadius(8)
                            .accentColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    // Error message
                    if !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 15) {
                        Button(action: onDelete) {
                            HStack {
                                if isDeleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isDeleting ? "Deleting..." : "DELETE ACCOUNT")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(25)
                        }
                        .disabled(isDeleting || password.isEmpty)
                        
                        Button(action: onCancel) {
                            Text("Cancel")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.gray)
                                .cornerRadius(25)
                        }
                        .disabled(isDeleting)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
    }
}

// MARK: - Achievements View

struct AchievementsView: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: AchievementCategory? = nil
    
    var filteredAchievements: [Achievement] {
        if let category = selectedCategory {
            return achievements.filter { $0.category == category }
        }
        return achievements
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.black.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            CategoryFilterButton(
                                title: "All",
                                isSelected: selectedCategory == nil
                            ) {
                                selectedCategory = nil
                            }
                            
                            ForEach(AchievementCategory.allCases, id: \.self) { category in
                                CategoryFilterButton(
                                    title: category.rawValue,
                                    isSelected: selectedCategory == category,
                                    color: category.color
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 10)
                    
                    // Achievements grid
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                            ForEach(filteredAchievements) { achievement in
                                DetailedAchievementCard(achievement: achievement)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.gold)
                }
            }
        }
    }
}

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    init(title: String, isSelected: Bool, color: Color = .gray, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(isSelected ? color : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(isSelected ? color : Color.gray.opacity(0.5), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DetailedAchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon and status
            ZStack {
                Circle()
                    .fill(achievement.category.color.opacity(achievement.isUnlocked ? 0.3 : 0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.icon)
                    .font(.title)
                    .foregroundColor(achievement.isUnlocked ? achievement.category.color : .gray)
                
                if achievement.isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                        .offset(x: 20, y: -20)
                }
            }
            
            // Title and description
            VStack(spacing: 4) {
                Text(achievement.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(achievement.description)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Progress bar for locked achievements
            if !achievement.isUnlocked {
                VStack(spacing: 4) {
                    ProgressView(value: achievement.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: achievement.category.color))
                        .scaleEffect(y: 2)
                    
                    Text("\(achievement.current)/\(achievement.target)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // Unlock date for unlocked achievements
            if achievement.isUnlocked, let unlockDate = achievement.unlockedDate {
                Text("Unlocked \(unlockDate, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(achievement.category.color.opacity(achievement.isUnlocked ? 0.5 : 0.2), lineWidth: 1)
        )
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
} 