#!/bin/bash

# FocusPass iOS Screen Time Setup Script
# This script configures the iOS project for Screen Time API support

set -e

echo "🚀 Setting up iOS Screen Time support for FocusPass..."

# Check if we're on macOS (required for iOS development)
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  This script should be run on macOS for iOS development"
    echo "📝 Please follow the manual setup instructions instead"
    exit 1
fi

# Check if Xcode command line tools are installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode command line tools not found"
    echo "Please install Xcode and run: xcode-select --install"
    exit 1
fi

# Navigate to iOS directory
cd ios

echo "📱 Configuring iOS project..."

# 1. Install Ruby dependencies (for xcodeproj gem)
echo "💎 Installing Ruby dependencies..."
gem install xcodeproj

# 2. Update iOS deployment target in project files
echo "🔧 Updating iOS deployment target to 15.0..."

# Update in project.pbxproj using sed
if [[ -f "Runner.xcodeproj/project.pbxproj" ]]; then
    sed -i.bak 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9]*\.[0-9]*/IPHONEOS_DEPLOYMENT_TARGET = 15.0/g' Runner.xcodeproj/project.pbxproj
    echo "✅ Updated deployment target in project.pbxproj"
fi

# 3. Run the Ruby configuration script
if [[ -f "configure_ios_project.rb" ]]; then
    echo "🔧 Running iOS project configuration script..."
    ruby configure_ios_project.rb
else
    echo "⚠️  configure_ios_project.rb not found, skipping automated configuration"
fi

# 4. Install/update CocoaPods
echo "📦 Installing CocoaPods dependencies..."
if command -v pod &> /dev/null; then
    pod install --repo-update
else
    echo "⚠️  CocoaPods not installed. Installing..."
    sudo gem install cocoapods
    pod setup
    pod install
fi

# 5. Create Swift bridging header if it doesn't exist
BRIDGING_HEADER="Runner/Runner-Bridging-Header.h"
if [[ ! -f "$BRIDGING_HEADER" ]]; then
    echo "🌉 Creating Swift bridging header..."
    cat > "$BRIDGING_HEADER" << EOF
//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "GeneratedPluginRegistrant.h"
EOF
    echo "✅ Created bridging header"
fi

# 6. Update Info.plist with required permissions
echo "📝 Updating Info.plist permissions..."
/usr/libexec/PlistBuddy -c "Set :NSFamilyControlsUsageDescription 'FocusPass needs access to Screen Time to help parents manage their children'\''s app usage and enforce healthy screen time limits.'" Runner/Info.plist 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :NSFamilyControlsUsageDescription string 'FocusPass needs access to Screen Time to help parents manage their children'\''s app usage and enforce healthy screen time limits.'" Runner/Info.plist

/usr/libexec/PlistBuddy -c "Set :NSDeviceActivityReportExtensionUsageDescription 'FocusPass uses device activity reports to track app usage and provide screen time statistics.'" Runner/Info.plist 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :NSDeviceActivityReportExtensionUsageDescription string 'FocusPass uses device activity reports to track app usage and provide screen time statistics.'" Runner/Info.plist

/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion string 15.0" Runner/Info.plist 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 15.0" Runner/Info.plist

echo "✅ Updated Info.plist permissions"

# 7. Validate Swift files exist
SWIFT_FILES=("Runner/ScreenTimeHandler.swift" "Runner/ScreenTimeMethodChannel.swift")
for file in "${SWIFT_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ Found $file"
    else
        echo "⚠️  Missing $file - make sure all Swift files are in place"
    fi
done

# 8. Validate entitlements file
if [[ -f "Runner/Runner.entitlements" ]]; then
    echo "✅ Found entitlements file"
else
    echo "⚠️  Missing entitlements file"
fi

echo ""
echo "🎉 iOS Screen Time setup complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Open Runner.xcworkspace in Xcode (NOT Runner.xcodeproj)"
echo "2. Select the Runner target"
echo "3. Go to 'Signing & Capabilities' tab"
echo "4. Add 'App Groups' capability"
echo "5. Enable 'group.com.focuspass.shared' app group"
echo "6. Ensure your Apple Developer account has Family Controls entitlements"
echo "7. Test on a physical iOS device (iOS 15.0+)"
echo ""
echo "⚠️  IMPORTANT NOTES:"
echo "• Screen Time APIs require special Apple approval"
echo "• Family Controls only work on physical devices, not simulator"
echo "• You need an active Apple Developer Program membership"
echo "• Your app must be reviewed by Apple before Screen Time features work"
echo ""
echo "🔗 Useful Links:"
echo "• Apple Developer: https://developer.apple.com/documentation/familycontrols"
echo "• Screen Time Guide: https://developer.apple.com/documentation/screentime"
