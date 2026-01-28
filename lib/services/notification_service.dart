import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _notificationChannelId = 'screen_time_reminders';
  static const String _notificationChannelName = 'Screen Time Reminders';
  static const String _notificationChannelDescription = 'Notifications about remaining screen time';

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Timer? _notificationTimer;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();
    
    // Request notification permission for Android 13+
    await _requestNotificationPermission();

    _isInitialized = true;
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: _notificationChannelDescription,
      importance: Importance.max,
      enableVibration: true,
      showBadge: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    print('Notification tapped: ${notificationResponse.payload}');
    
    // Handle different notification types
    if (notificationResponse.payload == 'educational_tasks' || 
        notificationResponse.actionId == 'open_focuspass') {
      print('Educational task notification tapped - attempting to open FocusPass');
      _openFocusPassApp();
    }
  }
  
  /// Attempt to open or bring FocusPass to foreground
  void _openFocusPassApp() {
    try {
      // This is a simplified approach - ideally we'd use platform channels
      // to properly bring the app to foreground or launch it
      print('Attempting to open FocusPass app');
      
      // For now, we'll rely on the notification action to guide users
      // In a production app, you'd implement platform-specific code
      // to actually launch or bring the app to foreground
    } catch (e) {
      print('Error opening FocusPass app: $e');
    }
  }

  Future<void> startPeriodicNotifications({
    required String currentAppPackage,
    required Function(String) getRemainingTime,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Cancel any existing timer
    _notificationTimer?.cancel();

    // Start periodic timer for every 15 minutes
    _notificationTimer = Timer.periodic(
      const Duration(minutes: 15),
      (timer) async {
        final remainingTime = getRemainingTime(currentAppPackage);
        await _showScreenTimeNotification(
          appPackage: currentAppPackage,
          remainingTime: remainingTime,
        );
      },
    );
  }

  Future<void> _showScreenTimeNotification({
    required String appPackage,
    required String remainingTime,
  }) async {
    // Get app name from package
    final appName = await _getAppNameFromPackage(appPackage);
    
    // Don't show notification if time is unlimited or already exceeded
    if (remainingTime.contains('unlimited') || remainingTime.contains('exceeded')) {
      return;
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      '⏰ Screen Time Reminder',
      'You have $remainingTime left for $appName',
      platformChannelSpecifics,
      payload: appPackage,
    );
  }

  Future<String> _getAppNameFromPackage(String packageName) async {
    // Try to get a user-friendly name, fallback to package name
    final parts = packageName.split('.');
    return parts.isNotEmpty ? parts.last : packageName;
  }

  Future<void> stopPeriodicNotifications() async {
    _notificationTimer?.cancel();
    _notificationTimer = null;
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> showTimeExceededNotification({
    required String appName,
    required String timeLimit,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: true,
      color: Color.fromARGB(255, 244, 67, 54), // Red color for exceeded time
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      999999, // Fixed ID for time exceeded notifications
      '🚫 Time Limit Reached',
      'Your $timeLimit time limit for $appName has been reached. Please close the app.',
      platformChannelSpecifics,
      payload: 'time_exceeded',
    );
  }

  Future<void> showWarningNotification({
    required String appName,
    required String remainingTime,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: true,
      color: Color.fromARGB(255, 255, 152, 0), // Orange color for warning
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      888888, // Fixed ID for warning notifications
      '⚠️ Screen Time Warning',
      'Only $remainingTime left for $appName!',
      platformChannelSpecifics,
      payload: 'warning',
    );
  }

  /// Show notification when child accesses a restricted app but has pending educational tasks
  Future<void> showEducationalTaskNotification({
    required String blockedAppName,
    required int pendingTaskCount,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.max, // Highest priority
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: false, // Don't auto-cancel, force user interaction
      ongoing: true, // Make it persistent
      fullScreenIntent: true, // Show as full screen on some devices
      color: Color.fromARGB(255, 76, 175, 80), // Green color for educational tasks
      actions: [
        AndroidNotificationAction(
          'open_focuspass',
          '📚 Complete Tasks',
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'dismiss',
          'Later',
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final taskText = pendingTaskCount == 1 ? 'task' : 'tasks';
    await _flutterLocalNotificationsPlugin.show(
      777777, // Fixed ID for educational task notifications
      '📚 Complete your educational ${taskText} first to earn 15 minutes of screen time!',
      'You need to complete $pendingTaskCount more educational $taskText to unlock $blockedAppName.',
      platformChannelSpecifics,
      payload: 'educational_tasks',
    );
  }

  /// Show notification when app access is granted after completing tasks with remaining time info
  Future<void> showAppAccessGrantedWithTime({
    required String appName,
    required int earnedMinutes,
    required int totalRemainingMinutes,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: true,
      color: Color.fromARGB(255, 76, 175, 80), // Green for success
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final timeText = totalRemainingMinutes > 60 
        ? '${(totalRemainingMinutes / 60).floor()}h ${totalRemainingMinutes % 60}m'
        : '${totalRemainingMinutes}m';

    await _flutterLocalNotificationsPlugin.show(
      666555, // Fixed ID for app access granted notifications
      '✅ Tasks Complete - $appName Unlocked!',
      'You earned $earnedMinutes minutes! You have $timeText remaining today.',
      platformChannelSpecifics,
      payload: 'app_access_granted',
    );
  }

  /// Show notification during app usage to indicate remaining time (every 15 minutes)
  Future<void> showUsageReminderNotification({
    required String appName,
    required int remainingMinutes,
    required bool isWarning, // true if <= 15 minutes remaining
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: isWarning ? Importance.high : Importance.defaultImportance,
      priority: isWarning ? Priority.high : Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      enableVibration: isWarning,
      autoCancel: true,
      color: isWarning 
          ? Color.fromARGB(255, 255, 152, 0) // Orange for warning
          : Color.fromARGB(255, 33, 150, 243), // Blue for info
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final timeText = remainingMinutes > 60 
        ? '${(remainingMinutes / 60).floor()}h ${remainingMinutes % 60}m'
        : '${remainingMinutes}m';

    final title = isWarning ? '⚠️ Screen Time Warning' : '⏰ Screen Time Update';
    final message = isWarning 
        ? 'Only $timeText left for $appName today!'
        : 'You have $timeText remaining for $appName today';

    await _flutterLocalNotificationsPlugin.show(
      555444, // Fixed ID for usage reminder notifications
      title,
      message,
      platformChannelSpecifics,
      payload: 'usage_reminder',
    );
  }

  /// Schedule notification when screen time expires (after 15 min earned session)
  /// This works even when app is in background
  Future<void> scheduleSessionExpiredNotification({
    required String appName,
    required int sessionMinutes,
    required DateTime scheduledDateTime,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: false,
      ongoing: true,
      fullScreenIntent: true,
      color: Color.fromARGB(255, 244, 67, 54), // Red for time expired
      actions: [
        AndroidNotificationAction(
          'complete_more_tasks',
          '📚 Learn More',
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'exit_app',
          'Exit Application',
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      999998, // Unique ID for scheduled session expiration
      '⏰ 15 Minutes Up!',
      'Your 15-minute $appName session is over. Complete 5 more questions to earn another 15 minutes!',
      tz.TZDateTime.from(scheduledDateTime, tz.local),
      platformChannelSpecifics,
      payload: 'session_expired_scheduled',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    
    print('NotificationService: Scheduled session expiration notification for $appName at $scheduledDateTime');
  }

  /// Show notification when screen time expires (after 15 min earned session)
  Future<void> showSessionExpiredNotification({
    required String appName,
    required int sessionMinutes,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: false,
      ongoing: true,
      color: Color.fromARGB(255, 244, 67, 54), // Red for time expired
      actions: [
        AndroidNotificationAction(
          'complete_more_tasks',
          '📚 Learn More',
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'exit_app',
          'Exit Application',
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      444333, // Fixed ID for session expired notifications
      '⏰ 15 Minutes Up!',
      'Your 15-minute $appName session is over. Complete 5 more questions to earn another 15 minutes!',
      platformChannelSpecifics,
      payload: 'session_expired',
    );
  }

  /// Show high-priority educational task interception notification
  Future<void> showEducationalTaskInterception({
    required String blockedAppName,
    required int pendingTaskCount,
    required int earnableTime,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: false,
      ongoing: true,
      fullScreenIntent: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      usesChronometer: false,
      color: const Color.fromARGB(255, 255, 87, 34), // Deep orange for blocking
      styleInformation: BigTextStyleInformation(
        'Access to $blockedAppName is blocked until you complete $pendingTaskCount educational tasks. Each completed task earns you 15 minutes of screen time!',
        htmlFormatBigText: false,
        contentTitle: '🚫 $blockedAppName Blocked - Complete Tasks First!',
        htmlFormatContentTitle: false,
        summaryText: 'Earn $earnableTime minutes by completing tasks',
        htmlFormatSummaryText: false,
      ),
      actions: [
        AndroidNotificationAction(
          'open_focuspass',
          '📚 Complete Tasks Now',
          cancelNotification: false,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'remind_later',
          '⏰ Remind in 5 min',
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      666666, // Fixed ID for interception notifications
      '🚫 $blockedAppName Blocked - Complete Tasks First!',
      'Complete $pendingTaskCount tasks to unlock $blockedAppName and earn $earnableTime minutes!',
      platformChannelSpecifics,
      payload: 'educational_interception',
    );
  }

  /// Show notification when all educational tasks are completed
  Future<void> showTasksCompletedNotification() async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: true,
      color: Color.fromARGB(255, 76, 175, 80), // Green for success
      styleInformation: BigTextStyleInformation(
        'Excellent! You answered all questions correctly and completed 5 tasks, earning 15 minutes of screen time! 5 new educational tasks are now available for your next session.',
        htmlFormatBigText: false,
        contentTitle: '🎉 15 Minutes Earned!',
        htmlFormatContentTitle: false,
        summaryText: 'All answers correct - new tasks available',
        htmlFormatSummaryText: false,
      ),
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      555555, // Fixed ID for completion notifications
      '🎉 15 Minutes Earned!',
      'Excellent! You answered all questions correctly and completed 5 tasks, earning 15 minutes of screen time. 5 new tasks are ready for your next session.',
      platformChannelSpecifics,
      payload: 'tasks_completed',
    );
  }

  /// Show app access granted notification with time information
  Future<void> showAppAccessGrantedNotification({
    required String appName,
    required int remainingMinutes,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      enableVibration: false,
      autoCancel: true,
      color: Color.fromARGB(255, 33, 150, 243), // Blue for info
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final timeText = remainingMinutes > 60 
        ? '${(remainingMinutes / 60).floor()}h ${remainingMinutes % 60}m'
        : '${remainingMinutes}m';

    await _flutterLocalNotificationsPlugin.show(
      444444, // Fixed ID for access granted notifications
      '✅ $appName Access Granted',
      'You have $timeText of screen time remaining for today.',
      platformChannelSpecifics,
      payload: 'access_granted',
    );
  }

  /// Show final notification when daily screen time limit is reached with parental PIN override option
  Future<void> showDailyLimitReachedNotification({
    required String appName,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: false,
      ongoing: true,
      fullScreenIntent: true,
      color: Color.fromARGB(255, 244, 67, 54), // Red for final limit
      styleInformation: BigTextStyleInformation(
        'You have reached your daily screen time limit for $appName. All screen time has been used up for today. A parent can enter the 5-digit PIN to allow additional access.',
        htmlFormatBigText: false,
        contentTitle: '🚫 Daily Screen Time Limit Reached',
        htmlFormatContentTitle: false,
        summaryText: 'Parental PIN required for more access',
        htmlFormatSummaryText: false,
      ),
      actions: [
        AndroidNotificationAction(
          'enter_parental_pin',
          '🔐 Enter Parental PIN',
          cancelNotification: false,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'exit_app',
          'Exit Application',
          cancelNotification: true,
        ),
      ],
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      333222, // Fixed ID for daily limit reached notifications
      '🚫 Daily Screen Time Limit Reached',
      'You have used all your screen time for $appName today. Parental PIN required for more access.',
      platformChannelSpecifics,
      payload: 'daily_limit_reached',
    );
  }

  /// Cancel scheduled session expiration notifications
  Future<void> cancelScheduledSessionNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(999998);
      print('NotificationService: Cancelled scheduled session expiration notification');
    } catch (e) {
      print('NotificationService: Error cancelling scheduled notification: $e');
    }
  }

  /// Schedule weekly notification for specific day and time
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: true,
      color: Color.fromARGB(255, 33, 150, 243), // Blue for reports
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformChannelSpecifics,
      payload: 'weekly_report',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Repeat weekly
    );
  }

  /// Show immediate notification (for testing or direct calls)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: _notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      autoCancel: true,
      color: Color.fromARGB(255, 33, 150, 243),
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  void dispose() {
    _notificationTimer?.cancel();
  }
}
