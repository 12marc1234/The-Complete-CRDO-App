//
//  Managers.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Managers for run tracking and permissions
//

import Foundation
import CoreLocation
import SwiftUI
import Combine

// MARK: - Run Manager

class RunManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var currentRun: RunSession?
    @Published var recentRuns: [RunSession] = []
    @Published var currentLocation: CLLocation?
    @Published var currentSpeed: Double = 0.0
    @Published var averageSpeed: Double = 0.0
    @Published var topSpeed: Double = 0.0
    @Published var distance: Double = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var pace: Double = 0.0
    @Published var route: [CLLocationCoordinate2D] = []
    
    // Daily goal properties
    @Published var dailySecondsCompleted: Int = 0
    @Published var dailyMinutesGoal: Int = 15
    
    // Stats properties
    @Published var totalDistance: Double = 0.0
    @Published var totalTime: Int = 0
    @Published var averagePace: Double = 0.0
    @Published var bestDistance: Double = 0.0
    
    private let locationManager = CLLocationManager()
    private var timer: Timer?
    private var startTime: Date?
    private var lastLocation: CLLocation?
    private var speedReadings: [Double] = []
    
    override init() {
        super.init()
        setupLocationManager()
        loadRecentRuns()
        calculateStats()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func startRun() {
        guard CLLocationManager.locationServicesEnabled() else {
            print("Location services are disabled")
            return
        }
        
        locationManager.requestWhenInUseAuthorization()
        
        isRunning = true
        startTime = Date()
        currentRun = RunSession()
        route.removeAll()
        speedReadings.removeAll()
        
        locationManager.startUpdatingLocation()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateRunStats()
        }
    }
    
    func stopRun() {
        isRunning = false
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        
        if let run = currentRun {
            var updatedRun = run
            updatedRun.endTime = Date()
            updatedRun.isActive = false
            recentRuns.insert(updatedRun, at: 0)
            saveRecentRuns()
            currentRun = nil
            
            // Update daily goal progress
            dailySecondsCompleted += Int(updatedRun.duration)
            
            // Recalculate stats
            calculateStats()
        }
        
        // Reset stats
        distance = 0.0
        duration = 0.0
        pace = 0.0
        currentSpeed = 0.0
        averageSpeed = 0.0
        topSpeed = 0.0
        route.removeAll()
    }
    
    func finishRun() {
        guard let run = currentRun else { return }
        
        // Calculate final stats
        let finalDistance = distance
        let finalDuration = Date().timeIntervalSince(run.startTime)
        let finalAveragePace = finalDuration / (finalDistance / 1609.34) // seconds per mile
        
        // Update the run with final stats
        var updatedRun = run
        updatedRun.endTime = Date()
        updatedRun.distance = finalDistance
        updatedRun.duration = finalDuration
        updatedRun.averagePace = finalAveragePace
        updatedRun.isActive = false
        updatedRun.route = route
        
        // Award gems for this run
        GemsManager.shared.awardGemsForRun(
            distance: finalDistance,
            averageSpeed: averageSpeed,
            duration: finalDuration
        )
        
        // Add to recent runs
        recentRuns.insert(updatedRun, at: 0)
        
        // Reset current run
        currentRun = nil
        distance = 0
        duration = 0
        averageSpeed = 0
        currentSpeed = 0
        pace = 0
        route = []
        lastLocation = nil
        
        // Stop location updates
        locationManager.stopUpdatingLocation()
    }
    
    private func updateRunStats() {
        guard let startTime = startTime else { return }
        
        duration = Date().timeIntervalSince(startTime)
        
        if let run = currentRun {
            var updatedRun = run
            updatedRun.duration = duration
            updatedRun.distance = distance
            updatedRun.averagePace = pace
            updatedRun.maxPace = topSpeed > 0 ? 1000 / topSpeed : 0
            updatedRun.route = route
            currentRun = updatedRun
        }
    }
    
    private func calculateStats() {
        // Calculate total distance
        totalDistance = recentRuns.reduce(0) { $0 + $1.distance }
        
        // Calculate total time
        totalTime = recentRuns.reduce(0) { $0 + Int($1.duration) }
        
        // Calculate average pace
        let totalPace = recentRuns.reduce(0.0) { $0 + $1.averagePace }
        averagePace = recentRuns.isEmpty ? 0.0 : totalPace / Double(recentRuns.count)
        
        // Calculate best distance
        bestDistance = recentRuns.map { $0.distance }.max() ?? 0.0
    }
    
    private func shouldAddToRoute(_ location: CLLocation) -> Bool {
        guard let lastLocation = lastLocation else { return true }
        
        let distance = location.distance(from: lastLocation)
        let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
        
        // Only add point if it's at least 10 meters away and 5 seconds have passed
        return distance >= 10 && timeInterval >= 5
    }
    
    private func loadRecentRuns() {
        if let data = UserDefaults.standard.data(forKey: "recentRuns"),
           let runs = try? JSONDecoder().decode([RunSession].self, from: data) {
            recentRuns = runs
        }
    }
    
    private func saveRecentRuns() {
        if let data = try? JSONEncoder().encode(recentRuns) {
            UserDefaults.standard.set(data, forKey: "recentRuns")
        }
    }
}

// MARK: - Run Manager Location Delegate

extension RunManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Less strict filtering for accuracy
        guard location.horizontalAccuracy <= 15 else { return } // Increased from 10 to 15 meters
        guard location.verticalAccuracy <= 20 else { return } // Increased from 15 to 20 meters
        
        currentLocation = location
        
        // Calculate speed (convert from m/s to mph)
        let speed = location.speed * 2.237 // Convert m/s to mph
        
        // Less strict speed filtering
        if speed >= 0.05 && speed <= 20 { // More permissive speed range
            currentSpeed = speed
            speedReadings.append(speed)
            
            // Keep only last 10 speed readings for more accurate average
            if speedReadings.count > 10 {
                speedReadings.removeFirst()
            }
            
            // Update average speed
            averageSpeed = speedReadings.reduce(0, +) / Double(speedReadings.count)
            
            // Update top speed
            if speed > topSpeed {
                topSpeed = speed
            }
        }
        
        // Calculate distance with less strict filtering
        if let lastLocation = lastLocation {
            let newDistance = location.distance(from: lastLocation)
            let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
            let speedMph = location.speed * 2.237
            
            // Less strict conditions for adding distance:
            // 1. Distance must be significant (> 5 meters instead of 10)
            // 2. Speed must be reasonable (> 0.3 mph instead of 1)
            // 3. Time between readings must be reasonable (> 2 seconds instead of 3)
            // 4. Speed must be consistent with distance (no teleporting)
            let expectedDistance = speedMph * 0.447 * timeInterval // Convert mph to m/s and multiply by time
            let distanceRatio = newDistance / max(expectedDistance, 1) // Avoid division by zero
            
            if newDistance > 5 && speedMph > 0.3 && timeInterval > 2 && distanceRatio < 5 {
                distance += newDistance
            }
        }
        
        // Calculate pace (minutes per mile)
        if currentSpeed > 0 {
            pace = 60 / currentSpeed // minutes per mile
        }
        
        // Add to route only if movement is significant
        if shouldAddToRoute(location) {
            route.append(location.coordinate)
        }
        
        lastLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if isRunning {
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            print("Location access denied")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - Permission Manager

class PermissionManager: ObservableObject {
    @Published var locationPermissionGranted = false
    @Published var showingPermissionAlert = false
    
    func requestLocationPermission() {
        let status = CLLocationManager.authorizationStatus()
        
        switch status {
        case .notDetermined:
            let locationManager = CLLocationManager()
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            showingPermissionAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            locationPermissionGranted = true
        @unknown default:
            break
        }
    }
    
    func checkLocationPermission() {
        let status = CLLocationManager.authorizationStatus()
        locationPermissionGranted = (status == .authorizedWhenInUse || status == .authorizedAlways)
    }
} 