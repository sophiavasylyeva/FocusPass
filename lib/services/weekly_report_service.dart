import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class WeeklyReportService {
  static const String _lastReportDateKey = 'last_weekly_report_date';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final NotificationService _notificationService = NotificationService();
  
  /// Generate weekly report for a specific child
  static Future<Map<String, dynamic>> generateWeeklyReport(String childName, String parentUid) async {
    final DateTime now = DateTime.now();
    final DateTime weekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday
    final DateTime weekEnd = weekStart.add(const Duration(days: 6)); // Sunday
    
    // Initialize report structure
    Map<String, dynamic> report = {
      'childName': childName,
      'weekStart': weekStart.toIso8601String(),
      'weekEnd': weekEnd.toIso8601String(),
      'generatedAt': now.toIso8601String(),
      'averageScreenTime': 0.0,
      'totalScreenTime': 0.0,
      'appUsage': <Map<String, dynamic>>[],
      'learningTopics': <Map<String, dynamic>>[],
      'daysActive': 0,
    };

    try {
      // Get child's screen time data for the week
      final screenTimeData = await _getWeeklyScreenTimeData(childName, parentUid, weekStart, weekEnd);
      report['averageScreenTime'] = screenTimeData['averageScreenTime'];
      report['totalScreenTime'] = screenTimeData['totalScreenTime'];
      report['appUsage'] = screenTimeData['appUsage'];
      report['daysActive'] = screenTimeData['daysActive'];

      // Get child's learning data for the week
      final learningData = await _getWeeklyLearningData(childName, parentUid, weekStart, weekEnd);
      report['learningTopics'] = learningData;

      // Save report to Firebase
      await _saveReportToFirebase(parentUid, childName, report);

    } catch (e) {
      print('Error generating weekly report: $e');
    }

    return report;
  }

  /// Get screen time data for the week
  static Future<Map<String, dynamic>> _getWeeklyScreenTimeData(
    String childName, 
    String parentUid, 
    DateTime weekStart, 
    DateTime weekEnd
  ) async {
    Map<String, int> appUsageMap = {};
    double totalScreenTime = 0.0;
    int daysActive = 0;
    
    try {
      // Query screen time usage logs for the week
      final query = await _firestore
          .collection('users')
          .doc(parentUid)
          .collection('children')
          .doc(childName)
          .collection('screenTimeUsage')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();

      Set<String> activeDays = {};

      for (final doc in query.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final dayKey = '${date.year}-${date.month}-${date.day}';
        activeDays.add(dayKey);

        // Sum up app usage
        final appUsage = data['appUsage'] as Map<String, dynamic>? ?? {};
        for (final entry in appUsage.entries) {
          final appName = entry.key;
          final usageMs = (entry.value['usedTime'] ?? 0) as int;
          appUsageMap[appName] = (appUsageMap[appName] ?? 0) + usageMs;
          totalScreenTime += usageMs.toDouble();
        }
      }

      daysActive = activeDays.length;

      // Convert app usage to sorted list
      final appUsageList = appUsageMap.entries
          .map((entry) => {
                'appName': entry.key,
                'totalUsageMs': entry.value,
                'totalUsageMinutes': (entry.value / (1000 * 60)).round(),
                'averageUsageMinutes': daysActive > 0 
                    ? ((entry.value / (1000 * 60)) / daysActive).round() 
                    : 0,
              })
          .toList();

      // Sort by total usage (descending)
      appUsageList.sort((a, b) => 
          (b['totalUsageMs'] as int).compareTo(a['totalUsageMs'] as int));

      final averageScreenTime = daysActive > 0 
          ? totalScreenTime / (daysActive * 1000 * 60) // Convert to minutes
          : 0.0;

      return {
        'averageScreenTime': averageScreenTime,
        'totalScreenTime': totalScreenTime / (1000 * 60), // Convert to minutes
        'appUsage': appUsageList,
        'daysActive': daysActive,
      };

    } catch (e) {
      print('Error getting weekly screen time data: $e');
      return {
        'averageScreenTime': 0.0,
        'totalScreenTime': 0.0,
        'appUsage': <Map<String, dynamic>>[],
        'daysActive': 0,
      };
    }
  }

  /// Get learning data for the week
  static Future<List<Map<String, dynamic>>> _getWeeklyLearningData(
    String childName, 
    String parentUid, 
    DateTime weekStart, 
    DateTime weekEnd
  ) async {
    Map<String, Map<String, dynamic>> topicsMap = {};

    try {
      // Query educational activity logs for the week
      final query = await _firestore
          .collection('users')
          .doc(parentUid)
          .collection('children')
          .doc(childName)
          .collection('educationalActivity')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();

      for (final doc in query.docs) {
        final data = doc.data();
        final subject = data['subject'] as String? ?? 'General';
        final question = data['question'] as String? ?? '';
        final isCorrect = data['isCorrect'] as bool? ?? false;

        if (!topicsMap.containsKey(subject)) {
          topicsMap[subject] = {
            'subject': subject,
            'questionsAnswered': 0,
            'questionsCorrect': 0,
            'accuracy': 0.0,
            'sampleQuestions': <String>[],
          };
        }

        topicsMap[subject]!['questionsAnswered'] = 
            (topicsMap[subject]!['questionsAnswered'] as int) + 1;
            
        if (isCorrect) {
          topicsMap[subject]!['questionsCorrect'] = 
              (topicsMap[subject]!['questionsCorrect'] as int) + 1;
        }

        // Add sample questions (max 3 per subject)
        final sampleQuestions = topicsMap[subject]!['sampleQuestions'] as List<String>;
        if (sampleQuestions.length < 3 && question.isNotEmpty) {
          sampleQuestions.add(question);
        }
      }

      // Calculate accuracy for each subject
      for (final topic in topicsMap.values) {
        final total = topic['questionsAnswered'] as int;
        final correct = topic['questionsCorrect'] as int;
        topic['accuracy'] = total > 0 ? (correct / total * 100) : 0.0;
      }

      // Convert to list and sort by questions answered
      final topicsList = topicsMap.values.toList();
      topicsList.sort((a, b) => 
          (b['questionsAnswered'] as int).compareTo(a['questionsAnswered'] as int));

      return topicsList;

    } catch (e) {
      print('Error getting weekly learning data: $e');
      return [];
    }
  }

  /// Save report to Firebase
  static Future<void> _saveReportToFirebase(
    String parentUid, 
    String childName, 
    Map<String, dynamic> report
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(parentUid)
          .collection('weeklyReports')
          .add({
        ...report,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving report to Firebase: $e');
    }
  }

  /// Schedule Friday 9pm notification
  static Future<void> scheduleWeeklyReportNotification() async {
    try {
      await _notificationService.initialize();
      
      // Schedule for every Friday at 9 PM
      final now = DateTime.now();
      final nextFriday = _getNextFriday(now);
      final notificationTime = DateTime(
        nextFriday.year,
        nextFriday.month,
        nextFriday.day,
        21, // 9 PM
        0,  // 0 minutes
      );

      await _notificationService.scheduleWeeklyNotification(
        id: 1000, // Unique ID for weekly reports
        title: '📊 Weekly Report Ready',
        body: 'Your child\'s weekly screen time and learning report is ready to view!',
        scheduledTime: notificationTime,
      );

      print('Weekly report notification scheduled for: $notificationTime');

    } catch (e) {
      print('Error scheduling weekly notification: $e');
    }
  }

  /// Get next Friday from given date
  static DateTime _getNextFriday(DateTime date) {
    final daysUntilFriday = (DateTime.friday - date.weekday) % 7;
    return date.add(Duration(days: daysUntilFriday == 0 ? 7 : daysUntilFriday));
  }

  /// Generate reports for all children and send notification
  static Future<void> generateAllChildrenReports() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final parentUid = user.uid;
      
      // Get all children for this parent
      final childrenQuery = await _firestore
          .collection('users')
          .doc(parentUid)
          .collection('children')
          .get();

      int reportsGenerated = 0;
      
      for (final childDoc in childrenQuery.docs) {
        final childName = childDoc.data()['name'] as String;
        await generateWeeklyReport(childName, parentUid);
        reportsGenerated++;
      }

      // Send immediate notification that reports are ready
      if (reportsGenerated > 0) {
        await _notificationService.showNotification(
          id: 1001,
          title: '📊 Weekly Reports Ready',
          body: 'Weekly reports for $reportsGenerated ${reportsGenerated == 1 ? "child" : "children"} are now available!',
        );
      }

      // Update last report date
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastReportDateKey, DateTime.now().toIso8601String());

      // Schedule next week's notification
      await scheduleWeeklyReportNotification();

    } catch (e) {
      print('Error generating all children reports: $e');
    }
  }

  /// Check if it's time to generate reports (for manual testing)
  static Future<bool> shouldGenerateReports() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReportDateStr = prefs.getString(_lastReportDateKey);
    
    if (lastReportDateStr == null) return true;
    
    final lastReportDate = DateTime.parse(lastReportDateStr);
    final now = DateTime.now();
    
    // Generate if it's been more than 6 days since last report
    return now.difference(lastReportDate).inDays >= 6;
  }

  /// Get all reports for a specific child
  static Future<List<Map<String, dynamic>>> getChildReports(String childName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final query = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('weeklyReports')
          .where('childName', isEqualTo: childName)
          .orderBy('createdAt', descending: true)
          .limit(10) // Last 10 reports
          .get();

      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

    } catch (e) {
      print('Error getting child reports: $e');
      return [];
    }
  }
}