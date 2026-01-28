import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataLoggingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Log daily screen time usage data
  static Future<void> logDailyScreenTimeUsage({
    required String childName,
    required Map<String, dynamic> appUsageData,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Save to parent's data structure
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(childName)
          .collection('screenTimeUsage')
          .doc(dateKey)
          .set({
        'date': Timestamp.fromDate(today),
        'appUsage': appUsageData,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('DataLoggingService: Logged screen time usage for $childName on $dateKey');

    } catch (e) {
      print('DataLoggingService: Error logging screen time usage: $e');
    }
  }

  /// Log educational activity when a task is completed
  static Future<void> logEducationalActivity({
    required String childName,
    required String subject,
    required String question,
    required bool isCorrect,
    String? userAnswer,
    String? correctAnswer,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Save educational activity log
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(childName)
          .collection('educationalActivity')
          .add({
        'subject': subject,
        'question': question,
        'isCorrect': isCorrect,
        'userAnswer': userAnswer,
        'correctAnswer': correctAnswer,
        'completedAt': FieldValue.serverTimestamp(),
      });

      print('DataLoggingService: Logged educational activity for $childName - Subject: $subject, Correct: $isCorrect');

    } catch (e) {
      print('DataLoggingService: Error logging educational activity: $e');
    }
  }

  /// Update screen time usage for a specific app
  static Future<void> updateAppUsage({
    required String childName,
    required String appName,
    required int usageTimeMs,
    required int remainingTimeMs,
    required int dailyLimitMs,
    required int earnedTimeMs,
    required bool isBlocked,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Prepare app usage data
      final appUsageData = {
        appName: {
          'usedTime': usageTimeMs,
          'remainingTime': remainingTimeMs,
          'dailyLimit': dailyLimitMs,
          'earnedTime': earnedTimeMs,
          'isBlocked': isBlocked,
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      };

      // Update the app usage in today's document
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(childName)
          .collection('screenTimeUsage')
          .doc(dateKey)
          .set({
        'date': Timestamp.fromDate(today),
        'appUsage': appUsageData,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      print('DataLoggingService: Error updating app usage: $e');
    }
  }

  /// Get current child name from SharedPreferences
  static Future<String?> getCurrentChildName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('current_child_name');
    } catch (e) {
      print('DataLoggingService: Error getting current child name: $e');
      return null;
    }
  }

  /// Helper method to get parent UID for a child
  static Future<String?> getParentUidForChild(String childName) async {
    try {
      final query = await _firestore
          .collectionGroup('children')
          .where('name', isEqualTo: childName)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final childDoc = query.docs.first;
        return childDoc.reference.parent.parent?.id;
      }
      return null;
    } catch (e) {
      print('DataLoggingService: Error getting parent UID: $e');
      return null;
    }
  }

  /// Log screen time session (when child starts using an app)
  static Future<void> logScreenTimeSession({
    required String childName,
    required String appName,
    required DateTime sessionStart,
    DateTime? sessionEnd,
  }) async {
    try {
      final parentUid = await getParentUidForChild(childName);
      if (parentUid == null) return;

      await _firestore
          .collection('users')
          .doc(parentUid)
          .collection('children')
          .doc(childName)
          .collection('screenTimeSessions')
          .add({
        'appName': appName,
        'sessionStart': Timestamp.fromDate(sessionStart),
        'sessionEnd': sessionEnd != null ? Timestamp.fromDate(sessionEnd) : null,
        'durationMs': sessionEnd != null 
            ? sessionEnd.difference(sessionStart).inMilliseconds 
            : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print('DataLoggingService: Error logging screen time session: $e');
    }
  }

}