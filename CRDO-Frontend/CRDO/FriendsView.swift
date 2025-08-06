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
    @State private var showingAddFriend = false
    @State private var friendRequests: [MockFriend] = []
    
    private let timeframes = ["This Week", "This Month", "All Time"]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Enhanced background
                LinearGradient.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Enhanced tab selector with modern design
                    HStack(spacing: 0) {
                        // Friends Tab
                        Button(action: { selectedTab = 0 }) {
                            Text("Friends")
                                .font(.system(size: 16, weight: selectedTab == 0 ? .semibold : .medium))
                                .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    selectedTab == 0 ? 
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.15)) :
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedTab == 0 ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Leaderboards Tab
                        Button(action: { selectedTab = 1 }) {
                            Text("Leaderboards")
                                .font(.system(size: 16, weight: selectedTab == 1 ? .semibold : .medium))
                                .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    selectedTab == 1 ? 
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.15)) :
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedTab == 1 ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    
                    if selectedTab == 0 {
                        FriendsTabView(
                            friends: friends,
                            friendRequests: friendRequests,
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
                        showingAddFriend = true
                    }
                    .foregroundColor(.gold)
                }
            }
            .sheet(isPresented: $showingProfile) {
                if let friend = selectedFriend {
                    FriendProfileView(friend: friend, unitSystem: preferencesManager.preferences.unitSystem)
                        .onDisappear {
                            selectedFriend = nil
                        }
                }
            }
            .onChange(of: showingProfile) { isPresented in
                if !isPresented {
                    selectedFriend = nil
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView()
            }
            .sheet(isPresented: $showingFriendRequests) {
                FriendRequestsView(friendRequests: friendRequests) { request in
                    acceptFriendRequest(request)
                } onDecline: { request in
                    declineFriendRequest(request)
                }
            }
        }
        .onAppear {
            generateMockData()
            generateMockFriendRequests()
        }
    }
    
    private func generateMockFriendRequests() {
        friendRequests = [
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
    }
    
    private func acceptFriendRequest(_ request: MockFriend) {
        withAnimation(.easeInOut(duration: 0.3)) {
            friendRequests.removeAll { $0.id == request.id }
            friends.append(request)
        }
    }
    
    private func declineFriendRequest(_ request: MockFriend) {
        withAnimation(.easeInOut(duration: 0.3)) {
            friendRequests.removeAll { $0.id == request.id }
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
    let friendRequests: [MockFriend]
    let unitSystem: UnitSystem
    @Binding var showingFriendRequests: Bool
    @Binding var selectedFriend: MockFriend?
    @Binding var showingProfile: Bool
    let scrollOffset: CGFloat
    @State private var currentFriends: [MockFriend]
    
    init(friends: [MockFriend], friendRequests: [MockFriend], unitSystem: UnitSystem, showingFriendRequests: Binding<Bool>, selectedFriend: Binding<MockFriend?>, showingProfile: Binding<Bool>, scrollOffset: CGFloat) {
        self.friends = friends
        self.friendRequests = friendRequests
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
                                        // This will be handled by the parent view
                                    },
                                    onDecline: {
                                        // This will be handled by the parent view
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
                                    print("👥 Tapped on friend: \(friend.name)")
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

// MARK: - Add Friend View

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isSearching = false
    @State private var searchResults: [MockFriend] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Add Friend")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 15) {
                        TextField("Enter friend's email", text: $email)
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button("Search") {
                            searchFriend()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(email.isEmpty)
                    }
                    .padding(.horizontal)
                    
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if !searchResults.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults) { friend in
                                    SearchResultCard(friend: friend) {
                                        sendFriendRequest(to: friend)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .alert("Friend Request", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func searchFriend() {
        guard !email.isEmpty else { return }
        
        isSearching = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSearching = false
            
            // Mock search results
            searchResults = [
                MockFriend(
                    name: "John Doe",
                    email: email,
                    avatar: "person.circle.fill",
                    status: .online,
                    lastActive: Date(),
                    totalRuns: 25,
                    totalDistance: 75000,
                    averagePace: 290,
                    bio: "Fitness enthusiast and running buddy!"
                )
            ]
        }
    }
    
    private func sendFriendRequest(to friend: MockFriend) {
        // Simulate sending friend request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            alertMessage = "Friend request sent to \(friend.name)!"
            showingAlert = true
            
            // Dismiss after showing alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }
}

struct SearchResultCard: View {
    let friend: MockFriend
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: friend.avatar)
                .font(.title2)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(friend.email)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button("Add") {
                onAdd()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Friend Requests View

struct FriendRequestsView: View {
    let friendRequests: [MockFriend]
    let onAccept: (MockFriend) -> Void
    let onDecline: (MockFriend) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.backgroundGradient
                    .ignoresSafeArea()
                
                if friendRequests.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Friend Requests")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("You don't have any pending friend requests")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(friendRequests) { request in
                                FriendRequestDetailCard(
                                    friend: request,
                                    onAccept: {
                                        onAccept(request)
                                        if friendRequests.count == 1 {
                                            dismiss()
                                        }
                                    },
                                    onDecline: {
                                        onDecline(request)
                                        if friendRequests.count == 1 {
                                            dismiss()
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct FriendRequestDetailCard: View {
    let friend: MockFriend
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: friend.avatar)
                    .font(.title)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(friend.email)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            if !friend.bio.isEmpty {
                Text(friend.bio)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            HStack(spacing: 12) {
                Button("Accept") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Decline") {
                    onDecline()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - All Achievements View

struct AllAchievementsView: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.backgroundGradient
                    .ignoresSafeArea()
                
                if achievements.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "trophy")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Achievements")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("This user hasn't earned any achievements yet")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                            ForEach(achievements) { achievement in
                                AchievementCard(achievement: achievement)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("All Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
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
    @State private var showingAllAchievements = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View All") {
                    showingAllAchievements = true
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
        .sheet(isPresented: $showingAllAchievements) {
            AllAchievementsView(achievements: achievements)
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

 