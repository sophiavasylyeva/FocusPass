//
//
// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/services.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:usage_stats/usage_stats.dart';
// import 'package:installed_apps/installed_apps.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'notification_service.dart';
// import 'educational_task_service.dart';
// import 'app_interception_service.dart';
//
// class ScreenTimeService {
//   // Storage keys now include child name for isolation
//   static const String _dailyUsageKey = 'daily_usage_';
//   static const String _lastResetKey = 'last_reset_';
//   static const String _screenTimeRulesKey = 'screen_time_rules_';
//   static const String _restrictedAppsKey = 'restricted_apps_';
//   static const String _earnedTimeKey = 'earned_time_';
//   static const String _trackingStartKey = 'tracking_start_';
//
//   // Track current session
//   static Timer? _monitoringTimer;
//   static Timer? _resetTimer;
//   static Map<String, int> _dailyUsage = {};
//   static Map<String, double> _screenTimeRules = {};
//   static List<String> _restrictedApps = [];
//   static double _earnedTimeToday = 0;
//   static String? _currentFocusedApp;
//   static String? _lastKnownDate;
//   static String? _currentChildName;
//   static final NotificationService _notificationService = NotificationService();
//
//   // Tracking start times for each app (when we started tracking today)
//   static Map<String, int> _trackingStartTimes = {};
//
//   // Apps that have reached their limit (stop tracking these)
//   static Set<String> _blockedApps = {};
//
//   /// Initialize the screen time service
//   static Future<void> initialize() async {
//     print('ScreenTimeService: Starting initialization...');
//
//     await _requestPermissions();
//     print('ScreenTimeService: Permissions requested');
//
//     // Load stored data first (includes child-specific data)
//     await _loadStoredData();
//     print('ScreenTimeService: Stored data loaded');
//
//     // Sync with Firestore to get parent's rules
//     // This will override any local rules with parent's settings
//     try {
//       await _syncWithFirestore();
//       print('ScreenTimeService: Firestore sync completed - rules updated from parent account');
//     } catch (e) {
//       print('ScreenTimeService: Firestore sync failed, using stored or default rules: $e');
//       // If sync fails and no stored rules, set defaults
//       if (_screenTimeRules.isEmpty || !_screenTimeRules.containsKey('dailyLimit')) {
//         _setDefaultRulesForTesting();
//       }
//     }
//
//     // Initialize notification service
//     await _notificationService.initialize();
//     print('ScreenTimeService: Notification service initialized');
//
//     _startMonitoring();
//     print('ScreenTimeService: Monitoring started');
//
//     // Initialize app interception service
//     await AppInterceptionService.initialize();
//     print('ScreenTimeService: App interception service initialized');
//
//     _scheduleDailyReset();
//     print('ScreenTimeService: Daily reset timer scheduled');
//   }
//
//   /// Set default rules for testing when Firebase is unavailable
//   static void _setDefaultRulesForTesting() {
//     // Default to 1 hour daily limit to match parent's unified settings
//     _screenTimeRules['dailyLimit'] = 1.0 * 60 * 60 * 1000; // 1 hour in milliseconds
//     _screenTimeRules['ratio'] = 3.0; // 3x ratio (5 min learning = 15 min screen time)
//     _restrictedApps = ['com.google.android.youtube', 'com.instagram.android', 'com.zhiliaoapp.musically', 'com.snapchat.android', 'com.twitter.android'];
//     print('ScreenTimeService: Default testing rules set - 1 hour limit, 3x ratio');
//   }
//
//   /// Map app display names to package names
//   static Map<String, String> _getAppPackageMap() {
//     return {
//       'YouTube': 'com.google.android.youtube',
//       'YouTube Shorts': 'com.google.android.youtube',
//       'Instagram': 'com.instagram.android',
//       'TikTok': 'com.zhiliaoapp.musically',
//       'Snapchat': 'com.snapchat.android',
//       'X (Twitter)': 'com.twitter.android',
//       'Twitter': 'com.twitter.android',
//     };
//   }
//
//   /// Request necessary permissions
//   static Future<void> _requestPermissions() async {
//     if (!await Permission.systemAlertWindow.isGranted) {
//       await Permission.systemAlertWindow.request();
//     }
//   }
//
//   /// Check if usage stats permission is granted
//   static Future<bool> hasUsageStatsPermission() async {
//     try {
//       final endTime = DateTime.now();
//       final startTime = endTime.subtract(const Duration(days: 1));
//       final stats = await UsageStats.queryUsageStats(startTime, endTime);
//
//       print('ScreenTimeService: Permission check - found ${stats.length} usage stats');
//
//       // More permissive check - if we can query stats at all, consider permission granted
//       if (stats.isNotEmpty) {
//         print('ScreenTimeService: Permission appears to be granted');
//         return true;
//       }
//
//       print('ScreenTimeService: No usage stats found - permission likely denied');
//       return false;
//     } catch (e) {
//       print('ScreenTimeService: Usage stats permission check failed: $e');
//       return false;
//     }
//   }
//
//   /// Open usage stats settings for the user to grant permission
//   static Future<void> openUsageStatsSettings() async {
//     try {
//       const platform = MethodChannel('com.focuspass.app_blocker');
//       await platform.invokeMethod('openUsageStatsSettings');
//     } catch (e) {
//       print('Error opening usage stats settings: $e');
//     }
//   }
//
//   /// Load stored data from SharedPreferences
//   static Future<void> _loadStoredData() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     // Get current child name
//     _currentChildName = await _getCurrentChildName();
//     if (_currentChildName == null) {
//       print('ScreenTimeService: No child name set, cannot load data');
//       return;
//     }
//
//     // Check if we need to reset daily usage (new day)
//     final lastResetKey = '${_lastResetKey}$_currentChildName';
//     final lastReset = prefs.getString(lastResetKey);
//     final today = DateTime.now().toIso8601String().split('T')[0];
//     _lastKnownDate = today;
//
//     print('ScreenTimeService: Loading data for child: $_currentChildName');
//     print('ScreenTimeService: Last reset: $lastReset, Today: $today');
//
//     if (lastReset != today) {
//       print('ScreenTimeService: New day detected, performing reset');
//       await _resetDailyUsage();
//     } else {
//       print('ScreenTimeService: Same day, loading existing data');
//
//       // Load daily usage for this child
//       final usageKey = '$_dailyUsageKey${_currentChildName}_$today';
//       final usageJson = prefs.getString(usageKey);
//       if (usageJson != null) {
//         try {
//           final Map<String, dynamic> decoded = json.decode(usageJson);
//           _dailyUsage = decoded.map((key, value) => MapEntry(key, value as int));
//           print('ScreenTimeService: Loaded daily usage for $_currentChildName: $_dailyUsage');
//         } catch (e) {
//           print('ScreenTimeService: Error loading daily usage, resetting: $e');
//           await _resetDailyUsage();
//           return;
//         }
//       }
//
//       // Load tracking start times for this child
//       final trackingKey = '$_trackingStartKey${_currentChildName}_$today';
//       final trackingJson = prefs.getString(trackingKey);
//       if (trackingJson != null) {
//         try {
//           final Map<String, dynamic> decoded = json.decode(trackingJson);
//           _trackingStartTimes = decoded.map((key, value) => MapEntry(key, value as int));
//           print('ScreenTimeService: Loaded tracking start times for $_currentChildName');
//         } catch (e) {
//           print('ScreenTimeService: Error loading tracking start times: $e');
//           _trackingStartTimes.clear();
//         }
//       }
//
//       // Load blocked apps for this child
//       final blockedKey = 'blocked_apps_${_currentChildName}_$today';
//       final blockedList = prefs.getStringList(blockedKey);
//       if (blockedList != null) {
//         _blockedApps = blockedList.toSet();
//         print('ScreenTimeService: Loaded blocked apps for $_currentChildName: $_blockedApps');
//       }
//
//       // Validate loaded data
//       await _validateAndFixData();
//     }
//
//     // Load screen time rules for this child
//     final rulesKey = '$_screenTimeRulesKey$_currentChildName';
//     final rulesJson = prefs.getString(rulesKey);
//     if (rulesJson != null) {
//       final Map<String, dynamic> decoded = json.decode(rulesJson);
//       _screenTimeRules = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
//     }
//
//     // Load restricted apps for this child
//     final restrictedKey = '$_restrictedAppsKey$_currentChildName';
//     final restrictedJson = prefs.getString(restrictedKey);
//     if (restrictedJson != null) {
//       _restrictedApps = List<String>.from(json.decode(restrictedJson));
//     }
//
//     // Load earned time for this child
//     final earnedKey = '$_earnedTimeKey${_currentChildName}_$today';
//     final earnedTime = prefs.getDouble(earnedKey) ?? 0.0;
//     _earnedTimeToday = earnedTime;
//   }
//
//   /// Validate and fix any corrupted data
//   static Future<void> _validateAndFixData() async {
//     bool needsReset = false;
//
//     // Check for suspicious usage values
//     for (final entry in _dailyUsage.entries) {
//       final usageMinutes = entry.value / (1000 * 60);
//       if (usageMinutes > 1440) { // More than 24 hours
//         print('ScreenTimeService: Detected invalid usage for ${entry.key}: ${usageMinutes.toStringAsFixed(1)} minutes - forcing reset');
//         needsReset = true;
//         break;
//       }
//     }
//
//     if (needsReset) {
//       await _resetDailyUsage();
//     }
//   }
//
//   /// Sync with Firestore to get latest rules and restrictions
//   static Future<void> _syncWithFirestore() async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) return;
//
//       final childName = await _getCurrentChildName();
//       if (childName == null) return;
//
//       // Get screen time rules from parent's settings
//       final parentQuery = await FirebaseFirestore.instance
//           .collectionGroup('children')
//           .where('name', isEqualTo: childName)
//           .get();
//
//       if (parentQuery.docs.isNotEmpty) {
//         final childDoc = parentQuery.docs.first;
//         final parentUid = childDoc.reference.parent.parent!.id;
//
//         // Get parent's screen time rules
//         final rulesDoc = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(parentUid)
//             .collection('settings')
//             .doc('screenTimeRules')
//             .get();
//
//         if (rulesDoc.exists) {
//           final rulesData = rulesDoc.data()!;
//           double dailyLimit = 1.0; // default to 1 hour
//           double ratio = 3.0; // default 3x (5 min learning = 15 min screen time)
//
//           if (rulesData['applySameForAll'] == true) {
//             // Use unified rules for all children
//             dailyLimit = (rulesData['unifiedRules']?['limit'] ?? 1.0).toDouble();
//             ratio = (rulesData['unifiedRules']?['ratio'] ?? 3.0).toDouble();
//             print('ScreenTimeService: Using unified rules - Limit: ${dailyLimit}h, Ratio: ${ratio}x');
//           } else {
//             // Use individual rules for this child
//             final childrenRules = rulesData['children'] as Map<String, dynamic>? ?? {};
//             dailyLimit = (childrenRules[childName]?['limit'] ?? 1.0).toDouble();
//             ratio = (childrenRules[childName]?['ratio'] ?? 3.0).toDouble();
//             print('ScreenTimeService: Using individual rules for $childName - Limit: ${dailyLimit}h, Ratio: ${ratio}x');
//           }
//
//           // Convert hours to milliseconds and store ratio
//           _screenTimeRules['dailyLimit'] = dailyLimit * 60 * 60 * 1000;
//           _screenTimeRules['ratio'] = ratio;
//         } else {
//           // No rules document exists, use defaults
//           print('ScreenTimeService: No rules found, using defaults - 1 hour limit, 3x ratio');
//           _screenTimeRules['dailyLimit'] = 1.0 * 60 * 60 * 1000;
//           _screenTimeRules['ratio'] = 3.0;
//         }
//
//         // Get restricted apps from child data
//         final childData = childDoc.data();
//         final selectedAppNames = List<String>.from(childData['selectedApps'] ?? []);
//         final Set<String> packagesToRestrict = {};
//         final Map<String, String> appPackageMap = _getAppPackageMap();
//
//         // Check if any web-based apps are selected
//         const webBasedApps = {'YouTube', 'TikTok', 'Netflix', 'Instagram', 'X (Twitter)', 'Twitter'};
//         bool shouldBlockBrowsers = false;
//
//         for (final appName in selectedAppNames) {
//           if (appPackageMap.containsKey(appName)) {
//             packagesToRestrict.add(appPackageMap[appName]!);
//           } else {
//             packagesToRestrict.add(appName);
//           }
//
//           // Check if this is a web-based app
//           if (webBasedApps.contains(appName)) {
//             shouldBlockBrowsers = true;
//           }
//         }
//
//         // Add browsers to prevent web access loophole
//         if (shouldBlockBrowsers) {
//           print('ScreenTimeService: Adding browsers to block web access loophole');
//           packagesToRestrict.add('com.android.chrome');
//           packagesToRestrict.add('com.sec.android.app.sbrowser'); // Samsung Internet
//           packagesToRestrict.add('org.mozilla.firefox');
//           packagesToRestrict.add('com.microsoft.emmx'); // Edge
//           packagesToRestrict.add('com.opera.browser');
//         }
//
//         _restrictedApps = packagesToRestrict.toList();
//
//         print('ScreenTimeService: Loaded rules for $childName:');
//         print('  Daily limit: ${_screenTimeRules['dailyLimit']! / (60 * 60 * 1000)} hours');
//         print('  Ratio: ${_screenTimeRules['ratio']}x');
//         print('  Restricted apps: $_restrictedApps');
//
//         await _saveToPreferences();
//       } else {
//         // Child not found in any parent's collection, use defaults
//         print('ScreenTimeService: Child $childName not found in parent records, using defaults');
//         _screenTimeRules['dailyLimit'] = 1.0 * 60 * 60 * 1000;
//         _screenTimeRules['ratio'] = 3.0;
//       }
//     } catch (e) {
//       print('Error syncing with Firestore: $e');
//       // Use defaults if sync fails
//       _screenTimeRules['dailyLimit'] = 1.0 * 60 * 60 * 1000;
//       _screenTimeRules['ratio'] = 3.0;
//     }
//   }
//
//   /// Get current child name from stored preferences
//   static Future<String?> _getCurrentChildName() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('current_child_name');
//   }
//
//   /// Set current child name
//   static Future<void> setCurrentChildName(String childName) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('current_child_name', childName);
//
//     // If child name changed, reload data for the new child
//     if (_currentChildName != childName) {
//       _currentChildName = childName;
//       print('ScreenTimeService: Switching to child: $childName');
//
//       // Clear current data
//       _dailyUsage.clear();
//       _trackingStartTimes.clear();
//       _blockedApps.clear();
//       _earnedTimeToday = 0;
//
//       // Load data for the new child
//       await _loadStoredData();
//     }
//   }
//
//   /// Start monitoring app usage
//   static void _startMonitoring() {
//     _monitoringTimer?.cancel();
//     _monitoringTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
//       await _checkCurrentAppUsage();
//       _checkForDayChange();
//     });
//   }
//
//   /// Schedule automatic daily reset at midnight
//   static void _scheduleDailyReset() {
//     _resetTimer?.cancel();
//
//     final now = DateTime.now();
//     final nextMidnight = DateTime(now.year, now.month, now.day + 1);
//     final timeUntilMidnight = nextMidnight.difference(now);
//
//     print('ScreenTimeService: Scheduling reset in ${timeUntilMidnight.inHours}h ${timeUntilMidnight.inMinutes % 60}m');
//
//     _resetTimer = Timer(timeUntilMidnight, () async {
//       print('ScreenTimeService: Midnight reset triggered');
//       await performDailyReset();
//       _scheduleDailyReset();
//     });
//   }
//
//   /// Check if day has changed during monitoring
//   static void _checkForDayChange() {
//     final currentDate = DateTime.now().toIso8601String().split('T')[0];
//
//     if (_lastKnownDate != null && _lastKnownDate != currentDate) {
//       print('ScreenTimeService: Day change detected during monitoring');
//       performDailyReset();
//     }
//
//     _lastKnownDate = currentDate;
//   }
//
//   /// Convert value to int safely
//   static int _asInt(dynamic v) {
//     if (v == null) return 0;
//     if (v is int) return v;
//     if (v is double) return v.toInt();
//     if (v is String) return int.tryParse(v) ?? 0;
//     return 0;
//   }
//
//   /// Check current app usage and enforce restrictions
//   static Future<void> _checkCurrentAppUsage() async {
//     try {
//       if (!await hasUsageStatsPermission()) {
//         print('ScreenTimeService: No usage stats permission, skipping check');
//         return;
//       }
//
//       if (_currentChildName == null) {
//         print('ScreenTimeService: No child name set, skipping check');
//         return;
//       }
//
//       final endTime = DateTime.now();
//       final startTime = DateTime(endTime.year, endTime.month, endTime.day);
//
//       final List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startTime, endTime);
//
//       // Check if educational tasks are completed
//       final hasCompletedTasks = _earnedTimeToday > 0;
//       final ratio = _screenTimeRules['ratio'] ?? 3.0;
//       final sessionTimeMs = hasCompletedTasks ? (5 * ratio * 60 * 1000) : 0; // 5 min learning * ratio
//       final dailyLimitMs = _screenTimeRules['dailyLimit'] ?? (1 * 60 * 60 * 1000);
//
//       bool hasChanges = false;
//
//       // Track combined usage for web-based apps (app + browser)
//       Map<String, int> combinedUsage = {};
//
//       for (final stat in usageStats) {
//         final packageName = stat.packageName ?? '';
//
//         if (!_restrictedApps.contains(packageName)) continue;
//
//         // Skip tracking if app has reached daily limit
//         if (_blockedApps.contains(packageName)) {
//           print('ScreenTimeService: $packageName already at daily limit, skipping tracking');
//           continue;
//         }
//
//         final usageTimeRaw = stat.totalTimeInForeground ?? 0;
//         int systemUsageTime = _asInt(usageTimeRaw);
//
//         // Initialize tracking start time if not set
//         if (!_trackingStartTimes.containsKey(packageName)) {
//           _trackingStartTimes[packageName] = systemUsageTime;
//           print('ScreenTimeService: Started tracking $packageName for $_currentChildName at ${systemUsageTime}ms');
//         }
//
//         // Calculate usage since we started tracking
//         final trackingStart = _trackingStartTimes[packageName] ?? systemUsageTime;
//         final relativeUsage = (systemUsageTime - trackingStart).clamp(0, double.maxFinite.toInt());
//
//         // For browsers, accumulate usage to the appropriate web app
//         if (_isBrowser(packageName)) {
//           // Add browser usage to YouTube tracking (since YouTube is the main web-based app)
//           final youtubePackage = 'com.google.android.youtube';
//           if (_restrictedApps.contains(youtubePackage)) {
//             combinedUsage[youtubePackage] = (combinedUsage[youtubePackage] ?? 0) + relativeUsage;
//             print('ScreenTimeService: Adding browser usage to YouTube tracking: ${(relativeUsage / (1000 * 60)).round()}m');
//           }
//         } else {
//           // Regular app usage
//           combinedUsage[packageName] = relativeUsage;
//         }
//       }
//
//       // Process combined usage
//       for (final entry in combinedUsage.entries) {
//         final packageName = entry.key;
//         final relativeUsage = entry.value;
//
//         // Update daily usage if it increased
//         final previousUsage = _dailyUsage[packageName] ?? 0;
//         if (relativeUsage != previousUsage) {
//           _dailyUsage[packageName] = relativeUsage;
//           hasChanges = true;
//
//           final usedMinutes = (relativeUsage / (1000 * 60)).round();
//           print('ScreenTimeService: Updated $packageName usage for $_currentChildName: ${usedMinutes}m');
//
//           // Check blocking conditions based on total available time (daily + earned)
//           final earnedMs = (_earnedTimeToday * 60 * 1000).toInt();
//           final totalLimitMs = dailyLimitMs + earnedMs;
//
//           if (relativeUsage >= totalLimitMs) {
//             // Total limit (daily + earned) reached -> BLOCK for today
//             print('ScreenTimeService: $packageName reached TOTAL LIMIT for $_currentChildName');
//             _blockedApps.add(packageName);
//             await _showDailyLimitReachedNotification(packageName);
//             await _forceCloseApp(packageName);
//             if (_isWebBasedApp(packageName)) {
//               await _blockBrowsers();
//             }
//             continue;
//           } else if (relativeUsage >= dailyLimitMs && earnedMs > 0) {
//             // Using earned time now -> show warnings near the end of earned time
//             final remainingTotalMs = totalLimitMs - relativeUsage;
//             final remainingTotalMinutes = (remainingTotalMs / (1000 * 60)).round();
//             if (remainingTotalMinutes <= 5 && remainingTotalMinutes > 0) {
//               await _showSessionWarningNotification(packageName, remainingTotalMinutes);
//             }
//           } else {
//             // Still within daily limit -> show warning when close to daily limit
//             final remainingDailyMs = dailyLimitMs - relativeUsage;
//             final remainingDailyMinutes = (remainingDailyMs / (1000 * 60)).round();
//             if (remainingDailyMinutes <= 5 && remainingDailyMinutes > 0) {
//               await _showSessionWarningNotification(packageName, remainingDailyMinutes);
//             }
//           }
//         }
//       }
//
//       if (hasChanges) {
//         await _saveToPreferences();
//       }
//     } catch (e) {
//       print('ScreenTimeService: Error checking app usage: $e');
//     }
//   }
//
//   /// Check if a package is a browser
//   static bool _isBrowser(String packageName) {
//     const browsers = {
//       'com.android.chrome',
//       'com.sec.android.app.sbrowser',
//       'org.mozilla.firefox',
//       'com.microsoft.emmx',
//       'com.opera.browser',
//     };
//     return browsers.contains(packageName);
//   }
//
//   /// Check if app has web version
//   static bool _isWebBasedApp(String packageName) {
//     const webBasedApps = {
//       'com.google.android.youtube',
//       'com.instagram.android',
//       'com.zhiliaoapp.musically',
//       'com.twitter.android',
//       'com.netflix.mediaclient',
//     };
//     return webBasedApps.contains(packageName);
//   }
//
//   /// Block all browsers
//   static Future<void> _blockBrowsers() async {
//     const browsers = [
//       'com.android.chrome',
//       'com.sec.android.app.sbrowser',
//       'org.mozilla.firefox',
//       'com.microsoft.emmx',
//       'com.opera.browser',
//     ];
//
//     for (final browser in browsers) {
//       await _forceCloseApp(browser);
//     }
//   }
//
//   /// Get app name from package name
//   static Future<String?> _getAppNameFromPackage(String packageName) async {
//     final knownApps = {
//       'com.google.android.youtube': 'YouTube',
//       'com.instagram.android': 'Instagram',
//       'com.zhiliaoapp.musically': 'TikTok',
//       'com.snapchat.android': 'Snapchat',
//       'com.twitter.android': 'Twitter',
//       'com.facebook.katana': 'Facebook',
//       'com.whatsapp': 'WhatsApp',
//       'com.spotify.music': 'Spotify',
//       'com.netflix.mediaclient': 'Netflix',
//       'com.discord': 'Discord',
//     };
//
//     if (knownApps.containsKey(packageName)) {
//       return knownApps[packageName];
//     }
//
//     try {
//       final apps = await InstalledApps.getInstalledApps(true, true);
//       final app = apps.firstWhere(
//             (app) => app.packageName == packageName,
//         orElse: () => throw Exception('App not found'),
//       );
//       return app.name;
//     } catch (e) {
//       return null;
//     }
//   }
//
//   /// Check if app usage has exceeded the daily limit
//   static bool _isAppUsageExceeded(String packageName, int usageTimeMs) {
//     final dailyLimitMs = _screenTimeRules['dailyLimit'] ?? (1 * 60 * 60 * 1000);
//     // App is exceeded if usage is greater than or equal to the fixed daily limit
//     return usageTimeMs >= dailyLimitMs;
//   }
//
//   /// Block an app
//   static Future<void> _blockApp(String packageName, String appName) async {
//     try {
//       await _showBlockingOverlay(appName);
//     } catch (e) {
//       print('Error blocking app: $e');
//     }
//   }
//
//   /// Show blocking overlay with exit app button
//   static Future<void> _showBlockingOverlay(String appName) async {
//     const platform = MethodChannel('com.focuspass.app_blocker');
//     try {
//       await platform.invokeMethod('showBlockingOverlay', {
//         'appName': appName,
//         'message': 'Time limit reached for $appName.',
//         'showExitButton': true,
//         'exitButtonText': 'Exit $appName',
//       });
//     } catch (e) {
//       print('Error showing blocking overlay: $e');
//     }
//   }
//
//   /// Force close the current app
//   static Future<void> _forceCloseApp(String packageName) async {
//     const platform = MethodChannel('com.focuspass.app_blocker');
//     try {
//       await platform.invokeMethod('forceCloseApp', {
//         'packageName': packageName,
//       });
//       print('ScreenTimeService: Force closed app: $packageName');
//     } catch (e) {
//       print('Error force closing app: $e');
//       // Fallback to showing blocking overlay
//       await _showBlockingOverlay(packageName);
//     }
//   }
//
//   /// Grant app access after completing educational tasks
//   static Future<void> addEarnedTime(double minutes) async {
//     // Accumulate earned minutes (applies on top of the daily limit)
//     _earnedTimeToday += minutes;
//
//     if (_currentChildName == null) {
//       print('ScreenTimeService: Cannot save earned time - no child name set');
//       return;
//     }
//
//     final prefs = await SharedPreferences.getInstance();
//     final today = DateTime.now().toIso8601String().split('T')[0];
//     await prefs.setDouble('$_earnedTimeKey${_currentChildName}_$today', _earnedTimeToday);
//
//     print('ScreenTimeService: Added $minutes minutes earned for $_currentChildName');
//     print('  Total earned today: $_earnedTimeToday minutes (adds to daily limit)');
//
//     await AppInterceptionService.checkTaskCompletionAndUpdateAccess();
//   }
//
//   /// Called when educational tasks are completed
//   static Future<void> onEducationalTasksCompleted() async {
//     final childName = await _getCurrentChildName();
//     if (childName == null) return;
//
//     print('ScreenTimeService: Educational tasks completed for $childName');
//
//     final taskService = EducationalTaskService();
//     final hasPendingTasks = await taskService.hasPendingTasks(childName);
//
//     if (!hasPendingTasks) {
//       await AppInterceptionService.clearAllInterceptions();
//       await _notificationService.showTasksCompletedNotification();
//
//       final stats = getCurrentUsageStats();
//       for (final app in _restrictedApps) {
//         final appStats = stats[app];
//         if (appStats != null) {
//           final remainingMs = appStats['remainingTime'] as double? ?? 0.0;
//           final remainingMinutes = (remainingMs / (1000 * 60)).round();
//
//           if (remainingMinutes > 0) {
//             await _notificationService.showAppAccessGrantedNotification(
//               appName: app,
//               remainingMinutes: remainingMinutes,
//             );
//           }
//         }
//       }
//
//       print('ScreenTimeService: All apps unlocked');
//     }
//   }
//
//   /// Get current usage statistics
//   static Map<String, dynamic> getCurrentUsageStats() {
//     final dailyLimitMs = (_screenTimeRules['dailyLimit'] ?? (1 * 60 * 60 * 1000)).toDouble();
//
//     // Earned minutes (from completed tasks) add on top of daily limit
//     final earnedMs = (_earnedTimeToday * 60 * 1000).toDouble();
//     final hasEarnedTime = earnedMs > 0;
//
//     Map<String, dynamic> stats = {};
//
//     // Create stats for each restricted app
//     for (final packageName in _restrictedApps) {
//       final usageMs = (_dailyUsage[packageName] ?? 0).toDouble();
//
//       // Total available today = daily limit + earned time
//       final totalLimitMs = dailyLimitMs + earnedMs;
//
//       final remainingTime = (totalLimitMs - usageMs).clamp(0.0, double.infinity);
//       final isBlocked = usageMs >= totalLimitMs;
//
//       stats[packageName] = {
//         'usedTime': usageMs.toInt(),
//         'remainingTime': remainingTime,
//         'sessionTime': earnedMs.toInt(), // Treat earned as extra session on top of daily limit
//         'sessionRemaining': (totalLimitMs - usageMs - (dailyLimitMs - usageMs).clamp(0.0, double.infinity)).clamp(0.0, double.infinity),
//         'dailyLimit': dailyLimitMs.toInt(),
//         'earnedTime': earnedMs, // expose for unified service consumers
//         'isBlocked': isBlocked,
//         'hasCompletedTasks': hasEarnedTime,
//         'needsTasks': (usageMs >= dailyLimitMs) && earnedMs <= 0,
//         'dailyLimitReached': usageMs >= dailyLimitMs,
//         'childName': _currentChildName ?? 'Unknown',
//       };
//     }
//
//     // Also create entries for display names
//     return _createStatsForSelectedApps(stats, dailyLimitMs, earnedMs);
//   }
//
//   /// Create stats entries for display names
//   static Map<String, dynamic> _createStatsForSelectedApps(Map<String, dynamic> packageStats, double dailyLimitMs, double earnedScreenTimeMs) {
//     Map<String, dynamic> displayStats = Map.from(packageStats);
//
//     final appPackageMap = _getAppPackageMap();
//     final hasCompletedTasks = earnedScreenTimeMs > 0;
//
//     // Add display name entries that map to package stats
//     for (final entry in appPackageMap.entries) {
//       final displayName = entry.key;
//       final packageName = entry.value;
//
//       if (packageStats.containsKey(packageName) && !displayStats.containsKey(displayName)) {
//         // Copy the stats but ensure correct blocking logic
//         final stats = Map<String, dynamic>.from(packageStats[packageName]);
//         displayStats[displayName] = stats;
//       }
//     }
//
//     return displayStats;
//   }
//
//   /// Reset daily usage (called at start of new day)
//   static Future<void> _resetDailyUsage() async {
//     print('ScreenTimeService: Performing daily reset for $_currentChildName...');
//
//     // Clear all tracking data
//     _dailyUsage.clear();
//     _trackingStartTimes.clear();
//     _blockedApps.clear();
//     _earnedTimeToday = 0;
//     _currentFocusedApp = null;
//
//     if (_currentChildName == null) {
//       print('ScreenTimeService: Cannot reset - no child name set');
//       return;
//     }
//
//     // Update preferences
//     final prefs = await SharedPreferences.getInstance();
//     final today = DateTime.now().toIso8601String().split('T')[0];
//     _lastKnownDate = today;
//
//     await prefs.setString('${_lastResetKey}$_currentChildName', today);
//     await _saveToPreferences();
//
//     // Clean up old data for this child
//     await _cleanupOldData(prefs);
//
//     print('ScreenTimeService: Daily reset completed for $_currentChildName');
//   }
//
//   /// Public method to manually trigger daily reset
//   static Future<void> performDailyReset() async {
//     await _resetDailyUsage();
//     await stopNotifications();
//     _scheduleDailyReset();
//   }
//
//   /// Immediately reset screen time to 0 minutes
//   static Future<void> resetScreenTimeToZero() async {
//     print('ScreenTimeService: Manually resetting screen time to 0...');
//
//     // Get current system usage for all restricted apps
//     try {
//       if (await hasUsageStatsPermission()) {
//         final endTime = DateTime.now();
//         final startTime = DateTime(endTime.year, endTime.month, endTime.day);
//         final usageStats = await UsageStats.queryUsageStats(startTime, endTime);
//
//         // Update tracking start times to current system values
//         _trackingStartTimes.clear();
//         for (final stat in usageStats) {
//           final packageName = stat.packageName ?? '';
//           if (_restrictedApps.contains(packageName)) {
//             final usageTime = _asInt(stat.totalTimeInForeground ?? 0);
//             _trackingStartTimes[packageName] = usageTime;
//             print('ScreenTimeService: Reset tracking for $packageName to ${usageTime}ms');
//           }
//         }
//       }
//     } catch (e) {
//       print('ScreenTimeService: Error updating tracking start times: $e');
//     }
//
//     // Clear daily usage and blocked apps
//     _dailyUsage.clear();
//     _blockedApps.clear();
//
//     // Save the reset state
//     await _saveToPreferences();
//
//     print('ScreenTimeService: Screen time reset to 0 minutes completed');
//   }
//
//   /// Clean up old data from SharedPreferences
//   static Future<void> _cleanupOldData(SharedPreferences prefs) async {
//     final today = DateTime.now();
//     final keys = prefs.getKeys();
//     final cutoffDate = today.subtract(const Duration(days: 7));
//
//     for (final key in keys) {
//       if (key.startsWith(_dailyUsageKey) ||
//           key.startsWith(_earnedTimeKey) ||
//           key.startsWith(_trackingStartKey) ||
//           key.contains('blocked_apps_')) {
//         // Extract date from key (format: prefix_childName_date)
//         final parts = key.split('_');
//         if (parts.length >= 3) {
//           final dateString = parts.last;
//           try {
//             final keyDate = DateTime.parse(dateString);
//             if (keyDate.isBefore(cutoffDate)) {
//               await prefs.remove(key);
//               print('ScreenTimeService: Cleaned up old data: $key');
//             }
//           } catch (e) {
//             // Invalid date format, skip
//             continue;
//           }
//         }
//       }
//     }
//   }
//
//   /// Save current state to SharedPreferences
//   static Future<void> _saveToPreferences() async {
//     if (_currentChildName == null) {
//       print('ScreenTimeService: Cannot save - no child name set');
//       return;
//     }
//
//     final prefs = await SharedPreferences.getInstance();
//     final today = DateTime.now().toIso8601String().split('T')[0];
//
//     // Save data with child-specific keys
//     await prefs.setString('$_dailyUsageKey${_currentChildName}_$today', json.encode(_dailyUsage));
//     await prefs.setString('$_trackingStartKey${_currentChildName}_$today', json.encode(_trackingStartTimes));
//     await prefs.setString('$_screenTimeRulesKey$_currentChildName', json.encode(_screenTimeRules));
//     await prefs.setString('$_restrictedAppsKey$_currentChildName', json.encode(_restrictedApps));
//     await prefs.setStringList('blocked_apps_${_currentChildName}_$today', _blockedApps.toList());
//
//     print('ScreenTimeService: Saved data for $_currentChildName');
//   }
//
//   /// Stop monitoring
//   static void stopMonitoring() {
//     _monitoringTimer?.cancel();
//     _resetTimer?.cancel();
//     stopNotifications();
//   }
//
//   /// Update screen time rules from parent settings
//   static Future<void> updateScreenTimeRules() async {
//     await _syncWithFirestore();
//   }
//
//   /// Start notifications for the currently focused app
//   static Future<void> _startNotificationsForApp(String appName) async {
//     print('ScreenTimeService: Starting periodic notifications for $appName');
//
//     await _notificationService.startPeriodicNotifications(
//       currentAppPackage: appName,
//       getRemainingTime: (appName) {
//         final stats = getCurrentUsageStats();
//         if (stats.containsKey(appName)) {
//           final remainingMs = (stats[appName] as Map<String, dynamic>)['remainingTime'] as double? ?? 0.0;
//           final remainingMinutes = (remainingMs / (1000 * 60)).round();
//
//           if (remainingMinutes <= 0) {
//             return 'Time exceeded';
//           } else if (remainingMinutes < 60) {
//             return '$remainingMinutes minutes';
//           } else {
//             final hours = (remainingMinutes / 60).floor();
//             final minutes = remainingMinutes % 60;
//             return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
//           }
//         }
//         return 'unlimited';
//       },
//     );
//   }
//
//   /// Stop periodic notifications
//   static Future<void> stopNotifications() async {
//     _currentFocusedApp = null;
//     await _notificationService.stopPeriodicNotifications();
//   }
//
//   /// Show warning notification
//   static Future<void> _showWarningNotification(String appName, int remainingMinutes) async {
//     if (remainingMinutes <= 15 && remainingMinutes > 0) {
//       await _notificationService.showWarningNotification(
//         appName: appName,
//         remainingTime: '$remainingMinutes minutes',
//       );
//     }
//   }
//
//   /// Show session warning notification
//   static Future<void> _showSessionWarningNotification(String appName, int remainingMinutes) async {
//     await _notificationService.showWarningNotification(
//       appName: appName,
//       remainingTime: '$remainingMinutes minutes left in this session',
//     );
//   }
//
//   /// Show time exceeded notification
//   static Future<void> _showTimeExceededNotification(String appName) async {
//     final dailyLimitMs = _screenTimeRules['dailyLimit'] ?? (1 * 60 * 60 * 1000);
//     final dailyLimitHours = (dailyLimitMs / (1000 * 60 * 60)).toStringAsFixed(1);
//
//     await _notificationService.showTimeExceededNotification(
//       appName: appName,
//       timeLimit: '${dailyLimitHours}h',
//     );
//   }
//
//   /// Show educational task notification
//   static Future<void> _showEducationalTaskNotification(String appName) async {
//     final childName = await _getCurrentChildName();
//     if (childName == null) return;
//
//     final taskService = EducationalTaskService();
//     final pendingTasks = await taskService.fetchTasks(childName);
//     final pendingCount = pendingTasks.where((task) => !task.isCompleted).length;
//
//     await _notificationService.showEducationalTaskNotification(
//       blockedAppName: appName,
//       pendingTaskCount: pendingCount,
//     );
//   }
//
//   /// Show session expired notification with exit app button
//   static Future<void> _showSessionExpiredNotification(String appName) async {
//     final childName = await _getCurrentChildName();
//     if (childName == null) return;
//
//     final taskService = EducationalTaskService();
//     final pendingTasks = await taskService.fetchTasks(childName);
//     final pendingCount = pendingTasks.where((task) => !task.isCompleted).length;
//
//     // Show notification with exit app option
//     await _notificationService.showSessionExpiredNotification(
//       appName: appName,
//       sessionMinutes: ((5 * (_screenTimeRules['ratio'] ?? 3.0)).round()),
//     );
//
//     // Force close the app
//     await _forceCloseApp(appName);
//   }
//
//   /// Show daily limit reached notification with parental PIN option and exit app
//   static Future<void> _showDailyLimitReachedNotification(String appName) async {
//     await _notificationService.showDailyLimitReachedNotification(
//       appName: appName,
//     );
//
//     // Force close the app
//     await _forceCloseApp(appName);
//   }
//
//   /// Check for pending educational tasks
//   static Future<void> _checkEducationalTasks(String appName) async {
//     try {
//       final childName = await _getCurrentChildName();
//       if (childName == null) return;
//
//       final taskService = EducationalTaskService();
//       final hasPending = await taskService.hasPendingTasks(childName);
//
//       if (hasPending) {
//         print('ScreenTimeService: Found pending educational tasks for $childName when accessing $appName');
//
//         final pendingTasks = await taskService.fetchTasks(childName);
//         final pendingCount = pendingTasks.where((task) => !task.isCompleted).length;
//
//         await _notificationService.showEducationalTaskNotification(
//           blockedAppName: appName,
//           pendingTaskCount: pendingCount,
//         );
//       }
//     } catch (e) {
//       print('ScreenTimeService: Error checking educational tasks: $e');
//     }
//   }
//
//   /// Debug function to check usage stats
//   static Future<void> debugUsageStats() async {
//     print('=== DEBUG: Screen Time Service State ===');
//
//     try {
//       // Show current internal state
//       print('Current tracking data:');
//       print('  Current child: $_currentChildName');
//       print('  Daily usage: $_dailyUsage');
//       print('  Tracking start times: $_trackingStartTimes');
//       print('  Blocked apps: $_blockedApps');
//       print('  Earned time today: $_earnedTimeToday');
//       print('  Restricted apps: $_restrictedApps');
//       print('  Daily limit: ${(_screenTimeRules['dailyLimit'] ?? 0) / (60 * 60 * 1000)} hours');
//       print('  Ratio: ${_screenTimeRules['ratio'] ?? 0}x');
//
//       // Check actual system usage
//       final endTime = DateTime.now();
//       final startTime = DateTime(endTime.year, endTime.month, endTime.day);
//
//       print('Checking usage from ${startTime.toIso8601String()} to ${endTime.toIso8601String()}');
//
//       final List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startTime, endTime);
//       print('Found ${usageStats.length} usage stats entries');
//
//       // Show all apps with significant usage
//       print('System reported usage:');
//       for (var stat in usageStats) {
//         final packageName = stat.packageName ?? 'unknown';
//         final usageTime = _asInt(stat.totalTimeInForeground ?? 0);
//
//         if (usageTime > 10000) { // More than 10 seconds
//           final appName = await _getAppNameFromPackage(packageName);
//           final minutes = (usageTime / (1000 * 60)).toStringAsFixed(1);
//
//           if (_restrictedApps.contains(packageName)) {
//             final trackingStart = _trackingStartTimes[packageName] ?? 0;
//             final trackedUsage = usageTime - trackingStart;
//             final trackedMinutes = (trackedUsage / (1000 * 60)).toStringAsFixed(1);
//             print('  ✓ ${appName ?? packageName}: ${minutes}m system, ${trackedMinutes}m tracked');
//           } else {
//             print('  - ${appName ?? packageName}: ${minutes}m (not restricted)');
//           }
//         }
//       }
//
//       // Show calculated stats
//       print('Calculated stats for UI:');
//       final stats = getCurrentUsageStats();
//       for (final entry in stats.entries) {
//         final app = entry.key;
//         final data = entry.value;
//         if (data is Map) {
//           final usedMinutes = ((data['usedTime'] ?? 0) / (1000 * 60)).round();
//           final remainingMinutes = ((data['remainingTime'] ?? 0) / (1000 * 60)).round();
//           final isBlocked = data['isBlocked'] ?? false;
//           print('  $app: ${usedMinutes}m used, ${remainingMinutes}m remaining, blocked: $isBlocked');
//         }
//       }
//
//     } catch (e) {
//       print('Error in debug check: $e');
//     }
//     print('=== END DEBUG ===');
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';
import 'educational_task_service.dart';
import 'app_interception_service.dart';

class ScreenTimeService {
  // Storage keys now include child name for isolation
  static const String _dailyUsageKey = 'daily_usage_';
  static const String _lastResetKey = 'last_reset_';
  static const String _screenTimeRulesKey = 'screen_time_rules_';
  static const String _restrictedAppsKey = 'restricted_apps_';
  static const String _earnedTimeKey = 'earned_time_';
  static const String _trackingStartKey = 'tracking_start_';

  // Track current session
  static Timer? _monitoringTimer;
  static Timer? _resetTimer;
  static Map<String, int> _dailyUsage = {};
  static Map<String, double> _screenTimeRules = {};
  static List<String> _restrictedApps = [];
  static double _earnedTimeToday = 0;
  static String? _currentFocusedApp;
  static String? _lastKnownDate;
  static String? _currentChildName;
  static final NotificationService _notificationService = NotificationService();

  // Tracking start times for each app (when we started tracking today)
  static Map<String, int> _trackingStartTimes = {};

  // Apps that have reached their limit (stop tracking these)
  static Set<String> _blockedApps = {};

  /// Initialize the screen time service
  static Future<void> initialize() async {
    print('ScreenTimeService: Starting initialization...');

    await _requestPermissions();
    print('ScreenTimeService: Permissions requested');

    // Load stored data first (includes child-specific data)
    await _loadStoredData();
    print('ScreenTimeService: Stored data loaded');

    // Sync with Firestore to get parent's rules
    // This will override any local rules with parent's settings
    try {
      await _syncWithFirestore();
      print('ScreenTimeService: Firestore sync completed - rules updated from parent account');
    } catch (e) {
      print('ScreenTimeService: Firestore sync failed, using stored or default rules: $e');
      // If sync fails and no stored rules, set defaults
      if (_screenTimeRules.isEmpty || !_screenTimeRules.containsKey('dailyLimit')) {
        _setDefaultRulesForTesting();
      }
    }

    // Initialize notification service
    await _notificationService.initialize();
    print('ScreenTimeService: Notification service initialized');

    _startMonitoring();
    print('ScreenTimeService: Monitoring started');

    // Initialize app interception service
    await AppInterceptionService.initialize();
    print('ScreenTimeService: App interception service initialized');

    _scheduleDailyReset();
    print('ScreenTimeService: Daily reset timer scheduled');
  }

  /// Set default rules for testing when Firebase is unavailable
  static void _setDefaultRulesForTesting() {
    // Default to 1 hour daily limit to match parent's unified settings
    _screenTimeRules['dailyLimit'] = 1.0 * 60 * 60 * 1000; // 1 hour in milliseconds
    _screenTimeRules['ratio'] = 3.0; // 3x ratio (5 min learning = 15 min screen time)
    _restrictedApps = ['com.google.android.youtube', 'com.instagram.android', 'com.zhiliaoapp.musically', 'com.snapchat.android', 'com.twitter.android'];
    print('ScreenTimeService: Default testing rules set - 1 hour limit, 3x ratio');
  }

  /// Map app display names to package names
  static Map<String, String> _getAppPackageMap() {
    return {
      'YouTube': 'com.google.android.youtube',
      'YouTube Shorts': 'com.google.android.youtube',
      'Instagram': 'com.instagram.android',
      'TikTok': 'com.zhiliaoapp.musically',
      'Snapchat': 'com.snapchat.android',
      'X (Twitter)': 'com.twitter.android',
      'Twitter': 'com.twitter.android',
    };
  }

  /// Request necessary permissions
  static Future<void> _requestPermissions() async {
    if (!await Permission.systemAlertWindow.isGranted) {
      await Permission.systemAlertWindow.request();
    }
  }

  /// Check if usage stats permission is granted
  static Future<bool> hasUsageStatsPermission() async {
    try {
      final endTime = DateTime.now();
      final startTime = endTime.subtract(const Duration(days: 1));
      final stats = await UsageStats.queryUsageStats(startTime, endTime);

      print('ScreenTimeService: Permission check - found ${stats.length} usage stats');

      // More permissive check - if we can query stats at all, consider permission granted
      if (stats.isNotEmpty) {
        print('ScreenTimeService: Permission appears to be granted');
        return true;
      }

      print('ScreenTimeService: No usage stats found - permission likely denied');
      return false;
    } catch (e) {
      print('ScreenTimeService: Usage stats permission check failed: $e');
      return false;
    }
  }

  /// Open usage stats settings for the user to grant permission
  static Future<void> openUsageStatsSettings() async {
    try {
      const platform = MethodChannel('com.focuspass.app_blocker');
      await platform.invokeMethod('openUsageStatsSettings');
    } catch (e) {
      print('Error opening usage stats settings: $e');
    }
  }

  /// Load stored data from SharedPreferences
  static Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();

    // Get current child name
    _currentChildName = await _getCurrentChildName();
    if (_currentChildName == null) {
      print('ScreenTimeService: No child name set, cannot load data');
      return;
    }

    // Check if we need to reset daily usage (new day)
    final lastResetKey = '${_lastResetKey}$_currentChildName';
    final lastReset = prefs.getString(lastResetKey);
    final today = DateTime.now().toIso8601String().split('T')[0];
    _lastKnownDate = today;

    print('ScreenTimeService: Loading data for child: $_currentChildName');
    print('ScreenTimeService: Last reset: $lastReset, Today: $today');

    if (lastReset != today) {
      print('ScreenTimeService: New day detected, performing reset');
      await _resetDailyUsage();
    } else {
      print('ScreenTimeService: Same day, loading existing data');

      // Load daily usage for this child
      final usageKey = '$_dailyUsageKey${_currentChildName}_$today';
      final usageJson = prefs.getString(usageKey);
      if (usageJson != null) {
        try {
          final Map<String, dynamic> decoded = json.decode(usageJson);
          _dailyUsage = decoded.map((key, value) => MapEntry(key, value as int));
          print('ScreenTimeService: Loaded daily usage for $_currentChildName: $_dailyUsage');
        } catch (e) {
          print('ScreenTimeService: Error loading daily usage, resetting: $e');
          await _resetDailyUsage();
          return;
        }
      }

      // Load tracking start times for this child
      final trackingKey = '$_trackingStartKey${_currentChildName}_$today';
      final trackingJson = prefs.getString(trackingKey);
      if (trackingJson != null) {
        try {
          final Map<String, dynamic> decoded = json.decode(trackingJson);
          _trackingStartTimes = decoded.map((key, value) => MapEntry(key, value as int));
          print('ScreenTimeService: Loaded tracking start times for $_currentChildName');
        } catch (e) {
          print('ScreenTimeService: Error loading tracking start times: $e');
          _trackingStartTimes.clear();
        }
      }

      // Load blocked apps for this child
      final blockedKey = 'blocked_apps_${_currentChildName}_$today';
      final blockedList = prefs.getStringList(blockedKey);
      if (blockedList != null) {
        _blockedApps = blockedList.toSet();
        print('ScreenTimeService: Loaded blocked apps for $_currentChildName: $_blockedApps');
      }

      // Validate loaded data
      await _validateAndFixData();
    }

    // Load screen time rules for this child
    final rulesKey = '$_screenTimeRulesKey$_currentChildName';
    final rulesJson = prefs.getString(rulesKey);
    if (rulesJson != null) {
      final Map<String, dynamic> decoded = json.decode(rulesJson);
      _screenTimeRules = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
    }

    // Load restricted apps for this child
    final restrictedKey = '$_restrictedAppsKey$_currentChildName';
    final restrictedJson = prefs.getString(restrictedKey);
    if (restrictedJson != null) {
      _restrictedApps = List<String>.from(json.decode(restrictedJson));
    }

    // Load earned time for this child
    final earnedKey = '$_earnedTimeKey${_currentChildName}_$today';
    final earnedTime = prefs.getDouble(earnedKey) ?? 0.0;
    _earnedTimeToday = earnedTime;
  }

  /// Validate and fix any corrupted data
  static Future<void> _validateAndFixData() async {
    bool needsReset = false;

    // Check for suspicious usage values
    for (final entry in _dailyUsage.entries) {
      final usageMinutes = entry.value / (1000 * 60);
      if (usageMinutes > 1440) { // More than 24 hours
        print('ScreenTimeService: Detected invalid usage for ${entry.key}: ${usageMinutes.toStringAsFixed(1)} minutes - forcing reset');
        needsReset = true;
        break;
      }
    }

    if (needsReset) {
      await _resetDailyUsage();
    }
  }

  /// Sync with Firestore to get latest rules and restrictions
  static Future<void> _syncWithFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final childName = await _getCurrentChildName();
      if (childName == null) return;

      // Get screen time rules from parent's settings
      final parentQuery = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('name', isEqualTo: childName)
          .get();

      if (parentQuery.docs.isNotEmpty) {
        final childDoc = parentQuery.docs.first;
        final parentUid = childDoc.reference.parent.parent!.id;

        // Get parent's screen time rules
        final rulesDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(parentUid)
            .collection('settings')
            .doc('screenTimeRules')
            .get();

        if (rulesDoc.exists) {
          final rulesData = rulesDoc.data()!;
          double dailyLimit = 1.0; // default to 1 hour
          double ratio = 3.0; // default 3x (5 min learning = 15 min screen time)

          if (rulesData['applySameForAll'] == true) {
            // Use unified rules for all children
            dailyLimit = (rulesData['unifiedRules']?['limit'] ?? 1.0).toDouble();
            ratio = (rulesData['unifiedRules']?['ratio'] ?? 3.0).toDouble();
            print('ScreenTimeService: Using unified rules - Limit: ${dailyLimit}h, Ratio: ${ratio}x');
          } else {
            // Use individual rules for this child
            final childrenRules = rulesData['children'] as Map<String, dynamic>? ?? {};
            dailyLimit = (childrenRules[childName]?['limit'] ?? 1.0).toDouble();
            ratio = (childrenRules[childName]?['ratio'] ?? 3.0).toDouble();
            print('ScreenTimeService: Using individual rules for $childName - Limit: ${dailyLimit}h, Ratio: ${ratio}x');
          }

          // Convert hours to milliseconds and store ratio
          _screenTimeRules['dailyLimit'] = dailyLimit * 60 * 60 * 1000;
          _screenTimeRules['ratio'] = ratio;
        } else {
          // No rules document exists, use defaults
          print('ScreenTimeService: No rules found, using defaults - 1 hour limit, 3x ratio');
          _screenTimeRules['dailyLimit'] = 1.0 * 60 * 60 * 1000;
          _screenTimeRules['ratio'] = 3.0;
        }

        // Get restricted apps from child data
        final childData = childDoc.data();
        final selectedAppNames = List<String>.from(childData['selectedApps'] ?? []);
        final Set<String> packagesToRestrict = {};
        final Map<String, String> appPackageMap = _getAppPackageMap();

        // Check if any web-based apps are selected
        const webBasedApps = {'YouTube', 'TikTok', 'Netflix', 'Instagram', 'X (Twitter)', 'Twitter'};
        bool shouldBlockBrowsers = false;

        for (final appName in selectedAppNames) {
          if (appPackageMap.containsKey(appName)) {
            packagesToRestrict.add(appPackageMap[appName]!);
          } else {
            packagesToRestrict.add(appName);
          }

          // Check if this is a web-based app
          if (webBasedApps.contains(appName)) {
            shouldBlockBrowsers = true;
          }
        }

        // Add browsers to prevent web access loophole
        if (shouldBlockBrowsers) {
          print('ScreenTimeService: Adding browsers to block web access loophole');
          packagesToRestrict.add('com.android.chrome');
          packagesToRestrict.add('com.sec.android.app.sbrowser'); // Samsung Internet
          packagesToRestrict.add('org.mozilla.firefox');
          packagesToRestrict.add('com.microsoft.emmx'); // Edge
          packagesToRestrict.add('com.opera.browser');
        }

        _restrictedApps = packagesToRestrict.toList();

        print('ScreenTimeService: Loaded rules for $childName:');
        print('  Daily limit: ${_screenTimeRules['dailyLimit']! / (60 * 60 * 1000)} hours');
        print('  Ratio: ${_screenTimeRules['ratio']}x');
        print('  Restricted apps: $_restrictedApps');

        await _saveToPreferences();
      } else {
        // Child not found in any parent's collection, use defaults
        print('ScreenTimeService: Child $childName not found in parent records, using defaults');
        _screenTimeRules['dailyLimit'] = 1.0 * 60 * 60 * 1000;
        _screenTimeRules['ratio'] = 3.0;
      }
    } catch (e) {
      print('Error syncing with Firestore: $e');
      // Use defaults if sync fails
      _screenTimeRules['dailyLimit'] = 1.0 * 60 * 60 * 1000;
      _screenTimeRules['ratio'] = 3.0;
    }
  }

  /// Get current child name from stored preferences
  static Future<String?> _getCurrentChildName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_child_name');
  }

  /// Set current child name
  static Future<void> setCurrentChildName(String childName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_child_name', childName);

    // If child name changed, reload data for the new child
    if (_currentChildName != childName) {
      _currentChildName = childName;
      print('ScreenTimeService: Switching to child: $childName');

      // Clear current data
      _dailyUsage.clear();
      _trackingStartTimes.clear();
      _blockedApps.clear();
      _earnedTimeToday = 0;

      // Load data for the new child
      await _loadStoredData();
    }
  }

  /// Start monitoring app usage
  static void _startMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _checkCurrentAppUsage();
      _checkForDayChange();
    });
  }

  /// Schedule automatic daily reset at midnight
  static void _scheduleDailyReset() {
    _resetTimer?.cancel();

    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = nextMidnight.difference(now);

    print('ScreenTimeService: Scheduling reset in ${timeUntilMidnight.inHours}h ${timeUntilMidnight.inMinutes % 60}m');

    _resetTimer = Timer(timeUntilMidnight, () async {
      print('ScreenTimeService: Midnight reset triggered');
      await performDailyReset();
      _scheduleDailyReset();
    });
  }

  /// Check if day has changed during monitoring
  static void _checkForDayChange() {
    final currentDate = DateTime.now().toIso8601String().split('T')[0];

    if (_lastKnownDate != null && _lastKnownDate != currentDate) {
      print('ScreenTimeService: Day change detected during monitoring');
      performDailyReset();
    }

    _lastKnownDate = currentDate;
  }

  /// Convert value to int safely
  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Check current app usage and enforce restrictions
  static Future<void> _checkCurrentAppUsage() async {
    try {
      if (!await hasUsageStatsPermission()) {
        print('ScreenTimeService: No usage stats permission, skipping check');
        return;
      }

      if (_currentChildName == null) {
        print('ScreenTimeService: No child name set, skipping check');
        return;
      }

      final endTime = DateTime.now();
      final startTime = DateTime(endTime.year, endTime.month, endTime.day);

      final List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startTime, endTime);

      // Check if educational tasks are completed
      final hasCompletedTasks = _earnedTimeToday > 0;
      final ratio = _screenTimeRules['ratio'] ?? 3.0;
      final sessionTimeMs = hasCompletedTasks ? (5 * ratio * 60 * 1000) : 0; // 5 min learning * ratio
      final dailyLimitMs = _screenTimeRules['dailyLimit'] ?? (1 * 60 * 60 * 1000);

      bool hasChanges = false;

      // Track combined usage for web-based apps (app + browser)
      Map<String, int> combinedUsage = {};

      for (final stat in usageStats) {
        final packageName = stat.packageName ?? '';

        if (!_restrictedApps.contains(packageName)) continue;

        // Skip tracking if app has reached daily limit
        if (_blockedApps.contains(packageName)) {
          print('ScreenTimeService: $packageName already at daily limit, skipping tracking');
          continue;
        }

        final usageTimeRaw = stat.totalTimeInForeground ?? 0;
        int systemUsageTime = _asInt(usageTimeRaw);

        // Initialize tracking start time if not set
        if (!_trackingStartTimes.containsKey(packageName)) {
          _trackingStartTimes[packageName] = systemUsageTime;
          print('ScreenTimeService: Started tracking $packageName for $_currentChildName at ${systemUsageTime}ms');
        }

        // Calculate usage since we started tracking
        final trackingStart = _trackingStartTimes[packageName] ?? systemUsageTime;
        final relativeUsage = (systemUsageTime - trackingStart).clamp(0, double.maxFinite.toInt());

        // For browsers, accumulate usage to the appropriate web app
        if (_isBrowser(packageName)) {
          // Add browser usage to YouTube tracking (since YouTube is the main web-based app)
          final youtubePackage = 'com.google.android.youtube';
          if (_restrictedApps.contains(youtubePackage)) {
            combinedUsage[youtubePackage] = (combinedUsage[youtubePackage] ?? 0) + relativeUsage;
            print('ScreenTimeService: Adding browser usage to YouTube tracking: ${(relativeUsage / (1000 * 60)).round()}m');
          }
        } else {
          // Regular app usage
          combinedUsage[packageName] = relativeUsage;
        }
      }

      // Process combined usage
      for (final entry in combinedUsage.entries) {
        final packageName = entry.key;
        final relativeUsage = entry.value;

        // Update daily usage if it increased
        final previousUsage = _dailyUsage[packageName] ?? 0;
        if (relativeUsage != previousUsage) {
          _dailyUsage[packageName] = relativeUsage;
          hasChanges = true;

          final usedMinutes = (relativeUsage / (1000 * 60)).round();
          print('ScreenTimeService: Updated $packageName usage for $_currentChildName: ${usedMinutes}m');

          // Check blocking conditions
          if (!hasCompletedTasks) {
            // No tasks completed = BLOCK immediately
            print('ScreenTimeService: $packageName blocked - must complete educational tasks first');
            await _showEducationalTaskNotification(packageName);
            await _blockApp(packageName, packageName);
            // Also block browsers if this is a web-based app
            if (_isWebBasedApp(packageName)) {
              await _blockBrowsers();
            }
          } else if (relativeUsage >= dailyLimitMs) {
            // Daily limit reached = BLOCK permanently for today
            print('ScreenTimeService: $packageName reached DAILY LIMIT for $_currentChildName');
            _blockedApps.add(packageName);
            await _showDailyLimitReachedNotification(packageName);
            await _forceCloseApp(packageName);
            // Also block browsers if this is a web-based app
            if (_isWebBasedApp(packageName)) {
              await _blockBrowsers();
            }
            continue;
          } else if (relativeUsage >= sessionTimeMs) {
            // Session time expired = need more tasks
            print('ScreenTimeService: Session expired for $packageName (used ${(relativeUsage / (1000 * 60)).round()}m of ${(sessionTimeMs / (1000 * 60)).round()}m session)');
            _earnedTimeToday = 0; // Reset earned time to require new tasks
            await _showSessionExpiredNotification(packageName);
            await _forceCloseApp(packageName);
            // Also block browsers if this is a web-based app
            if (_isWebBasedApp(packageName)) {
              await _blockBrowsers();
            }
          } else {
            // Still within session time
            final sessionRemainingMs = sessionTimeMs - relativeUsage;
            final sessionRemainingMinutes = (sessionRemainingMs / (1000 * 60)).round();

            if (sessionRemainingMinutes <= 5 && sessionRemainingMinutes > 0) {
              await _showSessionWarningNotification(packageName, sessionRemainingMinutes);
            }
          }
        }
      }

      if (hasChanges) {
        await _saveToPreferences();
      }
    } catch (e) {
      print('ScreenTimeService: Error checking app usage: $e');
    }
  }

  /// Check if a package is a browser
  static bool _isBrowser(String packageName) {
    const browsers = {
      'com.android.chrome',
      'com.sec.android.app.sbrowser',
      'org.mozilla.firefox',
      'com.microsoft.emmx',
      'com.opera.browser',
    };
    return browsers.contains(packageName);
  }

  /// Check if app has web version
  static bool _isWebBasedApp(String packageName) {
    const webBasedApps = {
      'com.google.android.youtube',
      'com.instagram.android',
      'com.zhiliaoapp.musically',
      'com.twitter.android',
      'com.netflix.mediaclient',
    };
    return webBasedApps.contains(packageName);
  }

  /// Block all browsers
  static Future<void> _blockBrowsers() async {
    const browsers = [
      'com.android.chrome',
      'com.sec.android.app.sbrowser',
      'org.mozilla.firefox',
      'com.microsoft.emmx',
      'com.opera.browser',
    ];

    for (final browser in browsers) {
      await _forceCloseApp(browser);
    }
  }

  /// Get app name from package name
  static Future<String?> _getAppNameFromPackage(String packageName) async {
    final knownApps = {
      'com.google.android.youtube': 'YouTube',
      'com.instagram.android': 'Instagram',
      'com.zhiliaoapp.musically': 'TikTok',
      'com.snapchat.android': 'Snapchat',
      'com.twitter.android': 'Twitter',
      'com.facebook.katana': 'Facebook',
      'com.whatsapp': 'WhatsApp',
      'com.spotify.music': 'Spotify',
      'com.netflix.mediaclient': 'Netflix',
      'com.discord': 'Discord',
    };

    if (knownApps.containsKey(packageName)) {
      return knownApps[packageName];
    }

    try {
      final apps = await InstalledApps.getInstalledApps(true, true);
      final app = apps.firstWhere(
            (app) => app.packageName == packageName,
        orElse: () => throw Exception('App not found'),
      );
      return app.name;
    } catch (e) {
      return null;
    }
  }

  /// Check if app usage has exceeded the daily limit
  static bool _isAppUsageExceeded(String packageName, int usageTimeMs) {
    final dailyLimitMs = _screenTimeRules['dailyLimit'] ?? (1 * 60 * 60 * 1000);
    // App is exceeded if usage is greater than or equal to the fixed daily limit
    return usageTimeMs >= dailyLimitMs;
  }

  /// Block an app
  static Future<void> _blockApp(String packageName, String appName) async {
    try {
      await _showBlockingOverlay(appName);
    } catch (e) {
      print('Error blocking app: $e');
    }
  }

  /// Show blocking overlay with exit app button
  static Future<void> _showBlockingOverlay(String appName) async {
    const platform = MethodChannel('com.focuspass.app_blocker');
    try {
      await platform.invokeMethod('showBlockingOverlay', {
        'appName': appName,
        'message': 'Time limit reached for $appName.',
        'showExitButton': true,
        'exitButtonText': 'Exit $appName',
      });
    } catch (e) {
      print('Error showing blocking overlay: $e');
    }
  }

  /// Force close the current app
  static Future<void> _forceCloseApp(String packageName) async {
    const platform = MethodChannel('com.focuspass.app_blocker');
    try {
      await platform.invokeMethod('forceCloseApp', {
        'packageName': packageName,
      });
      print('ScreenTimeService: Force closed app: $packageName');
    } catch (e) {
      print('Error force closing app: $e');
      // Fallback to showing blocking overlay
      await _showBlockingOverlay(packageName);
    }
  }

  /// Grant app access after completing educational tasks
  static Future<void> addEarnedTime(double minutes) async {
    // When tasks are completed, grant access for one session
    // The actual screen time is calculated based on parent's ratio
    _earnedTimeToday = 1.0; // Mark that tasks have been completed

    if (_currentChildName == null) {
      print('ScreenTimeService: Cannot save earned time - no child name set');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setDouble('$_earnedTimeKey${_currentChildName}_$today', _earnedTimeToday);

    final ratio = _screenTimeRules['ratio'] ?? 3.0;
    final earnedMinutes = 5 * ratio; // 5 min learning * ratio = earned screen time

    print('ScreenTimeService: Educational tasks completed for $_currentChildName');
    print('  Ratio: ${ratio}x (5 min learning = ${earnedMinutes} min screen time)');
    print('  Session granted: ${earnedMinutes} minutes');

    await AppInterceptionService.checkTaskCompletionAndUpdateAccess();
  }

  /// Called when educational tasks are completed
  static Future<void> onEducationalTasksCompleted() async {
    final childName = await _getCurrentChildName();
    if (childName == null) return;

    print('ScreenTimeService: Educational tasks completed for $childName');

    final taskService = EducationalTaskService();
    final hasPendingTasks = await taskService.hasPendingTasks(childName);

    if (!hasPendingTasks) {
      await AppInterceptionService.clearAllInterceptions();
      await _notificationService.showTasksCompletedNotification();

      final stats = getCurrentUsageStats();
      for (final app in _restrictedApps) {
        final appStats = stats[app];
        if (appStats != null) {
          final remainingMs = appStats['remainingTime'] as double? ?? 0.0;
          final remainingMinutes = (remainingMs / (1000 * 60)).round();

          if (remainingMinutes > 0) {
            await _notificationService.showAppAccessGrantedNotification(
              appName: app,
              remainingMinutes: remainingMinutes,
            );
          }
        }
      }

      print('ScreenTimeService: All apps unlocked');
    }
  }

  /// Get current usage statistics
  static Map<String, dynamic> getCurrentUsageStats() {
    final dailyLimitMs = (_screenTimeRules['dailyLimit'] ?? (1 * 60 * 60 * 1000)).toDouble();
    final ratioMultiplier = _screenTimeRules['ratio'] ?? 3.0;

    // Check if child has completed educational tasks today
    final hasCompletedTasks = _earnedTimeToday > 0;

    // Calculate earned screen time based on ratio
    final earnedScreenTimeMs = hasCompletedTasks ? (5 * ratioMultiplier * 60 * 1000) : 0.0;

    Map<String, dynamic> stats = {};

    // Create stats for each restricted app
    for (final packageName in _restrictedApps) {
      final usageMs = (_dailyUsage[packageName] ?? 0).toDouble();

      double sessionTimeMs = earnedScreenTimeMs;
      double remainingTime = 0.0;
      double sessionRemaining = 0.0;
      bool isBlocked = false;
      bool needsTasks = false;

      // Calculate remaining time from daily limit (for display)
      final dailyRemaining = (dailyLimitMs - usageMs).clamp(0.0, double.infinity);

      if (!hasCompletedTasks && usageMs == 0) {
        // No tasks completed and no usage yet = needs tasks to start
        isBlocked = false; // Don't block until daily limit is reached
        needsTasks = true;
        remainingTime = dailyRemaining; // Show full daily limit remaining
        sessionRemaining = 0.0;
      } else if (!hasCompletedTasks && usageMs > 0) {
        // Used some time but session expired, needs new tasks
        isBlocked = false; // Don't block until daily limit is reached
        needsTasks = true;
        remainingTime = dailyRemaining;
        sessionRemaining = 0.0;
      } else if (hasCompletedTasks) {
        // Tasks completed - check session status
        if (usageMs >= sessionTimeMs) {
          // Session used up, needs more tasks
          isBlocked = false; // Don't block until daily limit is reached
          needsTasks = true;
          remainingTime = dailyRemaining;
          sessionRemaining = 0.0;
        } else {
          // Still in active session
          isBlocked = false;
          needsTasks = false;
          remainingTime = dailyRemaining; // Show daily limit remaining
          sessionRemaining = sessionTimeMs - usageMs; // Show session remaining
        }
      }

      // Check if daily limit is reached (overrides everything)
      if (usageMs >= dailyLimitMs) {
        isBlocked = true;
        needsTasks = false; // Can't earn more time today
        remainingTime = 0.0;
        sessionRemaining = 0.0;
      }

      stats[packageName] = {
        'usedTime': usageMs.toInt(),
        'remainingTime': remainingTime, // Remaining from daily limit
        'sessionTime': sessionTimeMs.toInt(),
        'sessionRemaining': sessionRemaining, // Remaining in current session
        'dailyLimit': dailyLimitMs.toInt(),
        'isBlocked': isBlocked,
        'hasCompletedTasks': hasCompletedTasks,
        'needsTasks': needsTasks,
        'dailyLimitReached': usageMs >= dailyLimitMs,
        'childName': _currentChildName ?? 'Unknown',
      };
    }

    // Also create entries for display names
    return _createStatsForSelectedApps(stats, dailyLimitMs, earnedScreenTimeMs);
  }

  /// Create stats entries for display names
  static Map<String, dynamic> _createStatsForSelectedApps(Map<String, dynamic> packageStats, double dailyLimitMs, double earnedScreenTimeMs) {
    Map<String, dynamic> displayStats = Map.from(packageStats);

    final appPackageMap = _getAppPackageMap();
    final hasCompletedTasks = earnedScreenTimeMs > 0;

    // Add display name entries that map to package stats
    for (final entry in appPackageMap.entries) {
      final displayName = entry.key;
      final packageName = entry.value;

      if (packageStats.containsKey(packageName) && !displayStats.containsKey(displayName)) {
        // Copy the stats but ensure correct blocking logic
        final stats = Map<String, dynamic>.from(packageStats[packageName]);
        displayStats[displayName] = stats;
      }
    }

    return displayStats;
  }

  /// Reset daily usage (called at start of new day)
  static Future<void> _resetDailyUsage() async {
    print('ScreenTimeService: Performing daily reset for $_currentChildName...');

    // Clear all tracking data
    _dailyUsage.clear();
    _trackingStartTimes.clear();
    _blockedApps.clear();
    _earnedTimeToday = 0;
    _currentFocusedApp = null;

    if (_currentChildName == null) {
      print('ScreenTimeService: Cannot reset - no child name set');
      return;
    }

    // Update preferences
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    _lastKnownDate = today;

    await prefs.setString('${_lastResetKey}$_currentChildName', today);
    await _saveToPreferences();

    // Clean up old data for this child
    await _cleanupOldData(prefs);

    // Reset Firestore app limits to the parent's base daily limit (e.g., 1 hour)
    await _resetFirestoreAppLimitsToBase();

    print('ScreenTimeService: Daily reset completed for $_currentChildName');
  }

  /// Public method to manually trigger daily reset
  static Future<void> performDailyReset() async {
    await _resetDailyUsage();
    await stopNotifications();
    _scheduleDailyReset();
  }

  /// Immediately reset screen time to 0 minutes
  static Future<void> resetScreenTimeToZero() async {
    print('ScreenTimeService: Manually resetting screen time to 0...');

    // Get current system usage for all restricted apps
    try {
      if (await hasUsageStatsPermission()) {
        final endTime = DateTime.now();
        final startTime = DateTime(endTime.year, endTime.month, endTime.day);
        final usageStats = await UsageStats.queryUsageStats(startTime, endTime);

        // Update tracking start times to current system values
        _trackingStartTimes.clear();
        for (final stat in usageStats) {
          final packageName = stat.packageName ?? '';
          if (_restrictedApps.contains(packageName)) {
            final usageTime = _asInt(stat.totalTimeInForeground ?? 0);
            _trackingStartTimes[packageName] = usageTime;
            print('ScreenTimeService: Reset tracking for $packageName to ${usageTime}ms');
          }
        }
      }
    } catch (e) {
      print('ScreenTimeService: Error updating tracking start times: $e');
    }

    // Clear daily usage and blocked apps
    _dailyUsage.clear();
    _blockedApps.clear();

    // Save the reset state
    await _saveToPreferences();

    print('ScreenTimeService: Screen time reset to 0 minutes completed');
  }

  /// Clean up old data from SharedPreferences
  static Future<void> _cleanupOldData(SharedPreferences prefs) async {
    final today = DateTime.now();
    final keys = prefs.getKeys();
    final cutoffDate = today.subtract(const Duration(days: 7));

    for (final key in keys) {
      if (key.startsWith(_dailyUsageKey) ||
          key.startsWith(_earnedTimeKey) ||
          key.startsWith(_trackingStartKey) ||
          key.contains('blocked_apps_')) {
        // Extract date from key (format: prefix_childName_date)
        final parts = key.split('_');
        if (parts.length >= 3) {
          final dateString = parts.last;
          try {
            final keyDate = DateTime.parse(dateString);
            if (keyDate.isBefore(cutoffDate)) {
              await prefs.remove(key);
              print('ScreenTimeService: Cleaned up old data: $key');
            }
          } catch (e) {
            // Invalid date format, skip
            continue;
          }
        }
      }
    }
  }

  /// Save current state to SharedPreferences
  static Future<void> _saveToPreferences() async {
    if (_currentChildName == null) {
      print('ScreenTimeService: Cannot save - no child name set');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Save data with child-specific keys
    await prefs.setString('$_dailyUsageKey${_currentChildName}_$today', json.encode(_dailyUsage));
    await prefs.setString('$_trackingStartKey${_currentChildName}_$today', json.encode(_trackingStartTimes));
    await prefs.setString('$_screenTimeRulesKey$_currentChildName', json.encode(_screenTimeRules));
    await prefs.setString('$_restrictedAppsKey$_currentChildName', json.encode(_restrictedApps));
    await prefs.setStringList('blocked_apps_${_currentChildName}_$today', _blockedApps.toList());

    print('ScreenTimeService: Saved data for $_currentChildName');
  }

  /// Stop monitoring
  static void stopMonitoring() {
    _monitoringTimer?.cancel();
    _resetTimer?.cancel();
    stopNotifications();
  }

  /// Update screen time rules from parent settings
  static Future<void> updateScreenTimeRules() async {
    await _syncWithFirestore();
  }

  /// Start notifications for the currently focused app
  static Future<void> _startNotificationsForApp(String appName) async {
    print('ScreenTimeService: Starting periodic notifications for $appName');

    await _notificationService.startPeriodicNotifications(
      currentAppPackage: appName,
      getRemainingTime: (appName) {
        final stats = getCurrentUsageStats();
        if (stats.containsKey(appName)) {
          final remainingMs = (stats[appName] as Map<String, dynamic>)['remainingTime'] as double? ?? 0.0;
          final remainingMinutes = (remainingMs / (1000 * 60)).round();

          if (remainingMinutes <= 0) {
            return 'Time exceeded';
          } else if (remainingMinutes < 60) {
            return '$remainingMinutes minutes';
          } else {
            final hours = (remainingMinutes / 60).floor();
            final minutes = remainingMinutes % 60;
            return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
          }
        }
        return 'unlimited';
      },
    );
  }

  /// Stop periodic notifications
  static Future<void> stopNotifications() async {
    _currentFocusedApp = null;
    await _notificationService.stopPeriodicNotifications();
  }

  /// Show warning notification
  static Future<void> _showWarningNotification(String appName, int remainingMinutes) async {
    if (remainingMinutes <= 15 && remainingMinutes > 0) {
      await _notificationService.showWarningNotification(
        appName: appName,
        remainingTime: '$remainingMinutes minutes',
      );
    }
  }

  /// Show session warning notification
  static Future<void> _showSessionWarningNotification(String appName, int remainingMinutes) async {
    await _notificationService.showWarningNotification(
      appName: appName,
      remainingTime: '$remainingMinutes minutes left in this session',
    );
  }

  /// Show time exceeded notification
  static Future<void> _showTimeExceededNotification(String appName) async {
    final dailyLimitMs = _screenTimeRules['dailyLimit'] ?? (1 * 60 * 60 * 1000);
    final dailyLimitHours = (dailyLimitMs / (1000 * 60 * 60)).toStringAsFixed(1);

    await _notificationService.showTimeExceededNotification(
      appName: appName,
      timeLimit: '${dailyLimitHours}h',
    );
  }

  /// Show educational task notification
  static Future<void> _showEducationalTaskNotification(String appName) async {
    final childName = await _getCurrentChildName();
    if (childName == null) return;

    final taskService = EducationalTaskService();
    final pendingTasks = await taskService.fetchTasks(childName);
    final pendingCount = pendingTasks.where((task) => !task.isCompleted).length;

    await _notificationService.showEducationalTaskNotification(
      blockedAppName: appName,
      pendingTaskCount: pendingCount,
    );
  }

  /// Show session expired notification with exit app button
  static Future<void> _showSessionExpiredNotification(String appName) async {
    final childName = await _getCurrentChildName();
    if (childName == null) return;

    final taskService = EducationalTaskService();
    final pendingTasks = await taskService.fetchTasks(childName);
    final pendingCount = pendingTasks.where((task) => !task.isCompleted).length;

    // Show notification with exit app option
    await _notificationService.showSessionExpiredNotification(
      appName: appName,
      sessionMinutes: ((5 * (_screenTimeRules['ratio'] ?? 3.0)).round()),
    );

    // Force close the app
    await _forceCloseApp(appName);
  }

  /// Show daily limit reached notification with parental PIN option and exit app
  static Future<void> _showDailyLimitReachedNotification(String appName) async {
    await _notificationService.showDailyLimitReachedNotification(
      appName: appName,
    );

    // Force close the app
    await _forceCloseApp(appName);
  }

  /// Check for pending educational tasks
  static Future<void> _checkEducationalTasks(String appName) async {
    try {
      final childName = await _getCurrentChildName();
      if (childName == null) return;

      final taskService = EducationalTaskService();
      final hasPending = await taskService.hasPendingTasks(childName);

      if (hasPending) {
        print('ScreenTimeService: Found pending educational tasks for $childName when accessing $appName');

        final pendingTasks = await taskService.fetchTasks(childName);
        final pendingCount = pendingTasks.where((task) => !task.isCompleted).length;

        await _notificationService.showEducationalTaskNotification(
          blockedAppName: appName,
          pendingTaskCount: pendingCount,
        );
      }
    } catch (e) {
      print('ScreenTimeService: Error checking educational tasks: $e');
    }
  }

  /// Debug function to check usage stats
  static Future<void> debugUsageStats() async {
    print('=== DEBUG: Screen Time Service State ===');

    try {
      // Show current internal state
      print('Current tracking data:');
      print('  Current child: $_currentChildName');
      print('  Daily usage: $_dailyUsage');
      print('  Tracking start times: $_trackingStartTimes');
      print('  Blocked apps: $_blockedApps');
      print('  Earned time today: $_earnedTimeToday');
      print('  Restricted apps: $_restrictedApps');
      print('  Daily limit: ${(_screenTimeRules['dailyLimit'] ?? 0) / (60 * 60 * 1000)} hours');
      print('  Ratio: ${_screenTimeRules['ratio'] ?? 0}x');

      // Check educational tasks
      print('\nEducational Tasks Status:');
      final childName = await _getCurrentChildName();
      if (childName != null) {
        final taskService = EducationalTaskService();
        final hasPending = await taskService.hasPendingTasks(childName);
        print('  Has pending tasks: $hasPending');

        final tasks = await taskService.fetchTasks(childName);
        print('  Total tasks found: ${tasks.length}');

        final today = DateTime.now();
        final todaysTasks = tasks.where((task) {
          return task.assignedAt.year == today.year &&
              task.assignedAt.month == today.month &&
              task.assignedAt.day == today.day;
        }).toList();
        print('  Tasks for today: ${todaysTasks.length}');

        for (final task in todaysTasks) {
          print('    - ${task.subject}: ${task.isCompleted ? "COMPLETED" : "PENDING"}');
        }
      }

      // Check actual system usage
      final endTime = DateTime.now();
      final startTime = DateTime(endTime.year, endTime.month, endTime.day);

      print('\nSystem usage stats:');
      final List<UsageInfo> usageStats = await UsageStats.queryUsageStats(startTime, endTime);
      print('Found ${usageStats.length} usage stats entries');

      // Show calculated stats
      print('\nCalculated stats for UI:');
      final stats = getCurrentUsageStats();
      for (final entry in stats.entries) {
        final app = entry.key;
        final data = entry.value;
        if (data is Map) {
          final usedMinutes = ((data['usedTime'] ?? 0) / (1000 * 60)).round();
          final remainingMinutes = ((data['remainingTime'] ?? 0) / (1000 * 60)).round();
          final sessionRemaining = ((data['sessionRemaining'] ?? 0) / (1000 * 60)).round();
          final isBlocked = data['isBlocked'] ?? false;
          final needsTasks = data['needsTasks'] ?? false;
          print('  $app:');
          print('    Used: ${usedMinutes}m');
          print('    Daily remaining: ${remainingMinutes}m');
          print('    Session remaining: ${sessionRemaining}m');
          print('    Blocked: $isBlocked');
          print('    Needs tasks: $needsTasks');
        }
      }

    } catch (e) {
      print('Error in debug check: $e');
    }
    print('=== END DEBUG ===');
  }

  /// Force generate educational tasks for testing
  static Future<void> forceGenerateEducationalTasks() async {
    final childName = await _getCurrentChildName();
    if (childName == null) {
      print('ScreenTimeService: No child name set, cannot generate tasks');
      return;
    }

    print('ScreenTimeService: Force generating educational tasks for $childName');

    try {
      // Get child's data to find subjects
      final query = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('name', isEqualTo: childName)
          .get();

      if (query.docs.isEmpty) {
        print('ScreenTimeService: Child not found in Firestore');
        return;
      }

      final childData = query.docs.first.data();
      final subjects = List<String>.from(childData['subjectsOfInterest'] ?? ['Math', 'Science']);
      final ageRange = childData['ageRange'] ?? '6-8';

      print('ScreenTimeService: Generating tasks for subjects: $subjects, age: $ageRange');

      final taskService = EducationalTaskService();
      await taskService.generateDailyTasks(childName, subjects, ageRange);

      print('ScreenTimeService: Tasks generated successfully');

      // Verify tasks were created
      final tasks = await taskService.fetchTasks(childName);
      final today = DateTime.now();
      final todaysTasks = tasks.where((task) {
        return task.assignedAt.year == today.year &&
            task.assignedAt.month == today.month &&
            task.assignedAt.day == today.day;
      }).toList();

      print('ScreenTimeService: Created ${todaysTasks.length} tasks for today');

    } catch (e) {
      print('ScreenTimeService: Error generating tasks: $e');
    }
  }

  /// Reset Firestore app limits (dailyLimitMinutes) back to the parent's configured base limit each day.
  /// This prevents accumulated overrides from permanently increasing limits across days.
  static Future<void> _resetFirestoreAppLimitsToBase() async {
    try {
      final childName = await _getCurrentChildName();
      if (childName == null || childName.isEmpty) {
        print('ScreenTimeService: Cannot reset app limits - no child name set');
        return;
      }

      // Find the child's document to locate the parent and selected apps
      final childQuery = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('name', isEqualTo: childName)
          .get();

      if (childQuery.docs.isEmpty) {
        print('ScreenTimeService: Cannot reset app limits - child not found in Firestore');
        return;
      }

      final childDocRef = childQuery.docs.first.reference; // users/{parentUid}/children/{childName}
      final parentUid = childDocRef.parent.parent!.id;

      // Read parent's screen time rules to determine the base daily limit (in hours)
      final rulesDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .collection('settings')
          .doc('screenTimeRules')
          .get();

      double baseLimitHours = 1.0; // Default to 1 hour if not configured
      if (rulesDoc.exists) {
        final rulesData = rulesDoc.data()!;
        if ((rulesData['applySameForAll'] ?? false) == true) {
          baseLimitHours = (rulesData['unifiedRules']?['limit'] ?? 1.0).toDouble();
        } else {
          final childrenData = rulesData['children'] as Map<String, dynamic>? ?? {};
          baseLimitHours = (childrenData[childName]?['limit'] ?? 1.0).toDouble();
        }
      }

      final baseLimitMinutes = (baseLimitHours * 60).round();

      // Get selected apps so we can set per-app limits uniformly
      final childSnapshot = await childDocRef.get();
      final childData = childSnapshot.data() as Map<String, dynamic>? ?? {};
      final selectedApps = List<String>.from(childData['selectedApps'] ?? []);

      if (selectedApps.isEmpty) {
        print('ScreenTimeService: No selected apps found for $childName when resetting app limits');
        return;
      }

      // Build fresh appLimits map applying the base limit to each selected app
      final Map<String, dynamic> newAppLimits = {
        for (final app in selectedApps) app: {'dailyLimitMinutes': baseLimitMinutes}
      };

      await childDocRef.update({'appLimits': newAppLimits});
      print('ScreenTimeService: Reset appLimits to base (${baseLimitMinutes}m) for ${selectedApps.length} apps for $childName');
    } catch (e) {
      print('ScreenTimeService: Error resetting Firestore app limits: $e');
    }
  }
}
