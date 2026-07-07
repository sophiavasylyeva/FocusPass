import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../models/productive_task.dart';
import '../services/productive_task_service.dart';
import '../widgets/approval_card.dart';
import 'manage_children_screen.dart';
import 'screen_time_rules.dart';
import 'pin_setup_screen.dart';
import 'weekly_reports_screen.dart';
import 'task_approval_screen.dart';
import 'daily_cap_setup_screen.dart';
import '../services/weekly_report_service.dart';
import 'login_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String parentName;

  const ParentDashboardScreen({super.key, required this.parentName});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ChildInboxData {
  final String name;
  final List<ProductiveTask> pending;
  final int earnedMinutesToday;
  final int capMinutes;

  _ChildInboxData({
    required this.name,
    required this.pending,
    required this.earnedMinutesToday,
    required this.capMinutes,
  });
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final ProductiveTaskService _taskService = ProductiveTaskService();

  bool _showNotification = true;
  bool _isLoading = true;
  List<_ChildInboxData> _childInboxes = [];

  @override
  void initState() {
    super.initState();
    _initializeWeeklyReports();
    _loadInboxData();
  }

  Future<void> _initializeWeeklyReports() async {
    try {
      await WeeklyReportService.scheduleWeeklyReportNotification();
    } catch (e) {
      print('Error initializing weekly reports: $e');
    }
  }

  Future<void> _loadInboxData() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final childrenSnap =
          await FirebaseFirestore.instance.collection('users').doc(uid).collection('children').get();
      final names = childrenSnap.docs.map((d) => d.data()['name'] as String).toList();

      final allTasks = await _taskService.getAllSubmissionsForParent(uid);
      final today = DateTime.now();

      final inboxes = <_ChildInboxData>[];
      for (final name in names) {
        final childTasks = allTasks.where((t) => t.childName == name).toList();
        final pending = childTasks.where((t) => t.status == 'pending').toList();
        final earnedToday = childTasks
            .where((t) =>
                t.status == 'approved' &&
                t.submittedAt.year == today.year &&
                t.submittedAt.month == today.month &&
                t.submittedAt.day == today.day)
            .fold(0, (sum, t) => sum + (t.awardedMinutes ?? 0));
        final capHours = await _taskService.getDailyCapHours(uid, name);

        inboxes.add(_ChildInboxData(
          name: name,
          pending: pending,
          earnedMinutesToday: earnedToday,
          capMinutes: (capHours * 60).round(),
        ));
      }

      if (mounted) {
        setState(() {
          _childInboxes = inboxes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading parent inbox: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  void _goTo(Widget screen, {bool refreshOnReturn = false}) {
    final navigate = Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    if (refreshOnReturn) navigate.then((_) => _loadInboxData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          tooltip: 'Back to Login',
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
        title: const Text('Parent Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showNotification)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kMintGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        "IMPORTANT: Once you've added your children's profiles and set the screen time rules, join your child on their device to log in with the username and password you set up. They'll select which apps to limit and start logging productive tasks — you'll approve them here to grant screen time. FocusPass does the rest!",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          height: 1.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showNotification = false),
                      child: const Icon(Icons.close, color: Colors.black, size: 20),
                    ),
                  ],
                ),
              ),
            if (_showNotification) const SizedBox(height: 16),
            Text(
              'Good afternoon, ${widget.parentName}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              'Review activities and manage screen time.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _childInboxes.isEmpty
                      ? _buildEmptyChildrenState()
                      : RefreshIndicator(
                          onRefresh: _loadInboxData,
                          child: ListView.separated(
                            itemCount: _childInboxes.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 28),
                            itemBuilder: (context, index) => _buildChildBlock(_childInboxes[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(color: kDarkGreen),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _NavAction(
                icon: Icons.person,
                label: 'Children',
                onTap: () => _goTo(const ManageChildrenScreen(), refreshOnReturn: true),
              ),
              _NavAction(
                icon: Icons.timer,
                label: 'Rules',
                onTap: () => _goTo(const ScreenTimeRulesScreen(), refreshOnReturn: true),
              ),
              _NavAction(
                icon: Icons.bar_chart,
                label: 'Reports',
                onTap: () => _goTo(const WeeklyReportsScreen()),
              ),
              _NavAction(
                icon: Icons.security,
                label: 'PIN',
                onTap: () => _goTo(const PinSetupScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChildrenState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.family_restroom, color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          const Text(
            'No children added yet',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManageChildrenScreen()),
              ).then((_) => _loadInboxData());
            },
            child: const Text('Add a child', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildChildBlock(_ChildInboxData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_childInboxes.length > 1) ...[
          Text(
            data.name,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
        ],
        if (data.capMinutes > 0 && data.earnedMinutesToday >= data.capMinutes) ...[
          _buildCapReachedBanner(data.name),
          const SizedBox(height: 12),
        ],
        _buildScreenTimeCard(data),
        const SizedBox(height: 16),
        _buildToReviewSection(data),
      ],
    );
  }

  Widget _buildCapReachedBanner(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$name has run out of screen time for today.',
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTimeCard(_ChildInboxData data) {
    final progress =
        data.capMinutes > 0 ? (data.earnedMinutesToday / data.capMinutes).clamp(0.0, 1.0) : 0.0;
    final remaining = (data.capMinutes - data.earnedMinutesToday).clamp(0, data.capMinutes);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "${data.name.toUpperCase()}'S SCREEN TIME TODAY",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Colors.grey,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  final result = await Navigator.push<double>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DailyCapSetupScreen(
                        childName: data.name,
                        currentHours: data.capMinutes / 60.0,
                      ),
                    ),
                  );
                  if (result != null) _loadInboxData();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: kDarkGreen,
                  side: const BorderSide(color: kAccentGreen),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Change limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmt(data.earnedMinutesToday),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(width: 6),
              Text('/ ${_fmt(data.capMinutes)}', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(kAccentGreen),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_fmt(remaining)} remaining to award today.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildToReviewSection(_ChildInboxData data) {
    final count = data.pending.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kMintGreen.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TO REVIEW',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: kDarkGreen),
              ),
              const SizedBox(height: 6),
              Text(
                count > 0 ? '$count ${count == 1 ? 'activity' : 'activities'} waiting' : 'All caught up!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                count > 0
                    ? 'Adjust the minutes if needed, then approve to grant screen time.'
                    : 'Nothing to review right now.',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ],
          ),
        ),
        if (count > 0) ...[
          const SizedBox(height: 12),
          ...data.pending.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ApprovalCard(
                  task: t,
                  capMinutes: data.capMinutes,
                  onApprove: (minutes) async {
                    await _taskService.approveTask(t.id, t.childName, minutes);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Approved +${_fmt(minutes)} for ${t.childName}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    _loadInboxData();
                  },
                  onReject: () async {
                    await _taskService.rejectTask(t.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Activity declined')),
                      );
                    }
                    _loadInboxData();
                  },
                ),
              )),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _goTo(const TaskApprovalScreen(), refreshOnReturn: true),
            child: const Text('View full history', style: TextStyle(color: Colors.white70)),
          ),
        ),
      ],
    );
  }
}

class _NavAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
