//
//  RecentRunsView.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Recent runs view
//

import SwiftUI
import MapKit
import CoreLocation

struct RecentRunsView: View {
    @ObservedObject private var runManager = RunManager.shared
    @StateObject private var preferencesManager = UserPreferencesManager.shared
    @State private var selectedRun: RunSession?
    @State private var showingRouteDetail = false
    
    var body: some View {
        WorkoutHistoryView()
    }
}

struct WorkoutHistoryView: View {
    @ObservedObject private var workoutStore = WorkoutStore.shared
    @ObservedObject private var preferencesManager = UserPreferencesManager.shared
    @ObservedObject private var runManager = RunManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showClearConfirmation = false
    @State private var clearText = ""
    @State private var selectedWorkout: Workout? // Only this state is needed for sheet
    
    // Combine workouts from both sources
    private var allWorkouts: [Workout] {
        return workoutStore.workouts
    }
    
    var displayWorkouts: [Workout] {
        // Sort by start time (most recent first)
        return allWorkouts.sorted { $0.startTime > $1.startTime }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.gray.opacity(0.3), Color.black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Enhanced Header
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            showClearConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(15)
                        }
                    }
                    
                    // Workout History Title
                    Text("WORKOUT HISTORY")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Summary Stats
                    if !displayWorkouts.isEmpty {
                        HStack(spacing: 12) {
                            SummaryStatCard(
                                title: "TOTAL",
                                value: "\(displayWorkouts.count)",
                                icon: "figure.run",
                                color: .blue
                            )
                            SummaryStatCard(
                                title: "DISTANCE",
                                value: String(format: "%.1f mi", displayWorkouts.reduce(0) { $0 + $1.distance }),
                                icon: "location.fill",
                                color: .green
                            )
                            SummaryStatCard(
                                title: "TIME",
                                value: formatTotalTime(displayWorkouts.reduce(0) { $0 + $1.duration }),
                                icon: "clock.fill",
                                color: .orange
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Workouts List
                if displayWorkouts.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "figure.run")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("NO WORKOUTS YET")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("Complete your first workout to see it here")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(displayWorkouts) { workout in
                                ModernWorkoutCard(workout: workout, unitSystem: preferencesManager.preferences.unitSystem) {
                                    workoutStore.deleteWorkout(workout)
                                } onMapTap: {
                                    print("Map tapped for workout: \(workout.id)")
                                    selectedWorkout = workout // Only set selectedWorkout
                                }
                                .onTapGesture { // Made entire card tappable
                                    print("Workout card tapped for workout: \(workout.id)")
                                    selectedWorkout = workout
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedWorkout) { workout in
                SheetContentView(workout: workout)
            }
            .alert("Type 'clear' to confirm", isPresented: $showClearConfirmation, actions: {
                TextField("Type 'clear' to confirm", text: $clearText)
                Button("Confirm", role: .destructive) {
                    if clearText.lowercased() == "clear" {
                        workoutStore.clearAllWorkouts()
                    }
                    clearText = ""
                }
                Button("Cancel", role: .cancel) {
                    clearText = ""
                }
            }, message: {
                Text("This will delete all workout history. This action cannot be undone.")
            })
        }
        .onAppear {
            print("📱 WorkoutHistoryView appeared")
            print("📱 WorkoutStore workouts count: \(workoutStore.workouts.count)")
            // Force refresh of workout store
            DispatchQueue.main.async {
                workoutStore.objectWillChange.send()
            }
        }

    }
    
    private func formatTotalTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct SummaryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ModernWorkoutCard: View {
    let workout: Workout
    let unitSystem: UnitSystem
    let onDelete: () -> Void
    let onMapTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date and category
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(formatDate(workout.startTime))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Image(systemName: workout.category.icon)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                        Text(workout.category.rawValue)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .padding(10)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(25)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ModernStatRow(label: "AVG SPEED", value: UnitConverter.formatSpeed(workout.averageSpeed, unitSystem: unitSystem), icon: "speedometer")
                ModernStatRow(label: "PEAK SPEED", value: UnitConverter.formatSpeed(workout.peakSpeed, unitSystem: unitSystem), icon: "bolt.fill")
                ModernStatRow(label: "DISTANCE", value: UnitConverter.formatDistance(workout.distance * 1609.34, unitSystem: unitSystem), icon: "location.fill")
                ModernStatRow(label: "TIME", value: formatTime(workout.duration), icon: "clock.fill")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            
            // Route Preview
            if !workout.route.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("ROUTE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("TAP TO VIEW")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    
                    MapRoutePreview(route: workout.route)
                        .frame(height: 120)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .contentShape(Rectangle()) // Make the whole area tappable
                        .onTapGesture {
                            print("Map preview tapped!")
                            onMapTap()
                        }
                        .onAppear {
                            print("🗺️ ModernWorkoutCard showing route with \(workout.route.count) coordinates")
                        }
                }
                .padding(.bottom, 20)
            } else {
                // Debug: route is empty, so map preview is not shown
                Color.clear
                    .frame(height: 0)
                    .onAppear {
                        print("Workout route is empty, map preview not shown for workout: \(workout.id)")
                    }
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.4), Color.black.opacity(0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct ModernStatRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

struct MapRoutePreview: UIViewRepresentable {
    let route: [Coordinate]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isUserInteractionEnabled = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        print("🗺️ MapRoutePreview updateUIView called with \(route.count) coordinates")
        mapView.removeOverlays(mapView.overlays)
        let coords = route.map { $0.clLocationCoordinate2D }
        print("🗺️ Converted to \(coords.count) CLLocationCoordinate2D coordinates")
        
        guard coords.count > 1 else {
            print("🗺️ Not enough coordinates for polyline (need > 1, got \(coords.count))")
            // Center on first point if only one
            if let first = coords.first {
                let region = MKCoordinateRegion(center: first, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                mapView.setRegion(region, animated: false)
            }
            return
        }
        
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        mapView.addOverlay(polyline)
        print("🗺️ Added polyline with \(coords.count) coordinates")
        
        // Fit region
        var rect = polyline.boundingMapRect
        let padding = 0.002
        rect = rect.insetBy(dx: -rect.size.width * padding, dy: -rect.size.height * padding)
        mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10), animated: false)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 8 // Increased line width for better visibility
                renderer.alpha = 1.0 // Full opacity
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

struct FullScreenMapView: View {
    let workout: Workout
    @ObservedObject private var preferencesManager = UserPreferencesManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var replayIndex: Int = 1 // Revert to Int for working replay
    @State private var isPlaying: Bool = false
    @State private var speed: Double = 5.0 // Default to 5x
    let speedOptions: [Double] = [1.0, 5.0, 10.0]
    @State private var timer: Timer? = nil
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ReplayMapRouteView(
                coordinates: workout.route.map { $0.clLocationCoordinate2D },
                replayIndex: replayIndex
            )
            .edgesIgnoringSafeArea(.all)
            .onDisappear {
                timer?.invalidate()
            }
            
            // Close button (closer to top left)
            Button(action: {
                timer?.invalidate()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(10)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
            }
            .padding(.top, 18)
            .padding(.leading, 14)
            
            // Compact stats box (top right)
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 10) {
                    StatIconText(icon: "speedometer", text: UnitConverter.formatSpeed(workout.averageSpeed, unitSystem: preferencesManager.preferences.unitSystem))
                    StatIconText(icon: "bolt.fill", text: UnitConverter.formatSpeed(workout.peakSpeed, unitSystem: preferencesManager.preferences.unitSystem))
                }
                HStack(spacing: 10) {
                    StatIconText(icon: "location.fill", text: UnitConverter.formatDistance(workout.distance * 1609.34, unitSystem: preferencesManager.preferences.unitSystem))
                    StatIconText(icon: "clock.fill", text: formatTime(workout.duration))
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.65))
            .cornerRadius(12)
            .padding(.top, 18)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .topTrailing)
            
            // Speed controls and progress bar (bottom center)
            VStack(spacing: 12) {
                Spacer()
                // Progress bar with play button
                if workout.route.count > 1 {
                    HStack(spacing: 16) {
                        Button(action: {
                            if isPlaying {
                                timer?.invalidate()
                                isPlaying = false
                            } else {
                                if replayIndex >= workout.route.count {
                                    replayIndex = 1
                                }
                                startReplay()
                            }
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.white)
                                .shadow(radius: 6)
                                .background(Color.black.opacity(0.3).clipShape(Circle()))
                        }
                        Slider(value: Binding(
                            get: { Double(replayIndex) },
                            set: { newValue in
                                timer?.invalidate()
                                replayIndex = Int(newValue)
                                isPlaying = false
                            }
                        ), in: 1...Double(workout.route.count), step: 1)
                        .accentColor(.green)
                    }
                    .padding(.horizontal, 30)
                    // Live timer below slider
                    HStack {
                        Text(replayElapsedTimeString)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Text(totalElapsedTimeString)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 38)
                }
                // Speed controls
                HStack(spacing: 16) {
                    ForEach(speedOptions, id: \.self) { option in
                        Button(action: {
                            speed = option
                            if isPlaying { restartReplay() }
                        }) {
                            Text("\(Int(option))x")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(speed == option ? .black : .white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(speed == option ? Color.white : Color.black.opacity(0.7))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        let seconds = Int(timeInterval) % 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm %ds", minutes, seconds)
        }
    }
    
    private func startReplay() {
        timer?.invalidate()
        isPlaying = true
        let total = workout.route.count
        guard total > 1 else { return }
        if replayIndex >= total {
            replayIndex = 1
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2 / speed, repeats: true) { _ in
            if replayIndex < total {
                replayIndex += 1
            } else {
                timer?.invalidate()
                isPlaying = false
                replayIndex = total
            }
        }
    }
    private func restartReplay() {
        if isPlaying {
            startReplay()
        }
    }
    
    // Add computed properties for timer display
    private var replayElapsedTimeString: String {
        guard workout.route.count > 1 else { return "0:00" }
        let totalTime = workout.duration
        let percent = Double(replayIndex - 1) / Double(workout.route.count - 1)
        let elapsed = totalTime * percent
        return formatTimeShort(elapsed)
    }
    private var totalElapsedTimeString: String {
        formatTimeShort(workout.duration)
    }
    private func formatTimeShort(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ReplayMapRouteView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let replayIndex: Int
    
    class MapState: NSObject {
        var didSetRegion = false
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = true
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true
        
        // Set initial region to fit the full route
        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            var rect = polyline.boundingMapRect
            let padding = 0.1
            rect = rect.insetBy(dx: -rect.size.width * padding, dy: -rect.size.height * padding)
            mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 50, left: 20, bottom: 50, right: 20), animated: false)
        } else if let first = coordinates.first {
            let region = MKCoordinateRegion(center: first, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            mapView.setRegion(region, animated: false)
        }
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        let shownCoords = Array(coordinates.prefix(replayIndex))
        if shownCoords.count > 1 {
            let polyline = MKPolyline(coordinates: shownCoords, count: shownCoords.count)
            mapView.addOverlay(polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 8 // Increased line width for better visibility
                renderer.alpha = 1.0 // Full opacity
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

struct StatIconText: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.green)
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(Color.white.opacity(0.08))
        .cornerRadius(6)
    }
}

struct SheetContentView: View {
    let workout: Workout // Now non-optional
    
    var body: some View {
        FullScreenMapView(workout: workout)
            .onAppear {
                print("Sheet presenting workout: \(workout.id)")
            }
    }
} 