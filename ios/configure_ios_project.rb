#!/usr/bin/env ruby

# iOS Project Configuration Script for FocusPass Screen Time Support
# This script automatically configures the iOS project with required frameworks and capabilities

require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main app target
main_target = project.targets.find { |target| target.name == 'Runner' }

puts "🔧 Configuring iOS project for Screen Time support..."

# 1. Add required frameworks
frameworks_to_add = [
  'FamilyControls',
  'DeviceActivity', 
  'ManagedSettings'
]

frameworks_to_add.each do |framework_name|
  framework_ref = project.frameworks_group.files.find { |file| file.display_name == "#{framework_name}.framework" }
  
  unless framework_ref
    framework_ref = project.frameworks_group.new_reference("System/Library/Frameworks/#{framework_name}.framework")
    framework_ref.source_tree = 'SDKROOT'
    
    main_target.frameworks_build_phase.add_file_reference(framework_ref)
    puts "✅ Added #{framework_name}.framework"
  else
    puts "ℹ️  #{framework_name}.framework already exists"
  end
end

# 2. Update build settings
main_target.build_configurations.each do |config|
  # Set minimum iOS deployment target to 15.0
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  
  # Add framework search paths
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '$(PROJECT_DIR)/Flutter/ephemeral/.symlinks/plugins'
  
  puts "✅ Updated build settings for #{config.name}"
end

# 3. Create entitlements file
entitlements_content = <<~PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.focuspass.shared</string>
    </array>
    <key>com.apple.developer.family-controls</key>
    <true/>
    <key>com.apple.developer.deviceactivity</key>
    <true/>
</dict>
</plist>
PLIST

entitlements_path = 'Runner/Runner.entitlements'
File.write(entitlements_path, entitlements_content)

# Add entitlements file to project
entitlements_ref = main_target.project.main_group.find_subpath('Runner', true).new_reference('Runner.entitlements')
entitlements_ref.last_known_file_type = 'text.plist.entitlements'

# Set code signing entitlements
main_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

puts "✅ Created and configured entitlements file"

# 4. Add Swift files to project
swift_files = [
  'ScreenTimeHandler.swift',
  'ScreenTimeMethodChannel.swift'
]

runner_group = main_target.project.main_group.find_subpath('Runner', true)

swift_files.each do |swift_file|
  file_ref = runner_group.files.find { |file| file.display_name == swift_file }
  
  unless file_ref
    file_ref = runner_group.new_reference(swift_file)
    file_ref.last_known_file_type = 'sourcecode.swift'
    
    main_target.source_build_phase.add_file_reference(file_ref)
    puts "✅ Added #{swift_file} to project"
  else
    puts "ℹ️  #{swift_file} already in project"
  end
end

# 5. Configure Swift version
main_target.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
end

# Save the project
project.save

puts ""
puts "🎉 iOS project configuration complete!"
puts ""
puts "⚠️  IMPORTANT: You still need to manually:"
puts "1. Open the project in Xcode"
puts "2. Add 'App Groups' capability in Signing & Capabilities"
puts "3. Enable 'group.com.focuspass.shared' app group"
puts "4. Configure your Apple Developer account for Family Controls"
puts "5. Test on a physical iOS device (Simulator won't work)"
puts ""
puts "📋 Next steps:"
puts "1. cd ios && ruby configure_ios_project.rb"
puts "2. Open Runner.xcworkspace in Xcode"
puts "3. Follow the manual configuration steps above"
