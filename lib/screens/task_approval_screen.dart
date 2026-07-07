import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/productive_task.dart';
import '../services/productive_task_service.dart';
import '../utils/constants.dart';
import '../widgets/approval_card.dart';

class TaskApprovalScreen extends StatefulWidget {
  const TaskApprovalScreen({super.key});

  @override
  State<TaskApprovalScreen> createState() => _TaskApprovalScreenState();
}

class _TaskApprovalScreenState extends State<TaskApprovalScreen> {
  final ProductiveTaskService _service = ProductiveTaskService();
  List<ProductiveTask> _allTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final tasks = await _service.getAllSubmissionsForParent(uid);
    setState(() {
      _allTasks = tasks;
      _isLoading = false;
    });
  }

  List<ProductiveTask> get _pending =>
      _allTasks.where((t) => t.status == 'pending').toList();

  List<ProductiveTask> get _history =>
      _allTasks.where((t) => t.status != 'pending').take(20).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: const Text('Task Submissions', style: TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  if (_pending.isEmpty)
                    _buildEmptyState()
                  else ...[
                    const _SectionLabel(text: 'PENDING REVIEW'),
                    const SizedBox(height: 10),
                    ..._pending.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: ApprovalCard(
                            task: t,
                            onApprove: (minutes) async {
                              await _service.approveTask(t.id, t.childName, minutes);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '✅ Approved +${_fmt(minutes)} for ${t.childName}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                              _loadTasks();
                            },
                            onReject: () async {
                              await _service.rejectTask(t.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Activity declined')),
                                );
                              }
                              _loadTasks();
                            },
                          ),
                        )),
                  ],
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionLabel(text: 'HISTORY'),
                    const SizedBox(height: 10),
                    ..._history.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _HistoryRow(task: t),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final pendingCount = _pending.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kDarkGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: pendingCount > 0 ? Colors.orange : Colors.greenAccent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: pendingCount > 0
                  ? Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : const Icon(Icons.check, color: Colors.greenAccent, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pendingCount > 0
                      ? '$pendingCount ${pendingCount == 1 ? 'activity' : 'activities'} waiting'
                      : 'All caught up!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pendingCount > 0
                      ? 'Review and approve to grant screen time'
                      : 'Nothing to review right now',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.white54, size: 56),
          SizedBox(height: 16),
          Text(
            'No pending submissions',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'When your child logs a completed task\nit will appear here for your review.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _fmt(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ProductiveTask task;

  const _HistoryRow({required this.task});

  String _fmt(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = task.status == 'approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(task.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  task.childName,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                isApproved ? Icons.check_circle : Icons.cancel,
                color: isApproved ? Colors.greenAccent : Colors.redAccent,
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                isApproved
                    ? '+${_fmt(task.awardedMinutes ?? task.proposedMinutes)}'
                    : 'Declined',
                style: TextStyle(
                  color: isApproved ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
