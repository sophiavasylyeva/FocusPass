import DeviceActivity
import FamilyControls
import ManagedSettings

/// Reacts to the schedule set up by ScreenTimeHandler.configureDeviceActivityForSelection.
/// Runs in its own process (separate from Runner), so it can only see the
/// FamilyActivitySelection via the shared App Group (FamilyActivityStore).
@available(iOS 16.0, *)
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == FamilyActivityStore.activityName else { return }

        // Start of a new day: back to the earn-only default — everything shielded
        // until the child gets an activity approved.
        if let selection = FamilyActivityStore.loadSelection() {
            FamilyActivityStore.shieldAll(selection, using: store)
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == FamilyActivityStore.activityName, event == FamilyActivityStore.eventName else { return }

        // The child has used up everything they've earned for today — re-shield.
        if let selection = FamilyActivityStore.loadSelection() {
            FamilyActivityStore.shieldAll(selection, using: store)
        }
    }
}
