// Debug script to test screen time calculations
// This can be run to verify what data is being returned

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  await testScreenTimeDebug('TestChild');
}

Future<void> testScreenTimeDebug(String childName) async {
  try {
    print('=== DEBUG: Testing Screen Time Data ===');
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('ERROR: No user logged in');
      return;
    }

    final childDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('children')
        .doc(childName)
        .get();
    
    if (!childDoc.exists) {
      print('ERROR: Child document does not exist for $childName');
      return;
    }

    final childData = childDoc.data()!;
    final Map<String, dynamic> appLimits = childData['appLimits'] ?? {};
    
    print('Firestore App Limits:');
    appLimits.forEach((appName, limitData) {
      if (limitData is Map<String, dynamic>) {
        final limitMinutes = limitData['dailyLimitMinutes'] ?? 0;
        print('  $appName: ${limitMinutes}m daily limit');
      }
    });
    
    // Also check what UnifiedScreenTimeService returns
    // Note: This would need proper imports in a real test
    print('\nThis script would need to be integrated into the Flutter app to test UnifiedScreenTimeService');
    
  } catch (e) {
    print('ERROR: $e');
  }
}