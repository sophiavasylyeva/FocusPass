import 'package:flutter/services.dart';

class FamilyActivityPickerResult {
  final int appCount;
  final int categoryCount;

  const FamilyActivityPickerResult({
    required this.appCount,
    required this.categoryCount,
  });

  bool get isEmpty => appCount == 0 && categoryCount == 0;
}

/// Bridges to Apple's real FamilyActivityPicker (iOS 16+), which lists every
/// app/category installed on the device exactly like Settings > Screen Time.
/// Apple never reveals the picked app names back to third-party code, so the
/// result only carries counts — not a named list.
class FamilyActivityPickerService {
  static const MethodChannel _channel = MethodChannel(
    'com.focuspass.screentime',
  );

  /// Presents the native picker. Returns null if the user cancelled.
  static Future<FamilyActivityPickerResult?> show() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'showActivityPicker',
    );
    if (result == null) return null;
    return FamilyActivityPickerResult(
      appCount: (result['appCount'] as num?)?.toInt() ?? 0,
      categoryCount: (result['categoryCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Applies real Screen Time shielding using the previously picked selection.
  static Future<void> applyRestrictions({
    required int dailyLimitMinutes,
    required int earnedTimeMinutes,
  }) async {
    await _channel.invokeMethod('applyFamilyActivitySelectionRestrictions', {
      'dailyLimitMinutes': dailyLimitMinutes,
      'earnedTimeMinutes': earnedTimeMinutes,
    });
  }
}
