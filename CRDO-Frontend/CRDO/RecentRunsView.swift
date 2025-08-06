//
//  RecentRunsView.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Recent runs view
//

import SwiftUI
import CoreLocation
import MapKit

struct RecentRunsView: View {
    @ObservedObject var runManager: RunManager
    @ObservedObject var preferencesManager = UserPreferencesManager.shared
    @State private var selectedRun: RunSession?
    @State private var showingRouteDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient.backgroundGradient
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
                                    .onTapGesture {
                                        print("🎯 Tapped on run: \(run.id)")
                                        selectedRun = run
                                        showingRouteDetail = true
                                    }
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
            .sheet(isPresented: $showingRouteDetail) {
                if let run = selectedRun {
                    RouteDetailView(run: run, unitSystem: preferencesManager.preferences.unitSystem)
                        .onDisappear {
                            selectedRun = nil
                        }
                }
            }
            .onChange(of: showingRouteDetail) { isPresented in
                if !isPresented {
                    selectedRun = nil
                }
            }
        }
        .onAppear {
            // UserPreferencesManager automatically loads preferences on init
            // Force refresh of preferences
            preferencesManager.objectWillChange.send()
        }
    }
}

struct RouteDetailView: View {
    let run: RunSession
    let unitSystem: UnitSystem
    @Environment(\.dismiss) private var dismiss
    @State private var animationProgress: CGFloat = 0.0
    @State private var region: MKCoordinateRegion

    
    init(run: RunSession, unitSystem: UnitSystem) {
        self.run = run
        self.unitSystem = unitSystem
        
        // Calculate the region to show the entire route
        let coordinates = run.route
        if coordinates.isEmpty {
            // Default region if no coordinates
            self._region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            let minLat = coordinates.map { $0.latitude }.min() ?? 0
            let maxLat = coordinates.map { $0.latitude }.max() ?? 0
            let minLon = coordinates.map { $0.longitude }.min() ?? 0
            let maxLon = coordinates.map { $0.longitude }.max() ?? 0
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.2, 0.001), // Add 20% padding, minimum 0.001
                longitudeDelta: max((maxLon - minLon) * 1.2, 0.001)
            )
            
            self._region = State(initialValue: MKCoordinateRegion(center: center, span: span))
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Route Details")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.gold)
                }
                .padding()
                
                // Map with route overlay (like active run view)
                ZStack {
                    Map(position: .constant(MapCameraPosition.region(region))) {
                        // Show the completed route as a blue line
                        if !run.route.isEmpty {
                            MapPolyline(coordinates: run.route)
                                .stroke(.blue, lineWidth: 6)
                        }
                    }
                    .cornerRadius(12)
                    .padding()
                    
                    // Stats overlay (like active run view)
                    VStack {
                        Spacer()
                        
                        // Run stats cards
                        VStack(spacing: 12) {
                            // Distance and Duration
                            HStack(spacing: 12) {
                                StatCard(
                                    title: "Distance",
                                    value: UnitConverter.formatDistance(run.distance, unitSystem: unitSystem),
                                    subtitle: unitSystem == .imperial ? "miles" : "km",
                                    color: .blue
                                )
                                
                                StatCard(
                                    title: "Duration",
                                    value: UnitConverter.formatDuration(run.duration),
                                    subtitle: "time",
                                    color: .green
                                )
                            }
                            
                            // Pace and Speed
                            HStack(spacing: 12) {
                                StatCard(
                                    title: "Pace",
                                    value: UnitConverter.formatPace(run.averagePace, unitSystem: unitSystem),
                                    subtitle: unitSystem == .imperial ? "min/mi" : "min/km",
                                    color: .orange
                                )
                                
                                StatCard(
                                    title: "Speed",
                                    value: UnitConverter.formatSpeed(run.averagePace > 0 ? 60 / run.averagePace : 0, unitSystem: unitSystem),
                                    subtitle: unitSystem == .imperial ? "mph" : "km/h",
                                    color: .red
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                .frame(height: 400)
                
                // Additional details
                VStack(spacing: 16) {
                    // Header with date and gems
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
                        
                        // Gems earned
                        HStack(spacing: 4) {
                            Image(systemName: "diamond.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            
                            let gemsEarned = GemsManager.shared.calculateGemsForRun(
                                distance: run.distance,
                                averageSpeed: run.averagePace > 0 ? 60 / run.averagePace : 0
                            )
                            Text("+\(gemsEarned)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    // Route info
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(run.route.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                            
                            Text("GPS Points")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", run.averagePace > 0 ? 60 / run.averagePace : 0))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                            
                            Text("Avg Speed")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            print("🗺️ RouteDetailView appeared for run: \(run.id)")
            // Start animation for route line
            withAnimation(.easeInOut(duration: 2.0)) {
                animationProgress = 1.0
            }
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