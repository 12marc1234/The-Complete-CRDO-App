//
//  CRDOApp.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//

import SwiftUI
import CoreLocation
import UserNotifications

@main
struct CRDOApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Request notification permissions when app launches
                    notificationManager.requestAuthorization()
                }
        }
    }
}
