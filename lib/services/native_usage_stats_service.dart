import 'dart:io';
import 'package:flutter/services.dart';

class UsageStatInfo {
  final String packageName;
  final int totalTimeInForeground;
  final int firstTimeStamp;
  final int lastTimeStamp;
  final int lastTimeUsed;

  UsageStatInfo({
    required this.packageName,
    required this.totalTimeInForeground,
    required this.firstTimeStamp,
    required this.lastTimeStamp,
    required this.lastTimeUsed,
  });

  factory UsageStatInfo.fromMap(Map<dynamic, dynamic> map) {
    return UsageStatInfo(
      packageName: map['packageName'] as String? ?? '',
      totalTimeInForeground: (map['totalTimeInForeground'] as num?)?.toInt() ?? 0,
      firstTimeStamp: (map['firstTimeStamp'] as num?)?.toInt() ?? 0,
      lastTimeStamp: (map['lastTimeStamp'] as num?)?.toInt() ?? 0,
      lastTimeUsed: (map['lastTimeUsed'] as num?)?.toInt() ?? 0,
    );
  }
}

class NativeUsageStatsService {
  static const MethodChannel _channel = MethodChannel('com.focuspass.usage_stats');

  static Future<List<UsageStatInfo>> queryUsageStats(DateTime startTime, DateTime endTime) async {
    if (!Platform.isAndroid) {
      return [];
    }

    try {
      final result = await _channel.invokeMethod('queryUsageStats', {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
      });

      if (result == null) return [];

      final List<dynamic> statsList = result as List<dynamic>;
      return statsList
          .map((stat) => UsageStatInfo.fromMap(stat as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      print('NativeUsageStatsService: Error querying usage stats: $e');
      return [];
    }
  }

  static Future<bool> hasUsageStatsPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod('hasUsageStatsPermission');
      return result as bool? ?? false;
    } catch (e) {
      print('NativeUsageStatsService: Error checking permission: $e');
      return false;
    }
  }

  static Future<void> openUsageStatsSettings() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod('openUsageStatsSettings');
    } catch (e) {
      print('NativeUsageStatsService: Error opening settings: $e');
    }
  }
}
