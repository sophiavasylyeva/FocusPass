import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

/// Shared constants + persistence for the FamilyActivitySelection, used by
/// both the main app (Runner) and the DeviceActivityMonitorExtension, which
/// run as separate processes and can only communicate through the App Group.
@available(iOS 16.0, *)
enum FamilyActivityStore {
    static let suiteName = "group.com.focuspass.shared"
    static let selectionKey = "familyActivitySelectionData"

    static let activityName = DeviceActivityName("screenTime")
    static let eventName = DeviceActivityEvent.Name("screenTimeLimit")

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let defaults, let data = try? PropertyListEncoder().encode(selection) else { return }
        defaults.set(data, forKey: selectionKey)
    }

    static func loadSelection() -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: selectionKey) else { return nil }
        return try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    /// Blocks every app/category in the selection — the "earn-only" default state.
    static func shieldAll(_ selection: FamilyActivitySelection, using store: ManagedSettingsStore) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? ShieldSettings.ActivityCategoryPolicy.none
            : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
    }

    /// Clears the shield so earned time is immediately usable.
    static func unshieldAll(using store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.none
    }
}
