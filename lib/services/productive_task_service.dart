import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/productive_task.dart';
import '../utils/screen_time_rules_lookup.dart';
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

  /// Fetches submissions owned by this child. Ownership is determined ONLY
  /// by [parentUid] + [childId] — never by display name. Documents written
  /// before this migration may not carry [childId] yet and simply won't
  /// match this query (see ProductiveTask.fromMap).
  Future<List<ProductiveTask>> getSubmissionsForChild({
    required String parentUid,
    required String childId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('parentUid', isEqualTo: parentUid)
          .where('childId', isEqualTo: childId)
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

  Future<List<ProductiveTask>> getAllSubmissionsForParent(
    String parentUid,
  ) async {
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

  Future<void> approveTask(
    String taskId,
    String childName,
    int awardedMinutes,
  ) async {
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

  static String generateTaskId(String childId) {
    return '${childId}_task_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<int> getApprovedMinutesToday({
    required String parentUid,
    required String childId,
  }) async {
    final all = await getSubmissionsForChild(
      parentUid: parentUid,
      childId: childId,
    );
    final today = DateTime.now();
    return all
        .where(
          (t) =>
              t.status == 'approved' &&
              t.resolvedAt != null &&
              t.resolvedAt!.year == today.year &&
              t.resolvedAt!.month == today.month &&
              t.resolvedAt!.day == today.day,
        )
        .fold<int>(0, (sum, t) => sum + (t.awardedMinutes ?? 0));
  }

  /// Reads a child's daily cap. Prefers `children[childId]`, falling back
  /// to the legacy `children[childName]` entry, and only then to the
  /// existing 2.0h default — see [resolveChildRuleEntry].
  Future<double> getDailyCapHours({
    required String parentUid,
    required String childId,
    required String childName,
  }) async {
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
      final entry = resolveChildRuleEntry(
        childrenData: childrenData,
        parentUid: parentUid,
        childId: childId,
        displayName: childName,
      );
      return (entry?['limit'] ?? 2.0).toDouble();
    } catch (e) {
      print('❌ Error fetching daily cap: $e');
      return 2.0;
    }
  }

  /// Sets a child's daily cap. Preserves every other field on the document
  /// (`applySameForAll` is explicitly re-asserted as false since setting an
  /// individual cap implies per-child mode, but `unifiedRules` and every
  /// other child's entry in `children` are read back and re-written
  /// unchanged via [SetOptions.merge]).
  ///
  /// TEMPORARY dual-write: writes both `children[childId]` and
  /// `children[childName]` with identical settings, so readers that
  /// haven't migrated yet (or documents predating this migration) keep
  /// working. Remove the childName-keyed write once a backfill confirms
  /// every reader and every existing document has a childId-keyed entry.
  Future<void> setChildDailyCapHours({
    required String parentUid,
    required String childId,
    required String childName,
    required double hours,
  }) async {
    final ref = _firestore
        .collection('users')
        .doc(parentUid)
        .collection('settings')
        .doc('screenTimeRules');

    final doc = await ref.get();
    final childrenData = doc.exists
        ? Map<String, dynamic>.from(doc.data()?['children'] ?? {})
        : <String, dynamic>{};

    final settings = {'displayName': childName, 'limit': hours};
    childrenData[childId] = settings;
    childrenData[childName] = settings;

    await ref.set({
      'applySameForAll': false,
      'children': childrenData,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
