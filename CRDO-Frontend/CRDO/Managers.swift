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
        locationManager.distanceFilter = 1 // Reduced from 5 to 1 meter for more frequent updates
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = false
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
        
        // Update stats more frequently (every 0.5 seconds instead of 1.0)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
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
            
            // Update daily progress (persists even when logging out)
            GemsManager.shared.addDailyProgress(seconds: Int(updatedRun.duration))
            
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
        print("🏃‍♂️ Finishing Run:")
        print("   Final Distance: \(finalDistance) meters")
        print("   Final Average Speed: \(averageSpeed) mph")
        print("   Final Duration: \(finalDuration) seconds")
        
        GemsManager.shared.awardGemsForRun(
            distance: finalDistance,
            averageSpeed: averageSpeed,
            duration: finalDuration
        )
        
        // Add to recent runs
        recentRuns.insert(updatedRun, at: 0)
        saveRecentRuns() // Save the updated runs list
        
        // Update daily progress (persists even when logging out)
        GemsManager.shared.addDailyProgress(seconds: Int(finalDuration))
        
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
        
        // More responsive route tracking: add points more frequently
        // Only add point if it's at least 5 meters away and 2 seconds have passed
        return distance >= 5 && timeInterval >= 2
    }
    
    func loadRecentRuns() {
        let userId = DataManager.shared.getUserId() ?? "guest"
        let key = "recentRuns_\(userId)"
        
        if let data = UserDefaults.standard.data(forKey: key),
           let runs = try? JSONDecoder().decode([RunSession].self, from: data) {
            recentRuns = runs
        }
    }
    
    func saveRecentRuns() {
        let userId = DataManager.shared.getUserId() ?? "guest"
        let key = "recentRuns_\(userId)"
        
        if let data = try? JSONEncoder().encode(recentRuns) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Run Manager Location Delegate

extension RunManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let speed = location.speed * 2.237 // Convert m/s to mph
        
        // More lenient speed filtering
        if speed >= 0.01 && speed <= 25 { // Much more permissive speed range
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
        
        // Calculate distance with much less strict filtering
        if let lastLocation = lastLocation {
            let newDistance = location.distance(from: lastLocation)
            let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
            let speedMph = location.speed * 2.237
            
            // Much more lenient conditions for adding distance:
            // 1. Distance must be at least 1 meter (instead of 5)
            // 2. Speed must be at least 0.1 mph (instead of 0.3)
            // 3. Time between readings must be at least 1 second (instead of 2)
            // 4. Allow for GPS jitter and slow movement
            let expectedDistance = speedMph * 0.447 * timeInterval // Convert mph to m/s and multiply by time
            let distanceRatio = newDistance / max(expectedDistance, 0.1) // Avoid division by zero
            
            if newDistance > 1 && speedMph > 0.1 && timeInterval > 1 && distanceRatio < 10 {
                distance += newDistance
                print("📍 Distance added: \(newDistance)m, Total: \(distance)m, Speed: \(speedMph) mph")
            }
        }
        
        // Calculate pace (minutes per mile) - only if we have meaningful speed
        if currentSpeed > 0.5 { // Only calculate pace if speed is reasonable
            pace = 60 / currentSpeed // minutes per mile
        }
        
        // Add to route only if movement is significant
        if shouldAddToRoute(location) {
            route.append(location.coordinate)
        }
        
        lastLocation = location
        
        // Update stats immediately when new location data arrives
        updateRunStats()
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