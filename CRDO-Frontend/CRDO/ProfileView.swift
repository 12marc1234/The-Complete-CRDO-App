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
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.black.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Profile header with fade-in animation
                        ProfileHeaderSection(
                            authTracker: authTracker,
                            userBio: $userBio,
                            isEditingBio: $isEditingBio,
                            scrollOffset: scrollOffset
                        )
                        .opacity(max(0.3, 1.0 - scrollOffset / 200))
                        .scaleEffect(max(0.8, 1.0 - scrollOffset / 400))
                        
                        // Stats summary with fade-in
                        StatsSection(scrollOffset: scrollOffset)
                            .opacity(max(0.3, 1.0 - scrollOffset / 300))
                        
                        // Gems section with fade-in
                        ProfileGemsSection(gemsManager: gemsManager, scrollOffset: scrollOffset)
                            .opacity(max(0.3, 1.0 - scrollOffset / 250))
                        
                        // Achievements section with fade-in
                        AchievementsSection(
                            achievements: achievementManager.achievements,
                            showingAchievements: $showingAchievements,
                            scrollOffset: scrollOffset,
                            isLoading: false
                        )
                        .opacity(max(0.3, 1.0 - scrollOffset / 200))
                        
                        // Settings with fade-in
                        SettingsSection(
                            preferencesManager: preferencesManager,
                            scrollOffset: scrollOffset
                        )
                        .opacity(max(0.3, 1.0 - scrollOffset / 150))
                        
                        // Actions with fade-in
                        ActionsSection(authTracker: authTracker, scrollOffset: scrollOffset)
                            .opacity(max(0.3, 1.0 - scrollOffset / 100))
                        
                        Spacer()
                    }
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
                Text(authTracker.currentUser?.fullName ?? authTracker.currentUser?.firstName != nil ? "\(authTracker.currentUser?.firstName ?? "") \(authTracker.currentUser?.lastName ?? "")" : "User")
                    .font(.title2)
                    .fontWeight(.semibold)
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

struct StatsSection: View {
    let scrollOffset: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Your Stats")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                StatCard(
                    title: "Total Runs",
                    value: "24",
                    subtitle: "This month",
                    color: .blue
                )
                
                StatCard(
                    title: "Total Distance",
                    value: "156.2 mi",
                    subtitle: "Lifetime",
                    color: .green
                )
                
                StatCard(
                    title: "Average Pace",
                    value: "8:30",
                    subtitle: "This month",
                    color: .orange
                )
                
                StatCard(
                    title: "Best Time",
                    value: "1:23:45",
                    subtitle: "10K race",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Gems Section

struct ProfileGemsSection: View {
    @ObservedObject var gemsManager: GemsManager
    let scrollOffset: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Gems")
                .font(.headline)
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
                    .font(.title2)
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
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "ruler",
                    title: "Units",
                    value: preferencesManager.preferences.unitSystem == .imperial ? "Imperial" : "Metric"
                ) {
                    preferencesManager.preferences.unitSystem = preferencesManager.preferences.unitSystem == .imperial ? .metric : .imperial
                }
                
                SettingsRow(
                    icon: "speedometer",
                    title: "Show Speed",
                    value: preferencesManager.preferences.showSpeed ? "On" : "Off"
                ) {
                    preferencesManager.preferences.showSpeed.toggle()
                }
                
                SettingsRow(
                    icon: "pause.circle",
                    title: "Auto Pause",
                    value: preferencesManager.preferences.autoPause ? "On" : "Off"
                ) {
                    preferencesManager.preferences.autoPause.toggle()
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
    
    var body: some View {
        VStack(spacing: 15) {
            Button("Sign Out") {
                authTracker.signOut()
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.red)
            .cornerRadius(25)
        }
        .padding(.horizontal)
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