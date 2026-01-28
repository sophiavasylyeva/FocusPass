import DeviceActivity
import FamilyControls
import ManagedSettings

@available(iOS 15.0, *)
class DeviceActivityMonitor: DeviceActivityMonitor {
    
    let store = ManagedSettingsStore()
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        // Called when the screen time monitoring interval starts (e.g., beginning of day)
        print("Screen time monitoring started for activity: \(activity)")
        
        // Reset any previous restrictions at the start of a new interval
        store.clearAllSettings()
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        // Called when the screen time monitoring interval ends (e.g., end of day)
        print("Screen time monitoring ended for activity: \(activity)")
        
        // Clear restrictions at the end of the day
        store.clearAllSettings()
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // Called when screen time limit is reached for specific apps
        print("Screen time threshold reached for event: \(event) in activity: \(activity)")
        
        // Block the apps that have exceeded their limit
        if event == DeviceActivityEvent.Name("screenTimeLimit") {
            blockRestrictedApps()
        }
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        
        // Called when approaching the start of a monitoring interval
        print("Screen time interval will start warning for activity: \(activity)")
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        
        // Called when approaching the end of a monitoring interval
        print("Screen time interval will end warning for activity: \(activity)")
    }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        
        // Called when approaching screen time limit (usually 5 minutes before)
        print("Screen time threshold warning for event: \(event) in activity: \(activity)")
        
        // You could show a warning notification here
        showTimeWarningNotification()
    }
    
    // MARK: - Helper Methods
    
    private func blockRestrictedApps() {
        // Get the list of apps that should be blocked from UserDefaults
        let defaults = UserDefaults(suiteName: "group.com.focuspass.shared")
        let restrictedAppBundleIds = defaults?.array(forKey: "restrictedAppBundleIds") as? [String] ?? []
        
        // Convert bundle IDs to ApplicationTokens (this is simplified)
        // In a real implementation, you'd need to properly map bundle IDs to ApplicationTokens
        var blockedApps: Set<ApplicationToken> = []
        
        // For now, we'll use a simplified approach
        // The actual implementation would require getting ApplicationTokens from FamilyControls
        
        if !restrictedAppBundleIds.isEmpty {
            // Apply restrictions
            store.application.blockedApplications = blockedApps
            
            // Also block installation of new apps during restricted time
            store.application.denyAppInstallation = true
            
            print("Blocked \(blockedApps.count) apps due to screen time limits")
        }
    }
    
    private func showTimeWarningNotification() {
        // In a real implementation, you might:
        // 1. Send a local notification
        // 2. Show an alert
        // 3. Send data to your main app
        
        print("⚠️ Screen time limit approaching - 5 minutes remaining")
        
        // Store warning state for the main app to potentially display
        let defaults = UserDefaults(suiteName: "group.com.focuspass.shared")
        defaults?.set(Date(), forKey: "lastTimeWarning")
    }
    
    private func unblockAppsWithEarnedTime() {
        // Check if user has earned additional time through completing tasks
        let defaults = UserDefaults(suiteName: "group.com.focuspass.shared")
        let earnedTimeMinutes = defaults?.integer(forKey: "earnedTimeToday") ?? 0
        
        if earnedTimeMinutes > 0 {
            // Clear restrictions if user has earned time
            store.clearAllSettings()
            print("Unblocked apps due to earned time: \(earnedTimeMinutes) minutes")
            
            // You might want to set up a new monitoring schedule with extended time
            rescheduleWithEarnedTime(earnedMinutes: earnedTimeMinutes)
        }
    }
    
    private func rescheduleWithEarnedTime(earnedMinutes: Int) {
        // This would reschedule the DeviceActivity monitoring with updated time limits
        // Implementation would depend on your specific requirements
        print("Rescheduling with additional \(earnedMinutes) minutes of earned time")
    }
}

// MARK: - Extension for handling earned time updates

@available(iOS 15.0, *)
extension DeviceActivityMonitor {
    
    func handleEarnedTimeUpdate() {
        // Called when the main app updates earned time
        // Check if we should unblock apps
        unblockAppsWithEarnedTime()
    }
}
