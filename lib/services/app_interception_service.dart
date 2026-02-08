import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screen_time_service.dart';
import 'educational_task_service.dart';
import 'notification_service.dart';
import 'focuspass_workflow_service.dart';
import 'native_usage_stats_service.dart';

class AppInterceptionService {
  static const String _lastAppCheckKey = 'last_app_check';
  static const String _interceptedAppsKey = 'intercepted_apps';
  static const String _pendingTasksKey = 'pending_tasks_shown';
  
  static Timer? _interceptionTimer;
  static String? _lastActiveApp;
  static Set<String> _interceptedApps = {};
  static bool _isRunning = false;
  static DateTime? _lastInterceptionTime;
  static String? _lastInterceptedApp;
  static int _interceptionCooldownSeconds = 10; // Prevent repeated interceptions
  
  static final NotificationService _notificationService = NotificationService();
  static final EducationalTaskService _taskService = EducationalTaskService();
  static final FocusPassWorkflowService _workflowService = FocusPassWorkflowService();

  /// Initialize the app interception service
  static Future<void> initialize() async {
    print('AppInterceptionService: Initializing...');
    
    await _loadInterceptedApps();
    await _notificationService.initialize();
    
    _startInterception();
    print('AppInterceptionService: Initialized and started');
  }

  /// Start monitoring for app launches
  static void _startInterception() {
    if (_isRunning) return;
    
    _isRunning = true;
    _interceptionTimer?.cancel();
    
    // Check every 2 seconds for app changes (more responsive than screen time service)
    _interceptionTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkForAppLaunch();
    });
    
    print('AppInterceptionService: Started app launch monitoring');
  }

  /// Check if a new app has been launched
  static Future<void> _checkForAppLaunch() async {
    try {
      if (!await ScreenTimeService.hasUsageStatsPermission()) {
        return;
      }

      // Get current app usage in the last 5 seconds
      final endTime = DateTime.now();
      final startTime = endTime.subtract(const Duration(seconds: 5));
      
      final usageStats = await NativeUsageStatsService.queryUsageStats(startTime, endTime);
      
      // Find the most recently used app
      String? currentApp = await _getMostRecentApp(usageStats);
      
      if (currentApp != null && currentApp != _lastActiveApp) {
        print('AppInterceptionService: App changed from $_lastActiveApp to $currentApp');
        
        if (await _shouldInterceptApp(currentApp)) {
          print('AppInterceptionService: Intercepting $currentApp');
          await _interceptApp(currentApp);
        }
        
        _lastActiveApp = currentApp;
      }
    } catch (e) {
      print('AppInterceptionService: Error checking app launch: $e');
    }
  }

  /// Get the most recently used app from usage stats
  static Future<String?> _getMostRecentApp(List<dynamic> usageStats) async {
    if (usageStats.isEmpty) return null;
    
    String? mostRecentPackage;
    int maxUsage = 0;
    
    for (final stat in usageStats) {
      final packageName = stat.packageName ?? '';
      if (packageName.isEmpty) continue;
      
      // Convert usage time safely
      final usageTimeRaw = stat.totalTimeInForeground ?? 0;
      int usageTime = 0;
      
      if (usageTimeRaw is int) {
        usageTime = usageTimeRaw;
      } else if (usageTimeRaw is String) {
        usageTime = int.tryParse(usageTimeRaw) ?? 0;
      } else if (usageTimeRaw is double) {
        usageTime = usageTimeRaw.toInt();
      }
      
      if (usageTime > maxUsage) {
        maxUsage = usageTime;
        mostRecentPackage = packageName; // Always return package name for consistency
      }
    }
    
    return mostRecentPackage;
  }

  /// Check if an app should be intercepted
  static Future<bool> _shouldInterceptApp(String packageName) async {
    // Prevent repeated interceptions of the same app within cooldown period
    if (_lastInterceptedApp == packageName && _lastInterceptionTime != null) {
      final timeSinceLastInterception = DateTime.now().difference(_lastInterceptionTime!);
      if (timeSinceLastInterception.inSeconds < _interceptionCooldownSeconds) {
        print('AppInterceptionService: Skipping interception of $packageName - within cooldown period (${timeSinceLastInterception.inSeconds}s < ${_interceptionCooldownSeconds}s)');
        return false;
      }
    }

    // Get app name from package (YouTube, TikTok, Chrome, etc.)
    final appName = await _getAppNameFromPackage(packageName);
    if (appName == null) return false; // Only intercept known apps
    
    // Use the workflow service to determine if app should be intercepted
    final accessResult = await _workflowService.handleAppAccessAttempt(appName);
    
    // Intercept if access is denied
    return !accessResult.isAllowed;
  }

  /// Intercept an app launch and redirect to educational content
  static Future<void> _interceptApp(String packageName) async {
    print('AppInterceptionService: Intercepting $packageName launch');
    
    try {
      // Record interception timing to prevent glitchy repeated interceptions
      _lastInterceptedApp = packageName;
      _lastInterceptionTime = DateTime.now();
      
      // Add to intercepted apps set to prevent repeated interceptions
      _interceptedApps.add(packageName);
      await _saveInterceptedApps();
      
      final childName = await _getCurrentChildName();
      if (childName == null) return;
      
      // Resolve display name for messaging
      final appName = await _getAppNameFromPackage(packageName) ?? packageName;
      
      // Check what type of interception this is
      final hasPendingTasks = await _taskService.hasPendingTasks(childName);
      final stats = ScreenTimeService.getCurrentUsageStats();
      final appStats = stats[packageName];
      final isBlocked = appStats?['isBlocked'] ?? false;
      
      if (hasPendingTasks) {
        await _handleEducationalTaskInterception(appName, childName);
      } else if (isBlocked) {
        await _handleTimeExceededInterception(appName);
      }
      
      // Try to bring FocusPass to foreground
      await _bringFocusPassToForeground();
      
      // Request the system to close the intercepted foreground app
      await _closeForegroundApp();
      
    } catch (e) {
      print('AppInterceptionService: Error intercepting app: $e');
    }
  }

  /// Handle interception for pending educational tasks
  static Future<void> _handleEducationalTaskInterception(String appName, String childName) async {
    print('AppInterceptionService: Handling educational task interception for $appName');
    
    final pendingTasks = await _taskService.fetchTasks(childName);
    final pendingCount = pendingTasks.where((task) => !task.isCompleted).length;
    
    // Show high-priority notification that requires completing tasks
    await _notificationService.showEducationalTaskInterception(
      blockedAppName: appName,
      pendingTaskCount: pendingCount,
      earnableTime: _calculateEarnableTime(pendingCount),
    );
    
    // Block the app with educational message
    await _showEducationalBlockingOverlay(appName, pendingCount);
  }

  /// Handle interception for time exceeded
  static Future<void> _handleTimeExceededInterception(String appName) async {
    print('AppInterceptionService: Handling time exceeded interception for $appName');
    
    final stats = ScreenTimeService.getCurrentUsageStats();
    final appStats = stats[appName];
    final dailyLimitMs = appStats?['dailyLimit'] ?? (1 * 60 * 60 * 1000);
    final dailyLimitHours = (dailyLimitMs / (1000 * 60 * 60)).toStringAsFixed(1);
    
    // Show time exceeded notification
    await _notificationService.showTimeExceededNotification(
      appName: appName,
      timeLimit: '${dailyLimitHours}h',
    );
    
    // Block the app with time exceeded message
    await _showTimeExceededBlockingOverlay(appName, dailyLimitHours);
  }

  /// Calculate how much time can be earned from completing tasks
  static int _calculateEarnableTime(int taskCount) {
    // Each task can earn 15 minutes of screen time
    return taskCount * 15;
  }

  /// Show educational blocking overlay
  static Future<void> _showEducationalBlockingOverlay(String appName, int pendingCount) async {
    const platform = MethodChannel('com.focuspass.app_blocker');
    try {
      await platform.invokeMethod('showEducationalBlockingOverlay', {
        'appName': appName,
        'title': '📚 Complete Your Learning Tasks First!',
        'message': 'You have $pendingCount educational tasks to complete before accessing $appName.',
        'earnableTime': '${_calculateEarnableTime(pendingCount)} minutes',
        'actionText': 'Open FocusPass to Complete Tasks',
        'actionType': 'educational_tasks'
      });
    } catch (e) {
      print('AppInterceptionService: Error showing educational blocking overlay: $e');
    }
  }

  /// Show time exceeded blocking overlay
  static Future<void> _showTimeExceededBlockingOverlay(String appName, String timeLimit) async {
    const platform = MethodChannel('com.focuspass.app_blocker');
    try {
      await platform.invokeMethod('showTimeExceededBlockingOverlay', {
        'appName': appName,
        'title': '⏰ Daily Time Limit Reached',
        'message': 'You\'ve reached your ${timeLimit}h daily limit for $appName.',
        'actionText': 'Complete Tasks to Earn More Time',
        'actionType': 'time_exceeded'
      });
    } catch (e) {
      print('AppInterceptionService: Error showing time exceeded blocking overlay: $e');
    }
  }

  /// Bring FocusPass app to foreground
  static Future<void> _bringFocusPassToForeground() async {
    const platform = MethodChannel('com.focuspass.app_launcher');
    try {
      await platform.invokeMethod('bringToForeground');
      print('AppInterceptionService: Attempted to bring FocusPass to foreground');
    } catch (e) {
      print('AppInterceptionService: Error bringing FocusPass to foreground: $e');
    }
  }

  /// Ask the native layer to close the current foreground app (requires implementation on Android)
  static Future<void> _closeForegroundApp() async {
    const platform = MethodChannel('com.focuspass.app_blocker');
    try {
      await platform.invokeMethod('closeForegroundApp');
      print('AppInterceptionService: Requested to close foreground app');
    } catch (e) {
      print('AppInterceptionService: Error requesting app close: $e');
    }
  }

  /// Clear interception for an app (called when tasks are completed)
  static Future<void> clearInterceptionForApp(String appName) async {
    _interceptedApps.remove(appName);
    await _saveInterceptedApps();
    print('AppInterceptionService: Cleared interception for $appName');
  }

  /// Clear all interceptions (called on daily reset)
  static Future<void> clearAllInterceptions() async {
    _interceptedApps.clear();
    await _saveInterceptedApps();
    print('AppInterceptionService: Cleared all interceptions');
  }

  /// Check if educational tasks were completed and update app access
  static Future<void> checkTaskCompletionAndUpdateAccess() async {
    final childName = await _getCurrentChildName();
    if (childName == null) return;
    
    final hasPendingTasks = await _taskService.hasPendingTasks(childName);
    
    if (!hasPendingTasks) {
      // All tasks completed, clear educational interceptions
      await clearAllInterceptions();
      
      // Success notification is now handled in-app
      
      print('AppInterceptionService: All educational tasks completed, access granted');
    }
  }

  /// Get app name from package name
  static Future<String?> _getAppNameFromPackage(String packageName) async {
    // Use the same logic as ScreenTimeService
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
      'com.android.chrome': 'Chrome', // Add Chrome support
    };
    
    return knownApps[packageName];
  }

  /// Clear cooldown for a specific app (used when session expires)
  static Future<void> clearCooldownForApp(String appName) async {
    // Map display name back to package name
    final reverseMap = {
      'YouTube': 'com.google.android.youtube',
      'Instagram': 'com.instagram.android',
      'TikTok': 'com.zhiliaoapp.musically',
      'Snapchat': 'com.snapchat.android',
      'Twitter': 'com.twitter.android',
      'Facebook': 'com.facebook.katana',
      'WhatsApp': 'com.whatsapp',
      'Spotify': 'com.spotify.music',
      'Netflix': 'com.netflix.mediaclient',
      'Discord': 'com.discord',
      'Chrome': 'com.android.chrome',
    };
    
    final packageName = reverseMap[appName] ?? appName;
    
    if (_lastInterceptedApp == packageName) {
      _lastInterceptedApp = null;
      _lastInterceptionTime = null;
      print('AppInterceptionService: Cleared cooldown for $appName ($packageName)');
    }
  }

  /// Get current child name
  static Future<String?> _getCurrentChildName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_child_name');
  }

  /// Load intercepted apps from preferences
  static Future<void> _loadInterceptedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final interceptedList = prefs.getStringList(_interceptedAppsKey) ?? [];
    _interceptedApps = interceptedList.toSet();
  }

  /// Save intercepted apps to preferences
  static Future<void> _saveInterceptedApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_interceptedAppsKey, _interceptedApps.toList());
  }

  /// Stop the interception service
  static void stop() {
    _isRunning = false;
    _interceptionTimer?.cancel();
    _interceptionTimer = null;
    print('AppInterceptionService: Stopped');
  }

  /// Restart the interception service
  static void restart() {
    stop();
    _startInterception();
  }
}
