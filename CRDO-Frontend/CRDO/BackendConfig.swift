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
    // Development (Supabase Local)
    static let developmentBaseURL = "http://127.0.0.1:54321/functions/v1"
    static let developmentWebSocketURL = "ws://127.0.0.1:54321"
    
    // Staging (Supabase)
    static let stagingBaseURL = "https://your-project-ref.supabase.co/functions/v1"
    static let stagingWebSocketURL = "wss://your-project-ref.supabase.co"
    
    // Production (Supabase)
    static let productionBaseURL = "https://your-project-ref.supabase.co/functions/v1"
    static let productionWebSocketURL = "wss://your-project-ref.supabase.co"
    
    // Current environment
    static let currentEnvironment: Environment = .development
    
    enum Environment {
        case development
        case staging
        case production
        
        var baseURL: String {
            switch self {
            case .development:
                return BackendConfig.developmentBaseURL
            case .staging:
                return BackendConfig.stagingBaseURL
            case .production:
                return BackendConfig.productionBaseURL
            }
        }
        
        var webSocketURL: String {
            switch self {
            case .development:
                return BackendConfig.developmentWebSocketURL
            case .staging:
                return BackendConfig.stagingWebSocketURL
            case .production:
                return BackendConfig.productionWebSocketURL
            }
        }
    }
    
    // API Timeouts
    static let requestTimeout: TimeInterval = 30.0
    static let uploadTimeout: TimeInterval = 60.0
    
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