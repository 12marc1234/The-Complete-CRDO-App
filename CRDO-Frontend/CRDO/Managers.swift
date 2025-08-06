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
    // Static reference to the current instance
    static var currentInstance: RunManager?
    
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
    @Published var longestDistance: Double = 0.0
    
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
        
        // Set this as the current instance
        RunManager.currentInstance = self
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
        
        // Update stats every 1 second to reduce CPU usage
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
            
            // Update daily progress (persists even when logging out)
            GemsManager.shared.addDailyProgress(seconds: Int(updatedRun.duration))
            
            // Refresh achievements based on new run data
            AchievementManager.shared.refreshAchievements()
            
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
    
    func pauseRun() {
        guard isRunning else { return }
        
        print("⏸️ Pausing run...")
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    func resumeRun() {
        guard !isRunning, currentRun != nil else { return }
        
        print("▶️ Resuming run...")
        locationManager.startUpdatingLocation()
        
        // Restart timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateRunStats()
        }
        
        isRunning = true
    }
    
    func finishRun() {
        guard let run = currentRun else { return }
        
        // Calculate final stats
        let finalDistance = distance
        let finalDuration = Date().timeIntervalSince(run.startTime)
        
        // Calculate final average speed (distance/time)
        let finalDistanceInMiles = finalDistance / 1609.34 // Convert meters to miles
        let finalTimeInHours = finalDuration / 3600 // Convert seconds to hours
        let finalAverageSpeed = finalDistanceInMiles / finalTimeInHours // mph
        
        // Calculate final average pace (time/distance)
        let finalAveragePace = finalTimeInHours * 60 / finalDistanceInMiles // minutes per mile
        
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
        print("   Final Distance: \(finalDistance) meters (\(finalDistanceInMiles) miles)")
        print("   Final Average Speed: \(finalAverageSpeed) mph")
        print("   Final Average Pace: \(finalAveragePace) min/mi")
        print("   Final Duration: \(finalDuration) seconds")
        
        GemsManager.shared.awardGemsForRun(
            distance: finalDistance,
            averageSpeed: finalAverageSpeed,
            duration: finalDuration
        )
        
        // Check for potential achievements and send notifications
        checkForAchievements(distance: finalDistance, averageSpeed: finalAverageSpeed, duration: finalDuration)
        
        // Add to recent runs
        recentRuns.insert(updatedRun, at: 0)
        saveRecentRuns() // Save the updated runs list
        
        // Save to WorkoutStore for the workout history
        saveToWorkoutHistory(updatedRun)
        
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
    
    private func saveToWorkoutHistory(_ run: RunSession) {
        print("💾 saveToWorkoutHistory called with run route count: \(run.route.count)")
        
        // Convert RunSession to Workout
        let workout = Workout(
            date: run.startTime,
            averageSpeed: run.averagePace > 0 ? 60 / run.averagePace : 0, // Convert pace to speed
            peakSpeed: run.averagePace > 0 ? 60 / run.averagePace : 0, // Use average as peak for now
            distance: run.distance / 1609.34, // Convert meters to miles
            time: run.duration,
            route: run.route.map { Coordinate($0) }, // Convert CLLocationCoordinate2D to Coordinate
            category: .running
        )
        
        print("💾 Created workout with route count: \(workout.route.count)")
        print("💾 Workout route coordinates: \(workout.route.map { "\($0.latitude), \($0.longitude)" })")
        
        // Save to WorkoutStore
        WorkoutStore.shared.saveWorkout(workout)
        
        // Post notification to trigger UI updates
        NotificationCenter.default.post(name: NSNotification.Name("WorkoutAdded"), object: nil)
        
        print("💾 Workout saved to WorkoutStore and notification posted")
    }
    
    private func updateRunStats() {
        guard let startTime = startTime else { return }
        
        duration = Date().timeIntervalSince(startTime)
        
        if let run = currentRun {
            var updatedRun = run
            updatedRun.duration = duration
            updatedRun.distance = distance
            
            // Calculate current average pace based on current average speed
            if averageSpeed > 0.5 {
                updatedRun.averagePace = 60 / averageSpeed // minutes per mile
            } else {
                updatedRun.averagePace = pace // Use current pace as fallback
            }
            
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
        
        // Calculate longest distance
        longestDistance = recentRuns.map { $0.distance }.max() ?? 0.0
    }
    
    private func shouldAddToRoute(_ location: CLLocation) -> Bool {
        guard let lastLocation = lastLocation else { return true }
        
        let distance = location.distance(from: lastLocation)
        let timeInterval = location.timestamp.timeIntervalSince(lastLocation.timestamp)
        
        // Much more responsive route tracking to capture the actual path
        // Add points more frequently to show the real route with all turns and curves
        // Only require 2 meters distance and 1 second time interval
        return distance >= 2 && timeInterval >= 1
    }
    
    func loadRecentRuns() {
        let userId = DataManager.shared.getUserId() ?? "guest"
        let key = "recentRuns_\(userId)"
        
        if let data = UserDefaults.standard.data(forKey: key),
           let runs = try? JSONDecoder().decode([RunSession].self, from: data) {
            recentRuns = runs
        } else {
            // Create some test runs with GPS coordinates for demonstration
            createTestRuns()
        }
    }
    
    private func createTestRuns() {
        // Create test runs with realistic GPS coordinates that show curved paths
        let testRuns: [RunSession] = [
            createTestRun(
                distance: 5000, // 5km
                duration: 1800, // 30 minutes
                averagePace: 360, // 6 min/km
                coordinates: generateCurvedRoute(
                    startLat: 37.7749, startLon: -122.4194,
                    endLat: 37.7789, endLon: -122.4234,
                    points: 25
                ),
                startTime: Date().addingTimeInterval(-86400) // Yesterday
            ),
            createTestRun(
                distance: 3000, // 3km
                duration: 1200, // 20 minutes
                averagePace: 400, // 6.67 min/km
                coordinates: generateCurvedRoute(
                    startLat: 37.7849, startLon: -122.4094,
                    endLat: 37.7879, endLon: -122.4124,
                    points: 20
                ),
                startTime: Date().addingTimeInterval(-172800) // 2 days ago
            ),
            createTestRun(
                distance: 8000, // 8km
                duration: 2400, // 40 minutes
                averagePace: 300, // 5 min/km
                coordinates: generateCurvedRoute(
                    startLat: 37.7649, startLon: -122.4294,
                    endLat: 37.7709, endLon: -122.4354,
                    points: 35
                ),
                startTime: Date().addingTimeInterval(-259200) // 3 days ago
            )
        ]
        
        recentRuns = testRuns
        saveRecentRuns()
    }
    
    private func generateCurvedRoute(startLat: Double, startLon: Double, endLat: Double, endLon: Double, points: Int) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        
        for i in 0..<points {
            let progress = Double(i) / Double(points - 1)
            
            // Create a curved path using a sine wave for natural movement
            let latProgress = startLat + (endLat - startLat) * progress
            let lonProgress = startLon + (endLon - startLon) * progress
            
            // Add some natural curve using sine wave
            let curveOffset = sin(progress * .pi * 2) * 0.0005
            let latWithCurve = latProgress + curveOffset
            let lonWithCurve = lonProgress + curveOffset * 0.5
            
            coordinates.append(CLLocationCoordinate2D(latitude: latWithCurve, longitude: lonWithCurve))
        }
        
        return coordinates
    }
    
    private func createTestRun(distance: Double, duration: TimeInterval, averagePace: Double, coordinates: [CLLocationCoordinate2D], startTime: Date) -> RunSession {
        var run = RunSession()
        run.startTime = startTime
        run.endTime = startTime.addingTimeInterval(duration)
        run.distance = distance
        run.duration = duration
        run.averagePace = averagePace
        run.maxPace = averagePace * 0.8 // Slightly faster than average
        run.route = coordinates
        run.isActive = false
        return run
    }
    
    func saveRecentRuns() {
        let userId = DataManager.shared.getUserId() ?? "guest"
        let key = "recentRuns_\(userId)"
        
        if let data = try? JSONEncoder().encode(recentRuns) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // MARK: - Achievement Checking
    
    private func checkForAchievements(distance: Double, averageSpeed: Double, duration: TimeInterval) {
        let notificationManager = NotificationManager.shared
        
        // Check distance-based achievements
        let distanceInMiles = distance / 1609.34
        
        if distanceInMiles >= 3.1 && !UserDefaults.standard.bool(forKey: "achievement_5k_runner") {
            UserDefaults.standard.set(true, forKey: "achievement_5k_runner")
            let achievement = Achievement(
                title: "5K Runner", 
                description: "Run 5 kilometers in a single session", 
                icon: "flag.checkered", 
                category: .distance,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 5000,
                current: Int(distance)
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        if distanceInMiles >= 6.2 && !UserDefaults.standard.bool(forKey: "achievement_10k_runner") {
            UserDefaults.standard.set(true, forKey: "achievement_10k_runner")
            let achievement = Achievement(
                title: "10K Runner", 
                description: "Run 10 kilometers in a single session", 
                icon: "flag.checkered.2", 
                category: .distance,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 10000,
                current: Int(distance)
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        if distanceInMiles >= 13.1 && !UserDefaults.standard.bool(forKey: "achievement_half_marathon") {
            UserDefaults.standard.set(true, forKey: "achievement_half_marathon")
            let achievement = Achievement(
                title: "Half Marathon", 
                description: "Run 13.1 miles in a single session", 
                icon: "flag.checkered.3", 
                category: .distance,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 21097,
                current: Int(distance)
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        // Check speed-based achievements
        let paceInMinutes = 60 / averageSpeed // minutes per mile
        
        if paceInMinutes <= 7.0 && !UserDefaults.standard.bool(forKey: "achievement_speed_demon") {
            UserDefaults.standard.set(true, forKey: "achievement_speed_demon")
            let achievement = Achievement(
                title: "Speed Demon", 
                description: "Achieve a pace faster than 7:00 min/mi", 
                icon: "bolt.fill", 
                category: .speed,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 420,
                current: Int(paceInMinutes * 60)
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        if paceInMinutes <= 6.0 && !UserDefaults.standard.bool(forKey: "achievement_sprint_king") {
            UserDefaults.standard.set(true, forKey: "achievement_sprint_king")
            let achievement = Achievement(
                title: "Sprint King", 
                description: "Achieve a pace faster than 6:00 min/mi", 
                icon: "bolt.circle.fill", 
                category: .speed,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 360,
                current: Int(paceInMinutes * 60)
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        if paceInMinutes <= 5.0 && !UserDefaults.standard.bool(forKey: "achievement_elite_runner") {
            UserDefaults.standard.set(true, forKey: "achievement_elite_runner")
            let achievement = Achievement(
                title: "Elite Runner", 
                description: "Achieve a pace faster than 5:00 min/mi", 
                icon: "bolt.shield.fill", 
                category: .speed,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 300,
                current: Int(paceInMinutes * 60)
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        // Check duration-based achievements
        let durationInHours = duration / 3600
        
        if durationInHours >= 2.0 && !UserDefaults.standard.bool(forKey: "achievement_endurance_runner") {
            UserDefaults.standard.set(true, forKey: "achievement_endurance_runner")
            let achievement = Achievement(
                title: "Endurance Runner", 
                description: "Run for 2 hours straight", 
                icon: "timer.circle", 
                category: .challenge,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 7200,
                current: Int(duration)
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        // Check frequency-based achievements
        let totalRuns = recentRuns.count + 1 // +1 for current run
        
        if totalRuns >= 10 && !UserDefaults.standard.bool(forKey: "achievement_frequent_runner") {
            UserDefaults.standard.set(true, forKey: "achievement_frequent_runner")
            let achievement = Achievement(
                title: "Frequent Runner", 
                description: "Complete 10 runs", 
                icon: "number.circle", 
                category: .frequency,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 10,
                current: totalRuns
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        if totalRuns >= 50 && !UserDefaults.standard.bool(forKey: "achievement_dedicated_runner") {
            UserDefaults.standard.set(true, forKey: "achievement_dedicated_runner")
            let achievement = Achievement(
                title: "Dedicated Runner", 
                description: "Complete 50 runs", 
                icon: "number.circle.fill", 
                category: .frequency,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 50,
                current: totalRuns
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        if totalRuns >= 100 && !UserDefaults.standard.bool(forKey: "achievement_veteran_runner") {
            UserDefaults.standard.set(true, forKey: "achievement_veteran_runner")
            let achievement = Achievement(
                title: "Veteran Runner", 
                description: "Complete 100 runs", 
                icon: "number.square", 
                category: .frequency,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 100,
                current: totalRuns
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        // Check milestone achievements
        let totalDistanceInMiles = (recentRuns.reduce(0) { $0 + $1.distance } + distance) / 1609.34
        
        if totalDistanceInMiles >= 10 && !UserDefaults.standard.bool(forKey: "achievement_ten_miler") {
            UserDefaults.standard.set(true, forKey: "achievement_ten_miler")
            let achievement = Achievement(
                title: "Ten Miler", 
                description: "Run 10 miles total", 
                icon: "10.circle", 
                category: .milestone,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 16093,
                current: Int(totalDistanceInMiles * 1609.34)
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        if totalDistanceInMiles >= 100 && !UserDefaults.standard.bool(forKey: "achievement_hundred_miler") {
            UserDefaults.standard.set(true, forKey: "achievement_hundred_miler")
            let achievement = Achievement(
                title: "Hundred Miler", 
                description: "Run 100 miles total", 
                icon: "100.circle", 
                category: .milestone,
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1.0,
                target: 160934,
                current: Int(totalDistanceInMiles * 1609.34)
            )
            notificationManager.scheduleAchievementNotification(achievement: achievement)
        }
        
        print("🏆 Achievement check completed for run: \(distanceInMiles) miles, \(averageSpeed) mph, \(durationInHours) hours")
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
            
            // Calculate true average speed based on total distance and time
            if duration > 0 {
                let distanceInMiles = distance / 1609.34 // Convert meters to miles
                let timeInHours = duration / 3600 // Convert seconds to hours
                averageSpeed = distanceInMiles / timeInHours // mph
            }
            
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
        
        // Calculate pace (minutes per mile) based on current speed
        if currentSpeed > 0.5 { // Only calculate pace if speed is reasonable
            pace = 60 / currentSpeed // minutes per mile
        }
        
        // Calculate average pace based on average speed
        if averageSpeed > 0.5 {
            let averagePace = 60 / averageSpeed // minutes per mile
            // Update the current run's average pace
            if let run = currentRun {
                var updatedRun = run
                updatedRun.averagePace = averagePace
                currentRun = updatedRun
            }
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