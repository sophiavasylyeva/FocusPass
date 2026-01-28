import 'dart:async';
import 'package:flutter/material.dart';

class OverlayNotificationService {
  static final OverlayNotificationService _instance = OverlayNotificationService._internal();
  factory OverlayNotificationService() => _instance;
  OverlayNotificationService._internal();

  static OverlayEntry? _currentOverlay;
  static Timer? _dismissTimer;

  /// Show a real-time overlay notification on screen
  static void showOverlayNotification({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.info,
    Color backgroundColor = Colors.blue,
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onTap,
  }) {
    // Remove any existing overlay
    hideOverlayNotification();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    _currentOverlay = OverlayEntry(
      builder: (context) => _OverlayNotificationWidget(
        title: title,
        message: message,
        icon: icon,
        backgroundColor: backgroundColor,
        onTap: onTap,
        onDismiss: hideOverlayNotification,
      ),
    );

    overlay.insert(_currentOverlay!);

    // Auto-dismiss after duration
    _dismissTimer = Timer(duration, () {
      hideOverlayNotification();
    });
  }

  /// Hide the current overlay notification
  static void hideOverlayNotification() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Show screen time warning notification
  static void showScreenTimeWarning({
    required BuildContext context,
    required String appName,
    required int remainingMinutes,
  }) {
    showOverlayNotification(
      context: context,
      title: '⚠️ Screen Time Warning',
      message: 'Only $remainingMinutes minutes left for $appName!',
      icon: Icons.timer,
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 8),
    );
  }

  /// Show time exceeded notification
  static void showTimeExceeded({
    required BuildContext context,
    required String appName,
  }) {
    showOverlayNotification(
      context: context,
      title: '🚫 Time Limit Reached',
      message: 'Your time limit for $appName has been reached. Complete learning tasks to earn more time!',
      icon: Icons.block,
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 10),
    );
  }

  /// Show educational task notification
  static void showEducationalTaskNotification({
    required BuildContext context,
    required String appName,
    required int pendingTasks,
    VoidCallback? onOpenTasks,
  }) {
    showOverlayNotification(
      context: context,
      title: '📚 Complete Tasks First!',
      message: 'You have $pendingTasks pending tasks. Complete them to unlock $appName and earn screen time!',
      icon: Icons.school,
      backgroundColor: const Color.fromARGB(255, 76, 175, 80),
      duration: const Duration(seconds: 12),
      onTap: onOpenTasks,
    );
  }

  /// Show tasks completed notification
  static void showTasksCompleted({
    required BuildContext context,
    required int earnedMinutes,
  }) {
    showOverlayNotification(
      context: context,
      title: '🎉 Tasks Completed!',
      message: 'Great job! You earned $earnedMinutes minutes of screen time. Apps are now unlocked!',
      icon: Icons.celebration,
      backgroundColor: const Color.fromARGB(255, 76, 175, 80),
      duration: const Duration(seconds: 8),
    );
  }
}

class _OverlayNotificationWidget extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const _OverlayNotificationWidget({
    required this.title,
    required this.message,
    required this.icon,
    required this.backgroundColor,
    this.onTap,
    this.onDismiss,
  });

  @override
  State<_OverlayNotificationWidget> createState() => _OverlayNotificationWidgetState();
}

class _OverlayNotificationWidgetState extends State<_OverlayNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: widget.onTap ?? _dismiss,
                    child: Row(
                      children: [
                        Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _dismiss,
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
