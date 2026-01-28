import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register Screen Time method channel
    if #available(iOS 15.0, *) {
      ScreenTimeMethodChannel.register(with: registrar(forPlugin: "ScreenTimeMethodChannel")!)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
