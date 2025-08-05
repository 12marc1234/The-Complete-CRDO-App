//
//  RecentRunsView.swift
//  CRDO
//
//  Created by Ethan Yip on 7/25/25.
//  Recent runs view
//

import SwiftUI
import CoreLocation

struct RecentRunsView: View {
    @ObservedObject var runManager: RunManager
    @ObservedObject var preferencesManager = UserPreferencesManager.shared
    
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
                
                if runManager.recentRuns.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Recent Runs")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Your completed runs will appear here")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(runManager.recentRuns) { run in
                                RunCard(run: run, unitSystem: preferencesManager.preferences.unitSystem)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Recent Runs")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear All") {
                        runManager.recentRuns.removeAll()
                    }
                    .foregroundColor(.gold)
                }
            }
        }
        .onAppear {
            // UserPreferencesManager automatically loads preferences on init
        }
    }
}

struct RunCard: View {
    let run: RunSession
    let unitSystem: UnitSystem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.startTime, style: .date)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(run.startTime, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Route preview
                if !run.route.isEmpty {
                    RoutePreview(coordinates: run.route)
                        .frame(width: 60, height: 40)
                        .cornerRadius(8)
                }
            }
            
            // Stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                StatItem(
                    title: "Distance",
                    value: UnitConverter.formatDistance(run.distance, unitSystem: unitSystem),
                    color: .blue
                )
                
                StatItem(
                    title: "Duration",
                    value: UnitConverter.formatDuration(run.duration),
                    color: .green
                )
                
                StatItem(
                    title: "Pace",
                    value: UnitConverter.formatPace(run.averagePace, unitSystem: unitSystem),
                    color: .orange
                )
            }
            
            // Gems earned
            HStack {
                Image(systemName: "diamond.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                
                let gemsEarned = GemsManager.shared.calculateGemsForRun(
                    distance: run.distance,
                    averageSpeed: run.averagePace > 0 ? 60 / run.averagePace : 0 // Convert pace to speed
                )
                Text("+\(gemsEarned) gems")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
                
                Spacer()
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

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

struct RoutePreview: View {
    let coordinates: [CLLocationCoordinate2D]
    
    var body: some View {
        Canvas { context, size in
            if coordinates.count > 1 {
                var path = Path()
                let points = coordinates.map { coordinate in
                    CGPoint(
                        x: CGFloat(coordinate.longitude) * size.width,
                        y: CGFloat(coordinate.latitude) * size.height
                    )
                }
                
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
                
                context.stroke(path, with: .color(.blue), lineWidth: 2)
            }
        }
        .background(Color(.systemGray5))
    }
}

#Preview {
    RecentRunsView(runManager: RunManager())
} 