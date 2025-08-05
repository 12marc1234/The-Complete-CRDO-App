//
//  NotificationManager.swift
//  CRDO
//
//  Created by Marcus Lee on 8/4/25.
//  Notification manager for local and remote notifications
//

import Foundation
import UserNotifications
import SwiftUI

// MARK: - Notification Manager

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var notificationSettings = NotificationSettings()
    
    private override init() {
        super.init()
        loadNotificationSettings()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.scheduleDefaultNotifications()
                }
                if let error = error {
                    print("❌ Notification authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleDefaultNotifications() {
        // Clear existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Schedule daily reminder
        if notificationSettings.dailyReminder {
            scheduleDailyReminder()
        }
        
        // Schedule weekly summary
        if notificationSettings.weeklySummary {
            scheduleWeeklySummary()
        }
        
        // Schedule streak reminders
        if notificationSettings.streakReminders {
            scheduleStreakReminders()
        }
    }
    
    private func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time for a Run! 🏃‍♂️"
        content.body = "Don't break your streak! Get out there and crush your daily goal."
        content.sound = .default
        content.badge = 1
        
        // Schedule for 6 PM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 18
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule daily reminder: \(error.localizedDescription)")
            } else {
                print("✅ Daily reminder scheduled")
            }
        }
    }
    
    private func scheduleWeeklySummary() {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Running Summary 📊"
        content.body = "Check out your progress this week and see how you're doing!"
        content.sound = .default
        
        // Schedule for Sunday at 9 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weeklySummary", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule weekly summary: \(error.localizedDescription)")
            } else {
                print("✅ Weekly summary scheduled")
            }
        }
    }
    
    private func scheduleStreakReminders() {
        let content = UNMutableNotificationContent()
        content.title = "Streak Alert! 🔥"
        content.body = "You're on a roll! Don't let your streak die - get out there today!"
        content.sound = .default
        
        // Schedule for 5 PM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 17
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "streakReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule streak reminder: \(error.localizedDescription)")
            } else {
                print("✅ Streak reminder scheduled")
            }
        }
    }
    
    // MARK: - Achievement Notifications
    
    func scheduleAchievementNotification(achievement: Achievement) {
        let content = UNMutableNotificationContent()
        content.title = "Achievement Unlocked! 🏆"
        content.body = "\(achievement.title): \(achievement.description)"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "achievement_\(achievement.id)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule achievement notification: \(error.localizedDescription)")
            } else {
                print("✅ Achievement notification scheduled: \(achievement.title)")
            }
        }
    }
    
    // MARK: - Goal Notifications
    
    func scheduleGoalNotification(goalType: GoalType, progress: Double) {
        let content = UNMutableNotificationContent()
        
        switch goalType {
        case .dailyGoal:
            content.title = "Daily Goal Progress! 📈"
            content.body = "You're \(Int(progress * 100))% to your daily goal. Keep it up!"
        case .weeklyGoal:
            content.title = "Weekly Goal Progress! 🎯"
            content.body = "You're \(Int(progress * 100))% to your weekly goal. Almost there!"
        case .streakGoal:
            content.title = "Streak Goal Progress! 🔥"
            content.body = "You're \(Int(progress * 100))% to your streak goal. Don't stop now!"
        }
        
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "goal_\(goalType.rawValue)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule goal notification: \(error.localizedDescription)")
            } else {
                print("✅ Goal notification scheduled: \(goalType.rawValue)")
            }
        }
    }
    
    // MARK: - Friend Notifications
    
    func scheduleFriendNotification(type: FriendNotificationType, friendName: String) {
        let content = UNMutableNotificationContent()
        
        switch type {
        case .friendRequest:
            content.title = "New Friend Request! 👋"
            content.body = "\(friendName) wants to be your friend on CRDO!"
        case .friendAccepted:
            content.title = "Friend Request Accepted! ✅"
            content.body = "\(friendName) accepted your friend request!"
        case .friendChallenge:
            content.title = "New Challenge! 🏁"
            content.body = "\(friendName) challenged you to a run!"
        }
        
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "friend_\(type.rawValue)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule friend notification: \(error.localizedDescription)")
            } else {
                print("✅ Friend notification scheduled: \(type.rawValue)")
            }
        }
    }
    
    // MARK: - Settings Management
    
    private func loadNotificationSettings() {
        if let data = UserDefaults.standard.data(forKey: "notificationSettings"),
           let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            self.notificationSettings = settings
        }
    }
    
    func updateNotificationSettings(_ settings: NotificationSettings) {
        self.notificationSettings = settings
        saveNotificationSettings()
        scheduleDefaultNotifications()
    }
    
    private func saveNotificationSettings() {
        if let data = try? JSONEncoder().encode(notificationSettings) {
            UserDefaults.standard.set(data, forKey: "notificationSettings")
        }
    }
    
    // MARK: - Utility Methods
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            completion(requests)
        }
    }
}

// MARK: - Notification Settings

struct NotificationSettings: Codable {
    var dailyReminder: Bool = true
    var weeklySummary: Bool = true
    var streakReminders: Bool = true
    var achievementNotifications: Bool = true
    var goalNotifications: Bool = true
    var friendNotifications: Bool = true
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
}

// MARK: - Notification Types

enum GoalType: String, CaseIterable {
    case dailyGoal = "daily"
    case weeklyGoal = "weekly"
    case streakGoal = "streak"
}

enum FriendNotificationType: String, CaseIterable {
    case friendRequest = "request"
    case friendAccepted = "accepted"
    case friendChallenge = "challenge"
} 