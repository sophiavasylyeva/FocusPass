import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import SwiftUI

@available(iOS 15.0, *)
class ScreenTimeHandler: NSObject {
    
    private let store = ManagedSettingsStore()
    private let center = AuthorizationCenter.shared
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            try await center.requestAuthorization(for: .individual)
            return center.authorizationStatus == .approved
        } catch {
            print("Failed to request authorization: \(error)")
            return false
        }
    }
    
    func isAuthorized() -> Bool {
        return center.authorizationStatus == .approved
    }
    
    // MARK: - App Selection and Restrictions
    
    func getInstalledApps() async -> [String: String] {
        var appDict: [String: String] = [:]
        
        do {
            let apps = try await center.requestAuthorization(for: .child)
            // Note: Due to privacy, iOS doesn't allow direct access to installed apps
            // We'll work with a predefined list of common apps
            appDict = getCommonApps()
        } catch {
            print("Failed to get apps: \(error)")
            appDict = getCommonApps()
        }
        
        return appDict
    }
    
    private func getCommonApps() -> [String: String] {
        return [
            "Instagram": "com.burbn.instagram",
            "TikTok": "com.zhiliaoapp.musically",
            "YouTube": "com.google.ios.youtube",
            "Snapchat": "com.toyopagroup.picaboo",
            "Twitter": "com.atebits.Tweetie2",
            "Facebook": "com.facebook.Facebook",
            "Discord": "com.hammerandchisel.discord",
            "Roblox": "com.roblox.robloxmobile",
            "Minecraft": "com.mojang.minecraftpe",
            "Fortnite": "com.epicgames.fortnitemobile"
        ]
    }
    
    // MARK: - Screen Time Configuration
    
    func configureRestrictions(appNames: [String], dailyLimitMinutes: Int, earnedTimeMinutes: Int) {
        guard isAuthorized() else {
            print("Not authorized for Screen Time")
            return
        }
        
        let totalMinutes = dailyLimitMinutes + earnedTimeMinutes
        let commonApps = getCommonApps()
        
        // Filter to get bundle IDs for the requested apps
        var selectedTokens: Set<ApplicationToken> = []
        
        for appName in appNames {
            if let bundleId = commonApps[appName] {
                // In a real implementation, you'd need to get the actual ApplicationToken
                // This is a simplified version for demonstration
                print("Would restrict app: \(appName) with bundle ID: \(bundleId)")
            }
        }
        
        // Configure app restrictions
        if !selectedTokens.isEmpty {
            store.application.blockedApplications = selectedTokens
        }
        
        // Set up time-based restrictions using DeviceActivity
        configureDeviceActivity(limitMinutes: totalMinutes, apps: selectedTokens)
    }
    
    private func configureDeviceActivity(limitMinutes: Int, apps: Set<ApplicationToken>) {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        let event = DeviceActivityEvent(
            applications: apps,
            threshold: DateComponents(minute: limitMinutes)
        )
        
        let request = DeviceActivityRequest(
            schedule: schedule,
            events: ["screenTimeLimit": event]
        )
        
        do {
            try DeviceActivityCenter().startMonitoring(.screenTime, during: schedule)
            print("Started monitoring device activity")
        } catch {
            print("Failed to start monitoring: \(error)")
        }
    }
    
    // MARK: - Usage Statistics
    
    func getUsageStats() async -> [String: Int] {
        var usageStats: [String: Int] = [:]
        
        // Note: iOS doesn't provide direct access to usage statistics for third-party apps
        // In a real implementation, you would use DeviceActivity reports
        // For now, we'll return mock data or integrate with Screen Time reports
        
        let commonApps = getCommonApps()
        for (appName, _) in commonApps {
            // This would be replaced with actual usage data from DeviceActivity reports
            usageStats[appName] = Int.random(in: 0...120) // Mock data in minutes
        }
        
        return usageStats
    }
    
    // MARK: - Earned Time Management
    
    func updateEarnedTime(minutes: Int) {
        // Update earned time and reconfigure restrictions
        let defaults = UserDefaults.standard
        let currentEarned = defaults.integer(forKey: "earnedTimeToday")
        let newEarnedTime = currentEarned + minutes
        
        defaults.set(newEarnedTime, forKey: "earnedTimeToday")
        
        // You would reconfigure restrictions here with the new earned time
        print("Updated earned time to: \(newEarnedTime) minutes")
    }
    
    func getEarnedTime() -> Int {
        return UserDefaults.standard.integer(forKey: "earnedTimeToday")
    }
    
    // MARK: - Reset Daily Data
    
    func resetDailyData() {
        UserDefaults.standard.set(0, forKey: "earnedTimeToday")
        // Reset any other daily tracking data
    }
}

// MARK: - DeviceActivity Extension for handling events

@available(iOS 15.0, *)
extension ScreenTimeHandler {
    
    func handleScreenTimeLimitReached(for applications: Set<ApplicationToken>) {
        // This would be called when screen time limits are reached
        store.application.blockedApplications = applications
        
        // Show a blocking screen or notification
        showLimitReachedNotification()
    }
    
    private func showLimitReachedNotification() {
        // Implementation would show a native iOS notification
        // or redirect to the FocusPass app
        print("Screen time limit reached - apps are now blocked")
    }
}
