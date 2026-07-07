import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import SwiftUI

@available(iOS 16.0, *)
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
        // Note: due to privacy, iOS doesn't allow direct access to installed apps.
        // We work with a predefined list of common apps instead.
        return getCommonApps()
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
    
    // MARK: - Family Activity Selection (real Apple app/category picker)

    func saveFamilyActivitySelection(_ selection: FamilyActivitySelection) {
        FamilyActivityStore.saveSelection(selection)
    }

    func loadFamilyActivitySelection() -> FamilyActivitySelection? {
        return FamilyActivityStore.loadSelection()
    }

    func selectionCounts(_ selection: FamilyActivitySelection) -> (apps: Int, categories: Int) {
        return (selection.applicationTokens.count, selection.categoryTokens.count)
    }

    /// Applies real Screen Time shielding using the tokens returned by
    /// FamilyActivityPicker. Unlike configureRestrictions(appNames:), this
    /// works for any app the user picked, not just the hardcoded common list.
    ///
    /// Earn-only model ("No screen time without earning it. No exceptions."):
    /// there is no free baseline, so `dailyLimitMinutes` is intentionally
    /// ignored here — only approved task minutes (`earnedTimeMinutes`) unlock
    /// usage. Apps are unshielded immediately so the newly earned time is
    /// usable right away; the DeviceActivityMonitorExtension re-shields them
    /// once cumulative usage of the selected apps reaches that many minutes,
    /// and shields everything again at the start of each new day.
    func applyStoredFamilyActivitySelection(dailyLimitMinutes: Int, earnedTimeMinutes: Int) {
        guard isAuthorized() else {
            print("Not authorized for Screen Time")
            return
        }
        guard let selection = loadFamilyActivitySelection() else {
            print("No stored FamilyActivitySelection to apply")
            return
        }

        guard earnedTimeMinutes > 0 else {
            // Nothing earned yet today — stay shielded.
            FamilyActivityStore.shieldAll(selection, using: store)
            return
        }

        FamilyActivityStore.unshieldAll(using: store)
        configureDeviceActivityForSelection(limitMinutes: earnedTimeMinutes, selection: selection)
    }

    private func configureDeviceActivityForSelection(limitMinutes: Int, selection: FamilyActivitySelection) {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: limitMinutes)
        )

        do {
            // Re-calling startMonitoring for the same DeviceActivityName replaces
            // the previous schedule/events, so this both re-arms the threshold
            // with the new earned total and (per Apple's docs) resets its
            // cumulative usage tracking for the current interval.
            try DeviceActivityCenter().startMonitoring(
                FamilyActivityStore.activityName,
                during: schedule,
                events: [FamilyActivityStore.eventName: event]
            )
            print("Started monitoring device activity for \(limitMinutes) minutes")
        } catch {
            print("Failed to start monitoring: \(error)")
        }
    }

    // MARK: - Screen Time Configuration

    func configureRestrictions(appNames: [String], dailyLimitMinutes: Int, earnedTimeMinutes: Int) {
        guard isAuthorized() else {
            print("Not authorized for Screen Time")
            return
        }
        
        let totalMinutes = dailyLimitMinutes + earnedTimeMinutes
        let commonApps = getCommonApps()

        // Restrict by bundle identifier directly; iOS doesn't expose ApplicationTokens
        // for apps that weren't picked through a FamilyActivityPicker.
        let selectedApps: Set<Application> = Set(appNames.compactMap { appName in
            commonApps[appName].map { Application(bundleIdentifier: $0) }
        })

        store.application.blockedApplications = selectedApps.isEmpty ? nil : selectedApps

        // Set up time-based restrictions using DeviceActivity
        configureDeviceActivity(limitMinutes: totalMinutes)
    }

    private func configureDeviceActivity(limitMinutes: Int) {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        let event = DeviceActivityEvent(threshold: DateComponents(minute: limitMinutes))

        do {
            // Requires a DeviceActivityMonitor extension target to receive the
            // threshold callback; this project doesn't have one yet, so monitoring
            // is scheduled but nothing currently reacts to it.
            try DeviceActivityCenter().startMonitoring(
                DeviceActivityName("screenTime"),
                during: schedule,
                events: [DeviceActivityEvent.Name("screenTimeLimit"): event]
            )
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

@available(iOS 16.0, *)
extension ScreenTimeHandler {

    func handleScreenTimeLimitReached(for applications: Set<Application>) {
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
