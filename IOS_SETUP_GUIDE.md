# iOS Screen Time Configuration Guide for FocusPass

This guide will help you configure the iOS project to support Screen Time APIs and Family Controls.

## Prerequisites

- **macOS with Xcode 13.0+** (iOS development requires macOS)
- **Apple Developer Program membership** (required for Family Controls)
- **iOS 15.0+ device for testing** (Simulator won't work for Screen Time APIs)

## 🚀 Quick Setup (Automated)

If you're on macOS, run the automated setup script:

```bash
cd /path/to/your/project
chmod +x setup_ios_screentime.sh
./setup_ios_screentime.sh
```

Then follow the "Manual Configuration in Xcode" section below.

## 📱 Manual Configuration Steps

### 1. Open Project in Xcode

```bash
cd ios
open Runner.xcworkspace  # NOT Runner.xcodeproj
```

### 2. Configure Build Settings

1. Select **Runner** project in the navigator
2. Select **Runner** target
3. Go to **Build Settings** tab
4. Set **iOS Deployment Target** to **15.0**
5. Set **Swift Language Version** to **5**

### 3. Add Required Frameworks

1. Go to **Build Phases** tab
2. Expand **Link Binary With Libraries**
3. Click **+** and add:
   - `FamilyControls.framework`
   - `DeviceActivity.framework`
   - `ManagedSettings.framework`

### 4. Configure Signing & Capabilities

1. Go to **Signing & Capabilities** tab
2. Ensure you have a valid **Team** selected
3. Click **+ Capability** and add:
   - **App Groups**
   - **Family Controls** (may need to be requested from Apple)

4. For **App Groups**:
   - Enable: `group.com.focuspass.shared`
   - If it doesn't exist, create it in Apple Developer Console

### 5. Add Swift Files to Project

1. In Xcode, right-click on **Runner** folder
2. Select **Add Files to "Runner"**
3. Add these files:
   - `ScreenTimeHandler.swift`
   - `ScreenTimeMethodChannel.swift`
4. Ensure **Target Membership** includes **Runner**

### 6. Configure Entitlements

1. The `Runner.entitlements` file should be automatically recognized
2. Verify it contains:
   - `com.apple.security.application-groups`
   - `com.apple.developer.family-controls`
   - `com.apple.developer.deviceactivity`

### 7. Update Info.plist

Verify these keys exist in `Runner/Info.plist`:

```xml
<key>NSFamilyControlsUsageDescription</key>
<string>FocusPass needs access to Screen Time to help parents manage their children's app usage and enforce healthy screen time limits.</string>

<key>NSDeviceActivityReportExtensionUsageDescription</key>
<string>FocusPass uses device activity reports to track app usage and provide screen time statistics.</string>

<key>LSMinimumSystemVersion</key>
<string>15.0</string>
```

### 8. Configure Bundle Identifier

1. Ensure your Bundle Identifier matches your Apple Developer Console app
2. It should be something like: `com.yourcompany.focuspass`
3. This Bundle ID must be registered in Apple Developer Console with Family Controls entitlements

## 🔧 Advanced Configuration

### App Groups Setup in Apple Developer Console

1. Go to [Apple Developer Console](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Identifiers** → **App Groups**
4. Create new App Group: `group.com.focuspass.shared`
5. Add this App Group to your App ID

### Family Controls Entitlement Request

1. Family Controls requires special approval from Apple
2. Submit a request through Apple Developer Console
3. Explain your app's purpose and how it will use Screen Time APIs
4. This process can take several weeks

### Provisioning Profile Configuration

1. Create/update your Provisioning Profile
2. Ensure it includes:
   - Family Controls entitlement
   - App Groups capability
   - Your registered devices

## 🧪 Testing

### Build and Test

1. Connect an iOS 15.0+ device
2. Select your device in Xcode
3. Build and run the app
4. Test Screen Time authorization flow

### Debugging

- Use Xcode Console to view debug logs
- Screen Time APIs only work on physical devices
- Check entitlements in device logs

## 🚨 Common Issues and Solutions

### "Family Controls not available"
- Ensure iOS 15.0+ device
- Check Apple Developer Console for entitlements
- Verify provisioning profile includes Family Controls

### "App Groups not working"
- Verify App Group ID in both Xcode and Developer Console
- Check entitlements file syntax
- Ensure all targets use the same App Group

### "Method channel not found"
- Verify Swift files are added to Xcode project
- Check that `ScreenTimeMethodChannel.register` is called in AppDelegate
- Ensure proper target membership for Swift files

### Build Errors
- Clean build folder: `Product` → `Clean Build Folder`
- Delete derived data: `Window` → `Organizer` → `Projects` → Delete derived data
- Update CocoaPods: `cd ios && pod update`

## 📋 Verification Checklist

Before testing, verify:

- [ ] iOS Deployment Target set to 15.0
- [ ] All three frameworks linked
- [ ] App Groups capability added
- [ ] Entitlements file configured
- [ ] Swift files added to project
- [ ] Info.plist permissions added
- [ ] Bundle ID matches Developer Console
- [ ] Provisioning profile includes entitlements
- [ ] Testing on physical iOS 15.0+ device

## 🔗 Apple Documentation

- [Family Controls Framework](https://developer.apple.com/documentation/familycontrols)
- [Screen Time API](https://developer.apple.com/documentation/screentime)
- [Device Activity Framework](https://developer.apple.com/documentation/deviceactivity)
- [Managed Settings](https://developer.apple.com/documentation/managedsettings)

## 📞 Support

If you encounter issues:

1. Check Apple Developer Forums
2. Review Xcode build logs
3. Verify all configuration steps above
4. Ensure Apple Developer Program membership is active

---

**Note**: Screen Time APIs are complex and require proper Apple Developer Program setup. Allow extra time for Apple's review process for Family Controls entitlements.
