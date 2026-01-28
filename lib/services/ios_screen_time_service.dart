import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IOSScreenTimeService {
  static const String _earnedTimeKey = 'earned_time_';
  static const String _screenTimeRulesKey = 'screen_time_rules';
  static const String _restrictedAppsKey = 'restricted_apps';
  
  // iOS Screen Time API channel
  static const MethodChannel _screenTimeChannel = MethodChannel('com.focuspass.screentime');
  
  static Map<String, double> _screenTimeRules = {};
  static List<String> _restrictedApps = [];
  static double _earnedTimeToday = 0;

  /// Initialize iOS Screen Time integration
  static Future<void> initialize() async {
    if (!Platform.isIOS) return;
    
    await _loadStoredData();
    await _syncWithFirestore();
    await _requestScreenTimePermission();
  }

  /// Request Screen Time permission (iOS 15.0+)
  static Future<bool> _requestScreenTimePermission() async {
    try {
      final bool granted = await _screenTimeChannel.invokeMethod('requestAuthorization');
      return granted;
    } catch (e) {
      print('Error requesting Screen Time permission: $e');
      return false;
    }
  }

  /// Check if Screen Time authorization is granted
  static Future<bool> hasScreenTimePermission() async {
    try {
      final bool authorized = await _screenTimeChannel.invokeMethod('isAuthorized');
      return authorized;
    } catch (e) {
      return false;
    }
  }

  /// Set up app restrictions using iOS Screen Time API
  static Future<void> configureAppRestrictions() async {
    if (!await hasScreenTimePermission()) return;
    
    try {
      final dailyLimitMs = _screenTimeRules['dailyLimit'] ?? (2 * 60 * 60 * 1000);
      final dailyLimitMinutes = (dailyLimitMs / (1000 * 60)).round();
      
      await _screenTimeChannel.invokeMethod('configureRestrictions', {
        'apps': _restrictedApps,
        'dailyLimitMinutes': dailyLimitMinutes,
        'earnedTimeMinutes': _earnedTimeToday.round(),
      });
    } catch (e) {
      print('Error configuring app restrictions: $e');
    }
  }

  /// Get current usage statistics from iOS Screen Time
  static Future<Map<String, dynamic>> getCurrentUsageStats() async {
    try {
      if (!await hasScreenTimePermission()) {
        return {};
      }

      final Map<dynamic, dynamic> rawStats = await _screenTimeChannel.invokeMethod('getUsageStats');
      final Map<String, dynamic> stats = {};
      
      final dailyLimitMs = _screenTimeRules['dailyLimit'] ?? (2 * 60 * 60 * 1000);
      final earnedTimeMs = _earnedTimeToday * 60 * 1000;
      
      for (final app in _restrictedApps) {
        final usageMinutes = rawStats[app] ?? 0;
        final usageMs = usageMinutes * 60 * 1000;
        final remainingMs = (dailyLimitMs + earnedTimeMs - usageMs).clamp(0.0, double.infinity);
        
        stats[app] = {
          'usedTime': usageMs.toInt(),
          'remainingTime': remainingMs,
          'dailyLimit': dailyLimitMs.toInt(),
          'earnedTime': earnedTimeMs,
          'isBlocked': usageMs > (dailyLimitMs + earnedTimeMs),
        };
      }
      
      return stats;
    } catch (e) {
      print('Error getting usage stats: $e');
      return {};
    }
  }

  /// Add earned screen time
  static Future<void> addEarnedTime(double minutes) async {
    _earnedTimeToday += minutes;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setDouble('$_earnedTimeKey$today', _earnedTimeToday);
    
    // Update iOS Screen Time restrictions with new earned time
    await configureAppRestrictions();
  }

  /// Load stored data from SharedPreferences
  static Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Load earned time
    final earnedTime = prefs.getDouble('$_earnedTimeKey$today') ?? 0.0;
    _earnedTimeToday = earnedTime;
  }

  /// Sync with Firestore to get latest rules and restrictions
  static Future<void> _syncWithFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get current child's data
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
          double dailyLimit = 1.0; // default

          if (rulesData['applySameForAll'] == true) {
            dailyLimit = (rulesData['unifiedRules']?['limit'] ?? 1.0).toDouble();
          } else {
            final childrenRules = rulesData['children'] as Map<String, dynamic>? ?? {};
            dailyLimit = (childrenRules[childName]?['limit'] ?? 1.0).toDouble();
          }

          // Convert hours to milliseconds
          _screenTimeRules['dailyLimit'] = dailyLimit * 60 * 60 * 1000;
        }

        // Get restricted apps from child data
        final childData = childDoc.data();
        _restrictedApps = List<String>.from(childData['selectedApps'] ?? []);
        
        // Configure iOS restrictions
        await configureAppRestrictions();
      }
    } catch (e) {
      print('Error syncing with Firestore: $e');
    }
  }

  /// Get current child name
  static Future<String?> _getCurrentChildName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_child_name');
  }

  /// Set current child name
  static Future<void> setCurrentChildName(String childName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_child_name', childName);
  }

  /// Update screen time rules
  static Future<void> updateScreenTimeRules() async {
    await _syncWithFirestore();
  }
}
