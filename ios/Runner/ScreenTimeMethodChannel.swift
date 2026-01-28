import Flutter
import UIKit

@available(iOS 15.0, *)
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
}
