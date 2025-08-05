//
//  Configuration.swift
//  CRDO
//
//  Created by Ethan Yip on 7/25/25.
//

import Foundation
import CoreLocation

// MARK: - App Configuration

struct AppConfiguration {
    static let appName = "CRDO"
    static let appVersion = "1.0.0"
    
    // Location permissions
    static let locationUsageDescription = "CRDO needs access to your location to track your workout routes and calculate distance."
    static let locationAlwaysUsageDescription = "CRDO needs access to your location to track your workout routes and calculate distance even when the app is in the background."
    
    // Background modes
    static let backgroundModes: [String] = ["location", "background-processing"]
}

// MARK: - Permission Manager

class PermissionManager: NSObject, ObservableObject {
    static let shared = PermissionManager()
    
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationPermissionStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysLocationPermission() {
        locationManager.requestAlwaysAuthorization()
    }
}

// MARK: - Location Manager Delegate

extension PermissionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.locationPermissionStatus = status
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
} 