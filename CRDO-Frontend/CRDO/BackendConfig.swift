//
//  BackendConfig.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Backend configuration settings
//

import Foundation

// MARK: - Backend Configuration

struct BackendConfig {
    // Development (Local Supabase Functions)
    static let developmentBaseURL = "http://localhost:54321/functions/v1"
    static let developmentWebSocketURL = "ws://localhost:54321"
    
    // Production (Supabase) - TEMPORARY: Using a working Supabase project
    // TODO: Replace with your actual Supabase project URL
    // Get this from your Supabase project dashboard
    // Example: https://abc123def456.supabase.co/functions/v1
    static let productionBaseURL = "https://crdo-app.supabase.co/functions/v1"
    static let productionWebSocketURL = "wss://crdo-app.supabase.co"
    
    // Current environment - TEMPORARILY using development for testing
    // FOR TESTFLIGHT: Change this to .production after setting up your Supabase project
    static let currentEnvironment: Environment = .development // Temporarily use development for testing
    
    enum Environment {
        case development
        case production
    }
    
    static var baseURL: String {
        switch currentEnvironment {
        case .development:
            return developmentBaseURL
        case .production:
            return productionBaseURL
        }
    }
    
    static var webSocketURL: String {
        switch currentEnvironment {
        case .development:
            return developmentWebSocketURL
        case .production:
            return productionWebSocketURL
        }
    }
    
    // API Timeouts - INCREASED for better reliability
    static let requestTimeout: TimeInterval = 60.0  // Increased from 30 to 60 seconds
    static let uploadTimeout: TimeInterval = 120.0  // Increased from 60 to 120 seconds
    
    // Retry Configuration
    static let maxRetryAttempts = 3
    static let retryDelay: TimeInterval = 2.0
    
    // Cache Configuration
    static let cacheExpirationTime: TimeInterval = 300.0 // 5 minutes
    
    // Sync Configuration
    static let autoSyncInterval: TimeInterval = 300.0 // 5 minutes
    static let maxPendingUploads = 50
}

// MARK: - Feature Flags

struct FeatureFlags {
    static let enableRealTimeSync = true
    static let enableOfflineMode = true
    static let enablePushNotifications = true
    static let enableSocialFeatures = true
    static let enableChallenges = true
    static let enableLeaderboard = true
}

// MARK: - API Versioning

struct APIVersion {
    static let current = "v1"
    static let supportedVersions = ["v1"]
    
    static func isVersionSupported(_ version: String) -> Bool {
        return supportedVersions.contains(version)
    }
} 