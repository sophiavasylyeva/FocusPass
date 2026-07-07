import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/productive_task.dart';
import 'unified_screen_time_service.dart';

class ProductiveTaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'productive_tasks';

  Future<void> submitTask(ProductiveTask task) async {
    try {
      await _firestore.collection(_collection).doc(task.id).set(task.toMap());
    } catch (e) {
      print('❌ Error submitting productive task: $e');
      rethrow;
    }
  }

  Future<List<ProductiveTask>> getSubmissionsForChild(String childName) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('childName', isEqualTo: childName)
          .get();
      final tasks = snapshot.docs
          .map((doc) => ProductiveTask.fromMap(doc.id, doc.data()))
          .toList();
      tasks.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return tasks;
    } catch (e) {
      print('❌ Error fetching submissions for child: $e');
      return [];
    }
  }

  Future<List<ProductiveTask>> getAllSubmissionsForParent(String parentUid) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('parentUid', isEqualTo: parentUid)
          .get();
      final tasks = snapshot.docs
          .map((doc) => ProductiveTask.fromMap(doc.id, doc.data()))
          .toList();
      tasks.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return tasks;
    } catch (e) {
      print('❌ Error fetching submissions for parent: $e');
      return [];
    }
  }

  Future<void> approveTask(String taskId, String childName, int awardedMinutes) async {
    try {
      await _firestore.collection(_collection).doc(taskId).update({
        'status': 'approved',
        'awardedMinutes': awardedMinutes,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      await UnifiedScreenTimeService.setCurrentChildName(childName);
      await UnifiedScreenTimeService.addEarnedTime(awardedMinutes.toDouble());
    } catch (e) {
      print('❌ Error approving task: $e');
      rethrow;
    }
  }

  Future<void> rejectTask(String taskId) async {
    try {
      await _firestore.collection(_collection).doc(taskId).update({
        'status': 'rejected',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error rejecting task: $e');
      rethrow;
    }
  }

  static String generateTaskId(String childName) {
    return '${childName}_task_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<int> getApprovedMinutesToday(String childName) async {
    final all = await getSubmissionsForChild(childName);
    final today = DateTime.now();
    return all
        .where((t) =>
            t.status == 'approved' &&
            t.resolvedAt != null &&
            t.resolvedAt!.year == today.year &&
            t.resolvedAt!.month == today.month &&
            t.resolvedAt!.day == today.day)
        .fold<int>(0, (sum, t) => sum + (t.awardedMinutes ?? 0));
  }

  Future<double> getDailyCapHours(String parentUid, String childName) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(parentUid)
          .collection('settings')
          .doc('screenTimeRules')
          .get();

      if (!doc.exists) return 2.0;
      final data = doc.data()!;
      if ((data['applySameForAll'] ?? false) == true) {
        return (data['unifiedRules']?['limit'] ?? 2.0).toDouble();
      }
      final childrenData = data['children'] as Map<String, dynamic>? ?? {};
      return (childrenData[childName]?['limit'] ?? 2.0).toDouble();
    } catch (e) {
      print('❌ Error fetching daily cap: $e');
      return 2.0;
    }
  }

  Future<void> setChildDailyCapHours(
      String parentUid, String childName, double hours) async {
    final ref = _firestore
        .collection('users')
        .doc(parentUid)
        .collection('settings')
        .doc('screenTimeRules');

    final doc = await ref.get();
    final childrenData = doc.exists
        ? Map<String, dynamic>.from(doc.data()?['children'] ?? {})
        : <String, dynamic>{};
    childrenData[childName] = {'limit': hours};

    await ref.set({
      'applySameForAll': false,
      'children': childrenData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
