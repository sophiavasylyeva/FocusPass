import Flutter
import UIKit
import SwiftUI
import FamilyControls

@available(iOS 16.0, *)
class ScreenTimeMethodChannel: NSObject, FlutterPlugin {
    
    private let screenTimeHandler = ScreenTimeHandler()
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.focuspass.screentime", binaryMessenger: registrar.messenger())
        let instance = ScreenTimeMethodChannel()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestAuthorization":
            handleRequestAuthorization(result: result)
            
        case "isAuthorized":
            handleIsAuthorized(result: result)
            
        case "configureRestrictions":
            handleConfigureRestrictions(call: call, result: result)
            
        case "getUsageStats":
            handleGetUsageStats(result: result)
            
        case "updateEarnedTime":
            handleUpdateEarnedTime(call: call, result: result)
            
        case "getEarnedTime":
            handleGetEarnedTime(result: result)
            
        case "resetDailyData":
            handleResetDailyData(result: result)
            
        case "getInstalledApps":
            handleGetInstalledApps(result: result)

        case "showActivityPicker":
            handleShowActivityPicker(result: result)

        case "applyFamilyActivitySelectionRestrictions":
            handleApplyFamilyActivitySelectionRestrictions(call: call, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Method Handlers
    
    private func handleRequestAuthorization(result: @escaping FlutterResult) {
        Task {
            let authorized = await screenTimeHandler.requestAuthorization()
            DispatchQueue.main.async {
                result(authorized)
            }
        }
    }
    
    private func handleIsAuthorized(result: @escaping FlutterResult) {
        let authorized = screenTimeHandler.isAuthorized()
        result(authorized)
    }
    
    private func handleConfigureRestrictions(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let apps = args["apps"] as? [String],
              let dailyLimitMinutes = args["dailyLimitMinutes"] as? Int,
              let earnedTimeMinutes = args["earnedTimeMinutes"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for configureRestrictions", details: nil))
            return
        }
        
        screenTimeHandler.configureRestrictions(
            appNames: apps,
            dailyLimitMinutes: dailyLimitMinutes,
            earnedTimeMinutes: earnedTimeMinutes
        )
        
        result(nil)
    }
    
    private func handleGetUsageStats(result: @escaping FlutterResult) {
        Task {
            let stats = await screenTimeHandler.getUsageStats()
            DispatchQueue.main.async {
                result(stats)
            }
        }
    }
    
    private func handleUpdateEarnedTime(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let minutes = args["minutes"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for updateEarnedTime", details: nil))
            return
        }
        
        screenTimeHandler.updateEarnedTime(minutes: minutes)
        result(nil)
    }
    
    private func handleGetEarnedTime(result: @escaping FlutterResult) {
        let earnedTime = screenTimeHandler.getEarnedTime()
        result(earnedTime)
    }
    
    private func handleResetDailyData(result: @escaping FlutterResult) {
        screenTimeHandler.resetDailyData()
        result(nil)
    }
    
    private func handleGetInstalledApps(result: @escaping FlutterResult) {
        Task {
            let apps = await screenTimeHandler.getInstalledApps()
            DispatchQueue.main.async {
                result(apps)
            }
        }
    }

    private func handleShowActivityPicker(result: @escaping FlutterResult) {
        // FamilyActivityPicker silently shows nothing selectable until the
        // user has granted Family Controls authorization, so request it
        // (triggering the system prompt on first use) before presenting.
        Task {
            let authorized = await screenTimeHandler.requestAuthorization()
            guard authorized else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "NOT_AUTHORIZED",
                        message: "Screen Time authorization was not granted",
                        details: nil
                    ))
                }
                return
            }
            DispatchQueue.main.async {
                self.presentActivityPicker(result: result)
            }
        }
    }

    private func presentActivityPicker(result: @escaping FlutterResult) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
            result(FlutterError(code: "NO_ROOT_VC", message: "No root view controller available", details: nil))
            return
        }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }

        let existingSelection = screenTimeHandler.loadFamilyActivitySelection() ?? FamilyActivitySelection()
        var didRespond = false

        let pickerView = ActivityPickerView(
            selection: existingSelection,
            onDone: { [weak self] selection in
                guard !didRespond else { return }
                didRespond = true
                self?.screenTimeHandler.saveFamilyActivitySelection(selection)
                let counts = self?.screenTimeHandler.selectionCounts(selection) ?? (apps: 0, categories: 0)
                top.presentedViewController?.dismiss(animated: true)
                result(["appCount": counts.apps, "categoryCount": counts.categories])
            },
            onCancel: {
                guard !didRespond else { return }
                didRespond = true
                top.presentedViewController?.dismiss(animated: true)
                result(nil)
            }
        )

        let hosting = UIHostingController(rootView: pickerView)
        hosting.modalPresentationStyle = .formSheet
        top.present(hosting, animated: true)
    }

    private func handleApplyFamilyActivitySelectionRestrictions(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let dailyLimitMinutes = args["dailyLimitMinutes"] as? Int,
              let earnedTimeMinutes = args["earnedTimeMinutes"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for applyFamilyActivitySelectionRestrictions", details: nil))
            return
        }

        screenTimeHandler.applyStoredFamilyActivitySelection(
            dailyLimitMinutes: dailyLimitMinutes,
            earnedTimeMinutes: earnedTimeMinutes
        )

        result(nil)
    }
}
