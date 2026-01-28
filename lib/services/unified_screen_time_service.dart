// import 'dart:io';
// import 'screen_time_service.dart';
// import 'ios_screen_time_service.dart';
//
// class UnifiedScreenTimeService {
//   /// Initialize screen time service for current platform
//   static Future<void> initialize() async {
//     if (Platform.isAndroid) {
//       await ScreenTimeService.initialize();
//     } else if (Platform.isIOS) {
//       await IOSScreenTimeService.initialize();
//     }
//   }
//
//   /// Check if screen time permissions are granted
//   static Future<bool> hasPermissions() async {
//     if (Platform.isAndroid) {
//       return await ScreenTimeService.hasUsageStatsPermission();
//     } else if (Platform.isIOS) {
//       return await IOSScreenTimeService.hasScreenTimePermission();
//     }
//     return false;
//   }
//
//   /// Get current usage statistics
//   static Future<Map<String, dynamic>> getCurrentUsageStats() async {
//     if (Platform.isAndroid) {
//       return ScreenTimeService.getCurrentUsageStats();
//     } else if (Platform.isIOS) {
//       return await IOSScreenTimeService.getCurrentUsageStats();
//     }
//     return {};
//   }
//
//   /// Add earned screen time
//   static Future<void> addEarnedTime(double minutes) async {
//     if (Platform.isAndroid) {
//       await ScreenTimeService.addEarnedTime(minutes);
//     } else if (Platform.isIOS) {
//       await IOSScreenTimeService.addEarnedTime(minutes);
//     }
//   }
//
//   /// Set current child name
//   static Future<void> setCurrentChildName(String childName) async {
//     if (Platform.isAndroid) {
//       await ScreenTimeService.setCurrentChildName(childName);
//     } else if (Platform.isIOS) {
//       await IOSScreenTimeService.setCurrentChildName(childName);
//     }
//   }
//
//   /// Update screen time rules
//   static Future<void> updateScreenTimeRules() async {
//     if (Platform.isAndroid) {
//       await ScreenTimeService.updateScreenTimeRules();
//     } else if (Platform.isIOS) {
//       await IOSScreenTimeService.updateScreenTimeRules();
//     }
//   }
//
//   /// Stop monitoring (Android only)
//   static void stopMonitoring() {
//     if (Platform.isAndroid) {
//       ScreenTimeService.stopMonitoring();
//     }
//   }
//
//   /// Get platform-specific permission instruction
//   static String getPermissionInstructions() {
//     if (Platform.isAndroid) {
//       return 'Please go to Settings > Apps > Special Access > Usage Access and enable for FocusPass';
//     } else if (Platform.isIOS) {
//       return 'Please go to Settings > Screen Time > App Limits and grant permission for FocusPass';
//     }
//     return 'Platform not supported';
//   }
//
//   /// Get platform name
//   static String getPlatformName() {
//     if (Platform.isAndroid) {
//       return 'Android';
//     } else if (Platform.isIOS) {
//       return 'iOS';
//     }
//     return 'Unknown';
//   }
//
//   /// Debug function to check usage stats
//   static Future<void> debugUsageStats() async {
//     if (Platform.isAndroid) {
//       await ScreenTimeService.debugUsageStats();
//     } else if (Platform.isIOS) {
//       print('iOS debug not implemented yet');
//     }
//   }
//
//   /// Manually trigger daily reset (resets all screen time usage)
//   static Future<void> performDailyReset() async {
//     if (Platform.isAndroid) {
//       await ScreenTimeService.performDailyReset();
//     } else if (Platform.isIOS) {
//       // iOS reset functionality would go here when implemented
//       print('iOS daily reset not implemented yet');
//     }
//   }
//
//   /// Immediately reset screen time to 0 minutes
//   static Future<void> resetScreenTimeToZero() async {
//     if (Platform.isAndroid) {
//       await ScreenTimeService.resetScreenTimeToZero();
//     } else if (Platform.isIOS) {
//       // iOS reset functionality would go here when implemented
//       print('iOS screen time reset not implemented yet');
//     }
//   }
//
//   /// Force a complete reset of all screen time data (more aggressive than daily reset)
//   static Future<void> forceCompleteReset() async {
//     if (Platform.isAndroid) {
//       // First perform a complete reset to zero
//       await ScreenTimeService.resetScreenTimeToZero();
//
//       // Then perform a daily reset to ensure all systems are synced
//       await ScreenTimeService.performDailyReset();
//
//       print('UnifiedScreenTimeService: Complete force reset completed');
//     } else if (Platform.isIOS) {
//       print('iOS force reset not implemented yet');
//     }
//   }
//
//   /// Test method to diagnose monitoring issues
//   static Future<Map<String, dynamic>> diagnoseProblem() async {
//     Map<String, dynamic> diagnosis = {};
//
//     if (Platform.isAndroid) {
//       // Check permissions
//       final hasPermission = await ScreenTimeService.hasUsageStatsPermission();
//       diagnosis['hasPermission'] = hasPermission;
//
//       // Get current stats
//       final stats = ScreenTimeService.getCurrentUsageStats();
//       diagnosis['currentStats'] = stats;
//
//       // Run debug usage stats check
//       await ScreenTimeService.debugUsageStats();
//       diagnosis['debugRan'] = true;
//
//       print('UnifiedScreenTimeService: Diagnosis completed');
//       print('  Has Permission: $hasPermission');
//       print('  Stats Found: ${stats.length}');
//
//     } else if (Platform.isIOS) {
//       diagnosis['platform'] = 'iOS not implemented';
//     }
//
//     return diagnosis;
//   }
// }

import 'dart:io';
import 'screen_time_service.dart';
import 'ios_screen_time_service.dart';

class UnifiedScreenTimeService {
  /// Initialize screen time service for current platform
  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      await ScreenTimeService.initialize();
    } else if (Platform.isIOS) {
      await IOSScreenTimeService.initialize();
    }
  }

  /// Check if screen time permissions are granted
  static Future<bool> hasPermissions() async {
    if (Platform.isAndroid) {
      return await ScreenTimeService.hasUsageStatsPermission();
    } else if (Platform.isIOS) {
      return await IOSScreenTimeService.hasScreenTimePermission();
    }
    return false;
  }

  /// Get current usage statistics with validation
  static Future<Map<String, dynamic>> getCurrentUsageStats() async {
    if (Platform.isAndroid) {
      // Get stats and validate them
      final stats = ScreenTimeService.getCurrentUsageStats();

      // Validate that stats are reasonable
      final validatedStats = <String, dynamic>{};
      for (final entry in stats.entries) {
        final appName = entry.key;
        final data = entry.value;

        // Ensure all required fields exist
        final usedTime = data['usedTime'] ?? 0;
        final remainingTime = data['remainingTime'] ?? 0;
        final dailyLimit = data['dailyLimit'] ?? (1 * 60 * 60 * 1000);
        final earnedTime = data['earnedTime'] ?? 0;
        final isBlocked = data['isBlocked'] ?? false;

        // Validate time values are reasonable
        if (usedTime >= 0 && usedTime <= (24 * 60 * 60 * 1000)) { // Max 24 hours
          validatedStats[appName] = {
            'usedTime': usedTime,
            'remainingTime': remainingTime >= 0 ? remainingTime : 0,
            'dailyLimit': dailyLimit,
            'earnedTime': earnedTime,
            'isBlocked': isBlocked,
          };
        }
      }

      return validatedStats;
    } else if (Platform.isIOS) {
      return await IOSScreenTimeService.getCurrentUsageStats();
    }
    return {};
  }

  /// Add earned screen time
  static Future<void> addEarnedTime(double minutes) async {
    if (Platform.isAndroid) {
      await ScreenTimeService.addEarnedTime(minutes);
    } else if (Platform.isIOS) {
      await IOSScreenTimeService.addEarnedTime(minutes);
    }
  }

  /// Set current child name
  static Future<void> setCurrentChildName(String childName) async {
    if (Platform.isAndroid) {
      await ScreenTimeService.setCurrentChildName(childName);
    } else if (Platform.isIOS) {
      await IOSScreenTimeService.setCurrentChildName(childName);
    }
  }

  /// Update screen time rules
  static Future<void> updateScreenTimeRules() async {
    if (Platform.isAndroid) {
      await ScreenTimeService.updateScreenTimeRules();
    } else if (Platform.isIOS) {
      await IOSScreenTimeService.updateScreenTimeRules();
    }
  }

  /// Stop monitoring (Android only)
  static void stopMonitoring() {
    if (Platform.isAndroid) {
      ScreenTimeService.stopMonitoring();
    }
  }

  /// Get platform-specific permission instruction
  static String getPermissionInstructions() {
    if (Platform.isAndroid) {
      return 'Please go to Settings > Apps > Special Access > Usage Access and enable for FocusPass';
    } else if (Platform.isIOS) {
      return 'Please go to Settings > Screen Time > App Limits and grant permission for FocusPass';
    }
    return 'Platform not supported';
  }

  /// Get platform name
  static String getPlatformName() {
    if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    }
    return 'Unknown';
  }

  /// Debug function to check usage stats
  static Future<void> debugUsageStats() async {
    if (Platform.isAndroid) {
      await ScreenTimeService.debugUsageStats();
    } else if (Platform.isIOS) {
      print('iOS debug not implemented yet');
    }
  }

  /// Manually trigger daily reset (resets all screen time usage)
  static Future<void> performDailyReset() async {
    if (Platform.isAndroid) {
      await ScreenTimeService.performDailyReset();
    } else if (Platform.isIOS) {
      // iOS reset functionality would go here when implemented
      print('iOS daily reset not implemented yet');
    }
  }

  /// Immediately reset screen time to 0 minutes (keeps tracking from current point)
  static Future<void> resetScreenTimeToZero() async {
    if (Platform.isAndroid) {
      await ScreenTimeService.resetScreenTimeToZero();
    } else if (Platform.isIOS) {
      // iOS reset functionality would go here when implemented
      print('iOS screen time reset not implemented yet');
    }
  }

  /// Force a complete reset of all screen time data
  static Future<void> forceCompleteReset() async {
    if (Platform.isAndroid) {
      // First reset the tracking points
      await ScreenTimeService.resetScreenTimeToZero();

      // Small delay to ensure first operation completes
      await Future.delayed(const Duration(milliseconds: 100));

      // Then perform a daily reset to clear everything
      await ScreenTimeService.performDailyReset();

      print('UnifiedScreenTimeService: Complete force reset completed');
    } else if (Platform.isIOS) {
      print('iOS force reset not implemented yet');
    }
  }

  /// Test method to diagnose monitoring issues
  static Future<Map<String, dynamic>> diagnoseProblem() async {
    Map<String, dynamic> diagnosis = {};

    if (Platform.isAndroid) {
      // Check permissions
      final hasPermission = await ScreenTimeService.hasUsageStatsPermission();
      diagnosis['hasPermission'] = hasPermission;

      // Get current stats
      final stats = await getCurrentUsageStats();
      diagnosis['currentStats'] = stats;
      diagnosis['statsCount'] = stats.length;

      // Check if any apps have usage data
      bool hasAnyUsage = false;
      for (final appData in stats.values) {
        if ((appData['usedTime'] ?? 0) > 0) {
          hasAnyUsage = true;
          break;
        }
      }
      diagnosis['hasAnyUsage'] = hasAnyUsage;

      // Run debug usage stats check
      await ScreenTimeService.debugUsageStats();
      diagnosis['debugRan'] = true;

      print('UnifiedScreenTimeService: Diagnosis completed');
      print('  Has Permission: $hasPermission');
      print('  Stats Found: ${stats.length}');
      print('  Has Any Usage: $hasAnyUsage');

      // Provide diagnosis message
      if (!hasPermission) {
        diagnosis['message'] = 'Usage Access permission not granted. Please enable it in Settings.';
      } else if (stats.isEmpty) {
        diagnosis['message'] = 'No apps are being tracked. Check if restricted apps are configured.';
      } else if (!hasAnyUsage) {
        diagnosis['message'] = 'Tracking configured but no usage detected. Try using a restricted app.';
      } else {
        diagnosis['message'] = 'Screen time tracking appears to be working correctly.';
      }

    } else if (Platform.isIOS) {
      diagnosis['platform'] = 'iOS';
      diagnosis['message'] = 'iOS diagnostics not implemented';
    }

    return diagnosis;
  }

  /// Check if screen time tracking is working properly
  static Future<bool> isTrackingWorking() async {
    if (Platform.isAndroid) {
      // Check if we have permission
      if (!await hasPermissions()) {
        return false;
      }

      // Check if we're getting any stats
      final stats = await getCurrentUsageStats();
      return stats.isNotEmpty;
    } else if (Platform.isIOS) {
      return await IOSScreenTimeService.hasScreenTimePermission();
    }

    return false;
  }

  /// Get a summary of current tracking status
  static Future<String> getTrackingStatusSummary() async {
    final StringBuffer summary = StringBuffer();

    summary.writeln('Screen Time Tracking Status:');
    summary.writeln('Platform: ${getPlatformName()}');

    final hasPerms = await hasPermissions();
    summary.writeln('Permissions: ${hasPerms ? "✓ Granted" : "✗ Denied"}');

    if (hasPerms) {
      final stats = await getCurrentUsageStats();
      summary.writeln('Apps tracked: ${stats.length}');

      int totalUsageMs = 0;
      int blockedCount = 0;

      for (final appData in stats.values) {
        totalUsageMs += (appData['usedTime'] ?? 0) as int;
        if (appData['isBlocked'] == true) {
          blockedCount++;
        }
      }

      final totalMinutes = (totalUsageMs / (1000 * 60)).round();
      summary.writeln('Total usage today: ${totalMinutes}m');
      summary.writeln('Blocked apps: $blockedCount');
    } else {
      summary.writeln('\n${getPermissionInstructions()}');
    }

    return summary.toString();
  }
}