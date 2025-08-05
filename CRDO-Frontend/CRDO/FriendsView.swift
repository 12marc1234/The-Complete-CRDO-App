//
//  FriendsView.swift
//  CRDO
//
//  Created by Ethan Yip on 7/25/25.
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
                    // Tab selector
                    Picker("View", selection: $selectedTab) {
                        Text("Friends").tag(0)
                        Text("Leaderboards").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if selectedTab == 0 {
                        FriendsTabView(
                            friends: friends,
                            unitSystem: preferencesManager.preferences.unitSystem,
                            showingFriendRequests: $showingFriendRequests
                        )
                    } else {
                        LeaderboardsTabView(
                            leaderboardData: leaderboardData,
                            selectedTimeframe: $selectedTimeframe,
                            unitSystem: preferencesManager.preferences.unitSystem
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
        }
        .onAppear {
            generateMockData()
        }
    }
    
    private func generateMockData() {
        // Generate mock friends
        friends = [
            MockFriend(
                name: "Sarah Johnson",
                email: "sarah@example.com",
                avatar: "person.circle.fill",
                status: .online,
                lastActive: Date(),
                totalRuns: 45,
                totalDistance: 125000,
                averagePace: 280
            ),
            MockFriend(
                name: "Mike Chen",
                email: "mike@example.com",
                avatar: "person.circle.fill",
                status: .running,
                lastActive: Date().addingTimeInterval(-1800),
                totalRuns: 32,
                totalDistance: 89000,
                averagePace: 320
            ),
            MockFriend(
                name: "Emma Davis",
                email: "emma@example.com",
                avatar: "person.circle.fill",
                status: .offline,
                lastActive: Date().addingTimeInterval(-7200),
                totalRuns: 28,
                totalDistance: 67000,
                averagePace: 350
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
    @State private var friendRequests: [MockFriend] = [
        MockFriend(
            name: "John Smith",
            email: "john@example.com",
            avatar: "person.circle.fill",
            status: .online,
            lastActive: Date(),
            totalRuns: 15,
            totalDistance: 45000,
            averagePace: 300
        ),
        MockFriend(
            name: "Lisa Brown",
            email: "lisa@example.com",
            avatar: "person.circle.fill",
            status: .offline,
            lastActive: Date().addingTimeInterval(-3600),
            totalRuns: 22,
            totalDistance: 67000,
            averagePace: 280
        )
    ]
    @State private var currentFriends: [MockFriend]
    
    init(friends: [MockFriend], unitSystem: UnitSystem, showingFriendRequests: Binding<Bool>) {
        self.friends = friends
        self.unitSystem = unitSystem
        self._showingFriendRequests = showingFriendRequests
        self._currentFriends = State(initialValue: friends)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Friend requests section
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
                }
                
                // Friends list
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Friends")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    LazyVStack(spacing: 10) {
                        ForEach(currentFriends) { friend in
                            FriendCard(friend: friend, unitSystem: unitSystem)
                        }
                    }
                    .padding(.horizontal)
                }
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
    
    var body: some View {
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
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
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
    
    private let timeframes = ["This Week", "This Month", "All Time"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Timeframe selector
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(0..<timeframes.count, id: \.self) { index in
                    Text(timeframes[index]).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Leaderboard
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(leaderboardData) { entry in
                        LeaderboardCard(entry: entry, unitSystem: unitSystem)
                    }
                }
                .padding()
            }
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