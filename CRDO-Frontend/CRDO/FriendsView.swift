//
//  FriendsView.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Friends and leaderboards view
//

import SwiftUI

struct FriendsView: View {
    @State private var selectedTab = 0
    @ObservedObject var preferencesManager = UserPreferencesManager.shared
    @State private var friends: [MockFriend] = []
    @State private var leaderboardData: [MockLeaderboardEntry] = []
    @State private var selectedTimeframe = 0
    @State private var showingFriendRequests = false
    @State private var selectedFriend: MockFriend?
    @State private var showingProfile = false
    @State private var scrollOffset: CGFloat = 0
    
    private let timeframes = ["This Week", "This Month", "All Time"]
    
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
                    // Custom tab selector with better visibility
                    HStack(spacing: 0) {
                        // Friends Tab
                        Button(action: { selectedTab = 0 }) {
                            Text("Friends")
                                .font(.system(size: 14, weight: selectedTab == 0 ? .semibold : .medium))
                                .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    selectedTab == 0 ? 
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.2)) :
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Leaderboards Tab
                        Button(action: { selectedTab = 1 }) {
                            Text("Leaderboards")
                                .font(.system(size: 14, weight: selectedTab == 1 ? .semibold : .medium))
                                .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    selectedTab == 1 ? 
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.2)) :
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                    
                    if selectedTab == 0 {
                        FriendsTabView(
                            friends: friends,
                            unitSystem: preferencesManager.preferences.unitSystem,
                            showingFriendRequests: $showingFriendRequests,
                            selectedFriend: $selectedFriend,
                            showingProfile: $showingProfile,
                            scrollOffset: scrollOffset
                        )
                    } else {
                        LeaderboardsTabView(
                            leaderboardData: leaderboardData,
                            selectedTimeframe: $selectedTimeframe,
                            unitSystem: preferencesManager.preferences.unitSystem,
                            scrollOffset: scrollOffset
                        )
                    }
                }
            }
            .navigationTitle(selectedTab == 0 ? "Friends" : "Leaderboards")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Friend") {
                        // Add friend functionality
                    }
                    .foregroundColor(.gold)
                }
            }
            .sheet(isPresented: $showingProfile) {
                if let friend = selectedFriend {
                    FriendProfileView(friend: friend, unitSystem: preferencesManager.preferences.unitSystem)
                }
            }
        }
        .onAppear {
            generateMockData()
        }
    }
    
    private func generateMockData() {
        // Generate mock friends with bios
        friends = [
            MockFriend(
                name: "Sarah Johnson",
                email: "sarah@example.com",
                avatar: "person.circle.fill",
                status: .online,
                lastActive: Date(),
                totalRuns: 45,
                totalDistance: 125000,
                averagePace: 280,
                bio: "Marathon runner and fitness enthusiast. Love exploring new trails!"
            ),
            MockFriend(
                name: "Mike Chen",
                email: "mike@example.com",
                avatar: "person.circle.fill",
                status: .running,
                lastActive: Date().addingTimeInterval(-1800),
                totalRuns: 32,
                totalDistance: 89000,
                averagePace: 320,
                bio: "Sprint specialist focusing on speed training and interval workouts."
            ),
            MockFriend(
                name: "Emma Davis",
                email: "emma@example.com",
                avatar: "person.circle.fill",
                status: .offline,
                lastActive: Date().addingTimeInterval(-7200),
                totalRuns: 28,
                totalDistance: 67000,
                averagePace: 350,
                bio: "Casual runner who enjoys morning jogs and weekend long runs."
            )
        ]
        
        // Generate mock leaderboard data
        leaderboardData = [
            MockLeaderboardEntry(
                rank: 1,
                name: "Alex Thompson",
                distance: 156000,
                duration: 7200,
                averagePace: 250,
                totalRuns: 52,
                points: 1250
            ),
            MockLeaderboardEntry(
                rank: 2,
                name: "Sarah Johnson",
                distance: 125000,
                duration: 6000,
                averagePace: 280,
                totalRuns: 45,
                points: 1100
            ),
            MockLeaderboardEntry(
                rank: 3,
                name: "Mike Chen",
                distance: 89000,
                duration: 4800,
                averagePace: 320,
                totalRuns: 32,
                points: 950
            ),
            MockLeaderboardEntry(
                rank: 4,
                name: "Emma Davis",
                distance: 67000,
                duration: 3600,
                averagePace: 350,
                totalRuns: 28,
                points: 800
            ),
            MockLeaderboardEntry(
                rank: 5,
                name: "David Wilson",
                distance: 54000,
                duration: 3000,
                averagePace: 380,
                totalRuns: 22,
                points: 650
            )
        ]
    }
}

struct FriendsTabView: View {
    let friends: [MockFriend]
    let unitSystem: UnitSystem
    @Binding var showingFriendRequests: Bool
    @Binding var selectedFriend: MockFriend?
    @Binding var showingProfile: Bool
    let scrollOffset: CGFloat
    @State private var friendRequests: [MockFriend] = [
        MockFriend(
            name: "John Smith",
            email: "john@example.com",
            avatar: "person.circle.fill",
            status: .online,
            lastActive: Date(),
            totalRuns: 15,
            totalDistance: 45000,
            averagePace: 300,
            bio: "New to running, excited to join the community!"
        ),
        MockFriend(
            name: "Lisa Brown",
            email: "lisa@example.com",
            avatar: "person.circle.fill",
            status: .offline,
            lastActive: Date().addingTimeInterval(-3600),
            totalRuns: 22,
            totalDistance: 67000,
            averagePace: 280,
            bio: "Trail runner and nature lover. Always up for a challenge!"
        )
    ]
    @State private var currentFriends: [MockFriend]
    
    init(friends: [MockFriend], unitSystem: UnitSystem, showingFriendRequests: Binding<Bool>, selectedFriend: Binding<MockFriend?>, showingProfile: Binding<Bool>, scrollOffset: CGFloat) {
        self.friends = friends
        self.unitSystem = unitSystem
        self._showingFriendRequests = showingFriendRequests
        self._selectedFriend = selectedFriend
        self._showingProfile = showingProfile
        self.scrollOffset = scrollOffset
        self._currentFriends = State(initialValue: friends)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Friend requests section with fade-in
                if !friendRequests.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Friend Requests")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button("View All") {
                                showingFriendRequests = true
                            }
                            .foregroundColor(.gold)
                        }
                        
                        // Friend requests
                        VStack(spacing: 10) {
                            ForEach(friendRequests) { request in
                                FriendRequestCard(
                                    name: request.name,
                                    mutualFriends: Int.random(in: 1...5),
                                    onAccept: {
                                        acceptFriendRequest(request)
                                    },
                                    onDecline: {
                                        declineFriendRequest(request)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .opacity(max(0.5, 1.0 - scrollOffset / 300)) // Improved readability
                }
                
                // Friends list with fade-in
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Friends")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 10) {
                        ForEach(currentFriends) { friend in
                            FriendCard(
                                friend: friend,
                                unitSystem: unitSystem,
                                onTap: {
                                    selectedFriend = friend
                                    showingProfile = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .opacity(max(0.5, 1.0 - scrollOffset / 250)) // Improved readability
            }
        }
    }
    
    private func acceptFriendRequest(_ request: MockFriend) {
        withAnimation(.easeInOut(duration: 0.3)) {
            friendRequests.removeAll { $0.id == request.id }
            currentFriends.append(request)
        }
    }
    
    private func declineFriendRequest(_ request: MockFriend) {
        withAnimation(.easeInOut(duration: 0.3)) {
            friendRequests.removeAll { $0.id == request.id }
        }
    }
}

struct FriendRequestCard: View {
    let name: String
    let mutualFriends: Int
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var isAccepted = false
    @State private var isDeclined = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(mutualFriends) mutual friends")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            if !isAccepted && !isDeclined {
                HStack(spacing: 10) {
                    Button("Accept") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isAccepted = true
                        }
                        onAccept()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 35)
                    .background(Color.green)
                    .cornerRadius(8)
                    
                    Button("Decline") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isDeclined = true
                        }
                        onDecline()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 35)
                    .background(Color.red)
                    .cornerRadius(8)
                }
            } else {
                HStack {
                    Image(systemName: isAccepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isAccepted ? .green : .red)
                    Text(isAccepted ? "Accepted" : "Declined")
                        .foregroundColor(isAccepted ? .green : .red)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 35)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct FriendCard: View {
    let friend: MockFriend
    let unitSystem: UnitSystem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: friend.avatar)
                        .font(.title2)
                        .foregroundColor(statusColor)
                }
                
                // Friend info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(friend.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text("\(friend.totalRuns) runs • \(UnitConverter.formatDistance(friend.totalDistance, unitSystem: unitSystem))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("Last active: \(friend.lastActive, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Quick stats
                VStack(alignment: .trailing, spacing: 4) {
                    Text(UnitConverter.formatPace(friend.averagePace, unitSystem: unitSystem))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    Text("avg pace")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var statusColor: Color {
        switch friend.status {
        case .online:
            return .green
        case .running:
            return .blue
        case .offline:
            return .gray
        }
    }
}

struct LeaderboardsTabView: View {
    let leaderboardData: [MockLeaderboardEntry]
    @Binding var selectedTimeframe: Int
    let unitSystem: UnitSystem
    let scrollOffset: CGFloat
    
    private let timeframes = ["This Week", "This Month", "All Time"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom timeframe selector with better visibility
            HStack(spacing: 8) {
                ForEach(0..<timeframes.count, id: \.self) { index in
                    Button(action: { selectedTimeframe = index }) {
                        Text(timeframes[index])
                            .font(.system(size: 12, weight: selectedTimeframe == index ? .semibold : .medium))
                            .foregroundColor(selectedTimeframe == index ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedTimeframe == index ? 
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.2)) :
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.clear)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 12)
            
            // Leaderboard with fade-in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(leaderboardData) { entry in
                        LeaderboardCard(entry: entry, unitSystem: unitSystem)
                    }
                }
                .padding()
            }
            .opacity(max(0.5, 1.0 - scrollOffset / 250)) // Improved readability
        }
    }
}

struct LeaderboardCard: View {
    let entry: MockLeaderboardEntry
    let unitSystem: UnitSystem
    
    var body: some View {
        HStack(spacing: 15) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 40, height: 40)
                
                Text("\(entry.rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Runner info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(entry.totalRuns) runs • \(UnitConverter.formatDistance(entry.distance, unitSystem: unitSystem))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text(UnitConverter.formatPace(entry.averagePace, unitSystem: unitSystem))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                Text("\(entry.points) pts")
                    .font(.caption2)
                    .foregroundColor(.gold)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1:
            return .yellow
        case 2:
            return Color(.systemGray4)
        case 3:
            return Color(.systemOrange)
        default:
            return .blue
        }
    }
}

#Preview {
    FriendsView()
}

// MARK: - Helper Functions

func formatRelativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

// MARK: - Friend Profile View

struct FriendProfileView: View {
    let friend: MockFriend
    let unitSystem: UnitSystem
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var achievements: [Achievement] = []
    @State private var cityBuildings: [Building] = []
    
    var body: some View {
        NavigationView {
            FriendProfileContentView(
                friend: friend,
                unitSystem: unitSystem,
                statusColor: statusColor,
                achievements: achievements,
                cityBuildings: cityBuildings,
                dismiss: dismiss
            )
            .onAppear {
                loadMockData()
            }
        }
    }
    
    private var statusColor: Color {
        switch friend.status {
        case .online:
            return .green
        case .running:
            return .blue
        case .offline:
            return .gray
        }
    }
}

struct RecentActivityCard: View {
    let title: String
    let distance: Double
    let duration: TimeInterval
    let date: Date
    let unitSystem: UnitSystem
    
    var body: some View {
        HStack(spacing: 15) {
            // Activity icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "figure.run")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            
            // Activity info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(UnitConverter.formatDistance(distance, unitSystem: unitSystem)) • \(UnitConverter.formatDuration(duration))")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Pace
            VStack(alignment: .trailing, spacing: 4) {
                Text(UnitConverter.formatPace(duration / (distance / 1000), unitSystem: unitSystem))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                Text("pace")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Friend Profile Content View

struct FriendProfileContentView: View {
    let friend: MockFriend
    let unitSystem: UnitSystem
    let statusColor: Color
    let achievements: [Achievement]
    let cityBuildings: [Building]
    let dismiss: DismissAction
    
    var body: some View {
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
                    // Profile header
                    ProfileHeaderView(friend: friend, statusColor: statusColor)
                        .padding(.top, 20)
                    
                    // Stats summary
                    StatsSectionView(friend: friend, unitSystem: unitSystem)
                    
                    // Recent activity
                    RecentActivitySectionView(unitSystem: unitSystem)
                    
                    // Achievements section
                    AchievementsSectionView(achievements: achievements)
                    
                    // City section
                    CitySectionView(cityBuildings: cityBuildings)
                    
                    Spacer()
                }
            }
        }
        .navigationTitle("Profile")
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

// MARK: - Stats Section View

struct StatsSectionView: View {
    let friend: MockFriend
    let unitSystem: UnitSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Stats")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                StatCard(
                    title: "Total Runs",
                    value: "\(friend.totalRuns)",
                    subtitle: "Lifetime",
                    color: .blue
                )
                
                StatCard(
                    title: "Total Distance",
                    value: UnitConverter.formatDistance(friend.totalDistance, unitSystem: unitSystem),
                    subtitle: "Lifetime",
                    color: .green
                )
                
                StatCard(
                    title: "Average Pace",
                    value: UnitConverter.formatPace(friend.averagePace, unitSystem: unitSystem),
                    subtitle: "Lifetime",
                    color: .orange
                )
                
                StatCard(
                    title: "Last Active",
                    value: friend.lastActive.timeIntervalSinceNow > -3600 ? "Now" : formatRelativeDate(friend.lastActive),
                    subtitle: "Status",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Recent Activity Section View

struct RecentActivitySectionView: View {
    let unitSystem: UnitSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 10) {
                ForEach(1...3, id: \.self) { index in
                    RecentActivityCard(
                        title: "Morning Run",
                        distance: Double.random(in: 3000...8000),
                        duration: TimeInterval.random(in: 1200...3600),
                        date: Date().addingTimeInterval(-Double(index) * 86400),
                        unitSystem: unitSystem
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Achievements Section View

struct AchievementsSectionView: View {
    let achievements: [Achievement]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View All") {
                    // TODO: Navigate to full achievements view
                }
                .foregroundColor(.gold)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                ForEach(achievements) { achievement in
                    AchievementCard(achievement: achievement)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - City Section View

struct CitySectionView: View {
    let cityBuildings: [Building]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("City")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View Full City") {
                    // TODO: Navigate to full city view
                }
                .foregroundColor(.gold)
            }
            .padding(.horizontal)
            
            // Mini city grid view
            ZStack {
                // Background grid
                VStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(0..<6, id: \.self) { col in
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                // Buildings overlay
                ForEach(cityBuildings) { building in
                    let gridX = Int(building.position.x / 50) % 6
                    let gridY = Int(building.position.y / 50) % 6
                    
                    Image(building.type.realisticIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 35, height: 35)
                        .offset(x: CGFloat(gridX * 48 - 120), y: CGFloat(gridY * 48 - 120))
                }
            }
            .frame(height: 300)
            .padding(.horizontal)
        }
    }
}

// MARK: - Profile Header View

struct ProfileHeaderView: View {
    let friend: MockFriend
    let statusColor: Color
    
    var body: some View {
        VStack(spacing: 20) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.gold.opacity(0.3))
                    .frame(width: 100, height: 100)
                
                Image(systemName: friend.avatar)
                    .font(.system(size: 50))
                    .foregroundColor(.gold)
            }
            
            // Friend info
            VStack(spacing: 8) {
                HStack {
                    Text(friend.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                }
                
                Text(friend.bio)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Friend Profile Helper Methods

extension FriendProfileView {
    private func loadMockData() {
        // Load mock achievements
        achievements = [
            Achievement(
                title: "First Run",
                description: "Complete your first run",
                icon: "figure.run",
                category: .distance,
                isUnlocked: true,
                unlockedDate: Date().addingTimeInterval(-86400 * 7),
                progress: 1.0,
                target: 1,
                current: 1
            ),
            Achievement(
                title: "5K Runner",
                description: "Complete a 5K run",
                icon: "figure.run",
                category: .distance,
                isUnlocked: true,
                unlockedDate: Date().addingTimeInterval(-86400 * 5),
                progress: 1.0,
                target: 1,
                current: 1
            ),
            Achievement(
                title: "Speed Demon",
                description: "Run at 8+ mph for 1 mile",
                icon: "speedometer",
                category: .speed,
                isUnlocked: true,
                unlockedDate: Date().addingTimeInterval(-86400 * 3),
                progress: 1.0,
                target: 1,
                current: 1
            ),
            Achievement(
                title: "Consistency",
                description: "Run 3 days in a row",
                icon: "calendar",
                category: .consistency,
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.67,
                target: 3,
                current: 2
            )
        ]
        
        // Load mock city buildings
        cityBuildings = [
            Building(type: .house, position: CGPoint(x: 100, y: 100)),
            Building(type: .park, position: CGPoint(x: 200, y: 150)),
            Building(type: .office, position: CGPoint(x: 150, y: 200)),
            Building(type: .mall, position: CGPoint(x: 250, y: 100))
        ]
    }
}

 