import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'notification_service.dart';
import 'educational_task_service.dart';
import 'screen_time_service.dart';
import 'app_interception_service.dart';

/// FocusPassWorkflowService orchestrates the complete workflow:
/// 1. Child accesses app -> Check if tasks are pending
/// 2. If tasks pending -> Show educational task notification
/// 3. If tasks completed -> Grant app access with earned time
/// 4. During usage -> Show periodic reminders every 15 minutes
/// 5. When session ends -> Show session expired notification
/// 6. When daily limit reached -> Show final notification with parental PIN option
class FocusPassWorkflowService {
  static final FocusPassWorkflowService _instance = FocusPassWorkflowService._internal();
  factory FocusPassWorkflowService() => _instance;
  FocusPassWorkflowService._internal();

  final NotificationService _notificationService = NotificationService();
  final EducationalTaskService _taskService = EducationalTaskService();
  
  Timer? _sessionTimer;
  Timer? _reminderTimer;
  String? _currentActiveApp;
  DateTime? _sessionStartTime;
  int? _sessionDurationMinutes;
  
  bool _isInitialized = false;

  /// Initialize the workflow service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _notificationService.initialize();
    print('FocusPassWorkflowService: Initialized');
    _isInitialized = true;
  }

  /// Handle app access attempt - main entry point for the workflow
  Future<AppAccessResult> handleAppAccessAttempt(String appName) async {
    if (!_isInitialized) await initialize();
    
    print('FocusPassWorkflowService: Handling app access attempt for $appName');
    
    final childName = await _getCurrentChildName();
    if (childName == null) {
      print('FocusPassWorkflowService: No child name found');
      return AppAccessResult.denied('Child profile not found');
    }

    // Step 1: Ensure child has 5 tasks for today (generate if needed)
    await _ensureTasksForToday(childName);
    
    // Step 2: Check if child has completed enough tasks to earn access
    final tasks = await _taskService.fetchTasks(childName);
    final today = DateTime.now();
    
    final todayTasks = tasks.where((task) {
      return task.assignedAt.day == today.day &&
             task.assignedAt.month == today.month &&
             task.assignedAt.year == today.year;
    }).toList();
    
    final pendingTasks = todayTasks.where((task) => !task.isCompleted).toList();
    final completedTasks = todayTasks.where((task) => task.isCompleted).toList();
    
    print('FocusPassWorkflowService: Today tasks - Total: ${todayTasks.length}, Pending: ${pendingTasks.length}, Completed: ${completedTasks.length}');
    
    // Check if child has any unused 15-minute sessions from completed sets of 5 tasks
    final completedSets = (completedTasks.length / 5).floor();
    final usedSessions = await _getUsedSessionsToday(childName);
    final availableSessions = completedSets - usedSessions;
    
    if (availableSessions <= 0) {
      // Need to complete 5 tasks to earn next 15-minute session
      final tasksNeeded = 5 - (completedTasks.length % 5);
      
      await _notificationService.showEducationalTaskNotification(
        blockedAppName: appName,
        pendingTaskCount: tasksNeeded,
      );
      
      print('FocusPassWorkflowService: Access denied - need to complete $tasksNeeded more tasks (have completed ${completedTasks.length} tasks today)');
      return AppAccessResult.denied('Complete your educational task first to earn 15 minutes of screen time');
    }

    // Step 3: Check if child has exceeded daily limit
    final totalUsedMinutesToday = await _getTotalUsedMinutesToday(childName);
    final dailyLimitMinutes = await _getDailyLimitMinutes(childName);
    
    if (totalUsedMinutesToday >= dailyLimitMinutes) {
      // Show notification about daily limit reached
      await _notificationService.showDailyLimitReachedNotification(appName: appName);
      
      // Show visual blocking overlay to make apps truly "unclickable"
      await _showDailyLimitBlockingOverlay(appName, totalUsedMinutesToday, dailyLimitMinutes);
      
      print('FocusPassWorkflowService: Access denied - daily limit reached ($totalUsedMinutesToday/${dailyLimitMinutes} minutes)');
      return AppAccessResult.denied('Daily screen time limit reached. Parental PIN required.');
    }

    // Step 4: Grant access for exactly 15-minute session
    const sessionMinutes = 15; // Each completed set of 5 tasks = exactly 15 minutes
    
    // Show access granted notification
    await _notificationService.showAppAccessGrantedWithTime(
      appName: appName,
      earnedMinutes: sessionMinutes,
      totalRemainingMinutes: sessionMinutes,
    );
    
    // Start session tracking for 15 minutes
    await _startAppSession(appName, sessionMinutes);
    
    // Record that one session is now being used
    await _recordSessionUsed(childName);
    
    print('FocusPassWorkflowService: Access granted - 15 minutes session started');
    return AppAccessResult.allowed(timeRemainingMinutes: sessionMinutes);
  }

  /// Start tracking an app session with notifications
  Future<void> _startAppSession(String appName, int remainingMinutes) async {
    // Cancel any existing session and scheduled notifications
    await _endAppSession();
    await _cancelScheduledNotifications();
    
    _currentActiveApp = appName;
    _sessionStartTime = DateTime.now();
    _sessionDurationMinutes = remainingMinutes;
    
    print('FocusPassWorkflowService: 🚀 Starting session for $appName - $remainingMinutes minutes');
    print('FocusPassWorkflowService: Session timer will expire at ${DateTime.now().add(Duration(minutes: remainingMinutes))}');
    
    // Start periodic reminders every 5 minutes for better tracking
    _reminderTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (_currentActiveApp != null) {
        final elapsed = DateTime.now().difference(_sessionStartTime!).inMinutes;
        final remaining = remainingMinutes - elapsed;
        
        if (remaining > 0) {
          // Show warning when 5 minutes or less remaining
          if (remaining <= 5) {
            await _notificationService.showUsageReminderNotification(
              appName: _currentActiveApp!,
              remainingMinutes: remaining,
              isWarning: true,
            );
          }
        } else {
          // Session has expired
          await _handleSessionExpired();
        }
      }
    });
    
    // Set timer for when session should end
    if (remainingMinutes > 0) {
      _sessionTimer = Timer(Duration(minutes: remainingMinutes), () async {
        await _handleSessionExpired();
      });
      
      // Also schedule a notification to fire at the exact expiration time
      // This works even when the app is in background
      await _scheduleSessionExpirationNotification(appName, remainingMinutes);
    }
  }

  /// Cancel any scheduled session expiration notifications
  Future<void> _cancelScheduledNotifications() async {
    try {
      await _notificationService.cancelScheduledSessionNotifications();
      print('FocusPassWorkflowService: Cancelled any existing scheduled notifications');
    } catch (e) {
      print('FocusPassWorkflowService: Error cancelling scheduled notifications: $e');
    }
  }

  /// Schedule a notification to fire when the session expires
  /// This works even when the app is in background, unlike Timer
  Future<void> _scheduleSessionExpirationNotification(String appName, int minutes) async {
    try {
      final expirationTime = DateTime.now().add(Duration(minutes: minutes));
      print('FocusPassWorkflowService: Scheduling session expiration notification for $appName at $expirationTime');
      
      // Schedule the notification to fire at the exact expiration time
      await _notificationService.scheduleSessionExpiredNotification(
        appName: appName,
        sessionMinutes: minutes,
        scheduledDateTime: expirationTime,
      );
    } catch (e) {
      print('FocusPassWorkflowService: Error scheduling session expiration notification: $e');
    }
  }

  /// Handle session expiration
  Future<void> _handleSessionExpired() async {
    if (_currentActiveApp == null) {
      print('FocusPassWorkflowService: Session expired but no active app found');
      return;
    }
    
    final appName = _currentActiveApp!;
    final duration = _sessionDurationMinutes ?? 0;
    
    print('FocusPassWorkflowService: ⏰ SESSION EXPIRED for $appName after exactly $duration minutes');
    
    // Show the session expired notification with clear message about completing 5 more tasks
    await _notificationService.showSessionExpiredNotification(
      appName: appName,
      sessionMinutes: duration,
    );
    
    // Also trigger the blocking overlay to force app exit
    await _showSessionExpiredOverlay(appName);
    
    // Clear the session cooldown in app interception to allow immediate re-blocking
    await _clearInterceptionCooldown(appName);
    
    print('FocusPassWorkflowService: Session expired notification and overlay sent - user must complete 5 more tasks');
    
    await _endAppSession();
  }

  /// Show blocking overlay when session expires
  Future<void> _showSessionExpiredOverlay(String appName) async {
    try {
      const platform = MethodChannel('com.focuspass.app_blocker');
      await platform.invokeMethod('showTimeExceededBlockingOverlay', {
        'appName': appName,
        'title': '⏰ 15 Minutes Up!',
        'message': 'Your 15-minute $appName session is over. Complete 5 more educational tasks to earn another 15 minutes!',
        'actionText': 'Complete 5 More Tasks',
        'actionType': 'session_expired'
      });
      print('FocusPassWorkflowService: Session expired overlay triggered for $appName');
    } catch (e) {
      print('FocusPassWorkflowService: Error showing session expired overlay: $e');
    }
  }

  /// Show blocking overlay when daily limit is reached - makes apps unclickable
  Future<void> _showDailyLimitBlockingOverlay(String appName, int usedMinutes, int limitMinutes) async {
    try {
      const platform = MethodChannel('com.focuspass.app_blocker');
      final usedHours = (usedMinutes / 60).toStringAsFixed(1);
      final limitHours = (limitMinutes / 60).toStringAsFixed(1);
      
      await platform.invokeMethod('showDailyLimitBlockingOverlay', {
        'appName': appName,
        'title': '🚫 Daily Screen Time Limit Reached',
        'message': 'You have used ${usedHours}h of your ${limitHours}h daily limit for $appName. All screen time has been used up for today.',
        'actionText': '🔐 Enter Parental PIN',
        'secondaryActionText': 'Exit Application',
        'actionType': 'daily_limit_reached',
        'usedMinutes': usedMinutes,
        'limitMinutes': limitMinutes
      });
      print('FocusPassWorkflowService: Daily limit blocking overlay triggered for $appName ($usedMinutes/$limitMinutes minutes used)');
    } catch (e) {
      print('FocusPassWorkflowService: Error showing daily limit blocking overlay: $e');
    }
  }

  /// End current app session
  Future<void> _endAppSession() async {
    _sessionTimer?.cancel();
    _reminderTimer?.cancel();
    _currentActiveApp = null;
    _sessionStartTime = null;
    _sessionDurationMinutes = null;
    
    print('FocusPassWorkflowService: Session ended');
  }

  /// Handle educational tasks completion
  Future<void> onEducationalTasksCompleted(String childName) async {
    print('FocusPassWorkflowService: Educational tasks completed for $childName');
    
    // Get earned time information
    final tasks = await _taskService.fetchTasks(childName);
    final completedToday = tasks.where((task) {
      final today = DateTime.now();
      return task.isCompleted && 
             task.completedAt != null &&
             task.completedAt!.day == today.day &&
             task.completedAt!.month == today.month &&
             task.completedAt!.year == today.year;
    }).toList();
    
    final totalEarnedMinutes = completedToday.fold<int>(
      0, 
      (sum, task) => sum + task.screenTimeRewardMinutes
    );
    
    // Completion notification is now handled in-app
    
    // If there was a blocked app, the child can now try to access it again
    print('FocusPassWorkflowService: Tasks completed, earned $totalEarnedMinutes minutes');
  }

  /// Handle parental PIN override
  Future<bool> handleParentalPinOverride(String appName, String enteredPin) async {
    final isValidPin = await _verifyParentalPin(enteredPin);
    
    if (isValidPin) {
      print('FocusPassWorkflowService: Parental PIN verified, granting unlimited access to $appName');
      
      // Grant unlimited access for the current session
      await _startAppSession(appName, 999999); // Very long session
      
      return true;
    } else {
      print('FocusPassWorkflowService: Invalid parental PIN entered');
      return false;
    }
  }

  /// Verify parental PIN
  Future<bool> _verifyParentalPin(String enteredPin) async {
    try {
      final childName = await _getCurrentChildName();
      if (childName == null) return false;
      
      // Find parent UID by looking up child
      final childQuery = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('name', isEqualTo: childName)
          .get();
      
      if (childQuery.docs.isEmpty) return false;
      
      final parentUid = childQuery.docs.first.reference.parent.parent!.id;
      
      // Get parent's PIN
      final parentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .get();
      
      if (!parentDoc.exists) return false;
      
      final storedPin = parentDoc.data()?['pin'] as String?;
      return storedPin == enteredPin;
      
    } catch (e) {
      print('FocusPassWorkflowService: Error verifying PIN: $e');
      return false;
    }
  }

  /// Get current child name
  Future<String?> _getCurrentChildName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_child_name');
  }

  /// Get learning to screen time ratio for child
  Future<double> _getLearningRatio(String childName) async {
    try {
      // Find parent UID
      final childQuery = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('name', isEqualTo: childName)
          .get();
      
      if (childQuery.docs.isEmpty) return 1.0; // Default ratio
      
      final parentUid = childQuery.docs.first.reference.parent.parent!.id;
      
      // Get screen time rules
      final rulesDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .collection('settings')
          .doc('screenTimeRules')
          .get();
      
      if (!rulesDoc.exists) return 1.0;
      
      final data = rulesDoc.data()!;
      
      if (data['applySameForAll'] == true) {
        return (data['unifiedRules']?['ratio'] ?? 1.0).toDouble();
      } else {
        final childrenData = data['children'] as Map<String, dynamic>? ?? {};
        return (childrenData[childName]?['ratio'] ?? 1.0).toDouble();
      }
      
    } catch (e) {
      print('FocusPassWorkflowService: Error getting ratio: $e');
      return 1.0;
    }
  }

  /// Get used sessions count for today
  Future<int> _getUsedSessionsToday(String childName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final key = '${childName}_used_sessions_${today.year}_${today.month}_${today.day}';
      return prefs.getInt(key) ?? 0;
    } catch (e) {
      print('FocusPassWorkflowService: Error getting used sessions: $e');
      return 0;
    }
  }

  /// Record that a 15-minute session has been used
  Future<void> _recordSessionUsed(String childName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final sessionsKey = '${childName}_used_sessions_${today.year}_${today.month}_${today.day}';
      final minutesKey = '${childName}_used_minutes_${today.year}_${today.month}_${today.day}';
      
      final currentUsed = prefs.getInt(sessionsKey) ?? 0;
      final currentMinutes = prefs.getInt(minutesKey) ?? 0;
      
      await prefs.setInt(sessionsKey, currentUsed + 1);
      await prefs.setInt(minutesKey, currentMinutes + 15);
      
      print('FocusPassWorkflowService: Recorded session used for $childName. Total today: ${currentUsed + 1} sessions (${currentMinutes + 15} minutes)');
    } catch (e) {
      print('FocusPassWorkflowService: Error recording session used: $e');
    }
  }

  /// Get total used minutes for today
  Future<int> _getTotalUsedMinutesToday(String childName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final key = '${childName}_used_minutes_${today.year}_${today.month}_${today.day}';
      return prefs.getInt(key) ?? 0;
    } catch (e) {
      print('FocusPassWorkflowService: Error getting used minutes: $e');
      return 0;
    }
  }

  /// Get daily limit in minutes for child
  Future<int> _getDailyLimitMinutes(String childName) async {
    try {
      // Find parent UID
      final childQuery = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('name', isEqualTo: childName)
          .get();
      
      if (childQuery.docs.isEmpty) return 60; // Default 1 hour
      
      final parentUid = childQuery.docs.first.reference.parent.parent!.id;
      
      // Get screen time rules
      final rulesDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .collection('settings')
          .doc('screenTimeRules')
          .get();
      
      if (!rulesDoc.exists) return 60; // Default 1 hour
      
      final data = rulesDoc.data()!;
      double limitHours;
      
      if (data['applySameForAll'] == true) {
        limitHours = (data['unifiedRules']?['limit'] ?? 2.0).toDouble();
      } else {
        final childrenData = data['children'] as Map<String, dynamic>? ?? {};
        limitHours = (childrenData[childName]?['limit'] ?? 2.0).toDouble();
      }
      
      return (limitHours * 60).round(); // Convert hours to minutes
      
    } catch (e) {
      print('FocusPassWorkflowService: Error getting daily limit: $e');
      return 60; // Default 1 hour
    }
  }

  /// Ensure child has 5 tasks available for today
  Future<void> _ensureTasksForToday(String childName) async {
    try {
      // Get child's preferences for task generation
      final childQuery = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('name', isEqualTo: childName)
          .get();
      
      if (childQuery.docs.isEmpty) return;
      
      final childData = childQuery.docs.first.data();
      final subjects = List<String>.from(childData['subjectsOfInterest'] ?? ['Math', 'English', 'Science']);
      final ageRange = childData['ageRange'] ?? '14-16';
      
      // Generate tasks if needed
      await _taskService.generateDailyTasks(childName, subjects, ageRange);
      
    } catch (e) {
      print('FocusPassWorkflowService: Error ensuring tasks for today: $e');
      // Fallback - generate with default subjects
      await _taskService.generateDailyTasks(childName, ['Math', 'English', 'Science'], '14-16');
    }
  }

  /// Clear interception cooldown to allow immediate re-blocking after session expires
  Future<void> _clearInterceptionCooldown(String appName) async {
    try {
      await AppInterceptionService.clearCooldownForApp(appName);
      print('FocusPassWorkflowService: Cleared interception cooldown for $appName');
    } catch (e) {
      print('FocusPassWorkflowService: Error clearing interception cooldown: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _sessionTimer?.cancel();
    _reminderTimer?.cancel();
    _notificationService.dispose();
  }
}

/// Result of app access attempt
class AppAccessResult {
  final bool isAllowed;
  final String? reason;
  final int? timeRemainingMinutes;
  final bool unlimited;

  const AppAccessResult._({
    required this.isAllowed,
    this.reason,
    this.timeRemainingMinutes,
    this.unlimited = false,
  });

  factory AppAccessResult.allowed({
    int? timeRemainingMinutes,
    bool unlimited = false,
  }) {
    return AppAccessResult._(
      isAllowed: true,
      timeRemainingMinutes: timeRemainingMinutes,
      unlimited: unlimited,
    );
  }

  factory AppAccessResult.denied(String reason) {
    return AppAccessResult._(
      isAllowed: false,
      reason: reason,
    );
  }
}
