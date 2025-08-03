//
//  CRDOApp.swift
//  CRDO
//
//  Created by Ethan yip on 7/25/25.
//

import SwiftUI
import CoreLocation

@main
struct CRDOApp: App {
    @StateObject private var runManager = RunManager.shared
    @StateObject private var permissionManager = PermissionManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Request location permissions when app launches
                    permissionManager.requestLocationPermission()
                }
        }
    }
}
