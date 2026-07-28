import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../utils/screen_time_rules_lookup.dart';
import '../models/child_session.dart';
import '../services/authentication_lifecycle_service.dart';
import '../services/child_session_service.dart';
import '../services/unified_screen_time_service.dart';
import '../services/productive_task_service.dart';
import '../models/productive_task.dart';
import 'login_screen.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childName;

  const ChildDashboardScreen({super.key, required this.childName});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> {
  List<String> _selectedApps = [];
  bool _isLoading = true;
  Map<String, dynamic> _screenTimeStats = {};
  bool _hasUsagePermission = false;

  final ProductiveTaskService _taskService = ProductiveTaskService();
  List<ProductiveTask> _todaySubmissions = [];
  bool _tasksLoading = false;
  String _tierFilter = 'ALL';
  int _capMinutes = 120;

  bool _usesFamilyActivityPicker = false;
  int _familyActivityAppCount = 0;
  int _familyActivityCategoryCount = 0;

  bool _isLoggingOut = false;

  static const List<String> _tiers = ['XS', 'S', 'M', 'L', 'XL'];

  static const Map<String, IconData> _appIcons = {
    'Instagram': Icons.camera_alt,
    'TikTok': Icons.music_note,
    'YouTube': Icons.play_circle_fill,
    'YouTube Shorts': Icons.video_library,
    'Snapchat': Icons.chat_bubble,
    'X (Twitter)': Icons.tag,
  };

  static const Map<String, Color> _appColors = {
    'Instagram': Color(0xFFE1306C),
    'TikTok': Color(0xFF333333),
    'YouTube': Color(0xFFFF0000),
    'YouTube Shorts': Color(0xFFFF0000),
    'Snapchat': Color(0xFFFFFC00),
    'X (Twitter)': Color(0xFF000000),
  };

  Widget _buildAppIcon(String appName, {bool blocked = false}) {
    if (blocked) return const Icon(Icons.block, color: Colors.red);
    final icon = _appIcons[appName] ?? Icons.phone_android;
    final color = _appColors[appName] ?? kAccentGreen;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: appName == 'Snapchat' ? Colors.black : Colors.white,
        size: 20,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchChildData();
    _initializeScreenTime();
    _loadTodaySubmissions();
    _loadDailyCap();
  }

  ChildSession get _session => ChildSessionService.requireSession();


  Future<void> _handleLogout() async {
    if (_isLoggingOut) return; // guard against double-tap
    _isLoggingOut = true;
    try {
      await AuthenticationLifecycleService().logout();
    } finally {
      _isLoggingOut = false;
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _fetchChildData() async {
    try {
      final childDoc = await _session.childRef().get();

      if (childDoc.exists) {
        final data = childDoc.data()!;
        setState(() {
          _selectedApps = List<String>.from(data['selectedApps'] ?? []);
          _usesFamilyActivityPicker = data['usesFamilyActivityPicker'] ?? false;
          _familyActivityAppCount =
              (data['familyActivityAppCount'] as num?)?.toInt() ?? 0;
          _familyActivityCategoryCount =
              (data['familyActivityCategoryCount'] as num?)?.toInt() ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        print('❌ Child not found at ${_session.childRef().path}');
      }
    } catch (e) {
      print('❌ Error fetching child data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeScreenTime() async {
    await UnifiedScreenTimeService.setCurrentChildName(widget.childName);
    await UnifiedScreenTimeService.initialize();

    final hasPermission = await UnifiedScreenTimeService.hasPermissions();
    setState(() => _hasUsagePermission = hasPermission);

    final stats = await _getScreenTimeStatsWithFirestoreLimits();
    setState(() => _screenTimeStats = stats);

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (mounted) {
        final updatedStats = await _getScreenTimeStatsWithFirestoreLimits();
        setState(() => _screenTimeStats = updatedStats);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadTodaySubmissions() async {
    setState(() => _tasksLoading = true);
    try {
      final all = await _taskService.getSubmissionsForChild(
        parentUid: _session.parentUid,
        childId: _session.childId,
      );
      final today = DateTime.now();
      final todayTasks = all.where((t) {
        return t.submittedAt.year == today.year &&
            t.submittedAt.month == today.month &&
            t.submittedAt.day == today.day;
      }).toList();
      setState(() {
        _todaySubmissions = todayTasks;
        _tasksLoading = false;
      });
    } catch (e) {
      print('❌ Error loading today submissions: $e');
      setState(() => _tasksLoading = false);
    }
  }

  Future<void> _loadDailyCap() async {
    try {
      final hours = await _taskService.getDailyCapHours(
        parentUid: _session.parentUid,
        childId: _session.childId,
        childName: _session.displayName,
      );
      if (mounted) setState(() => _capMinutes = (hours * 60).round());
    } catch (e) {
      print('❌ Error loading daily cap: $e');
    }
  }

  int get _earnedMinutesToday => _todaySubmissions
      .where((t) => t.status == 'approved')
      .fold(0, (sum, t) => sum + (t.awardedMinutes ?? 0));

  int get _pendingCount =>
      _todaySubmissions.where((t) => t.status == 'pending').length;

  List<ProductiveTaskPreset> get _filteredPresets {
    if (_tierFilter == 'ALL') return kProductivePresets;
    return kProductivePresets.where((p) => p.tier == _tierFilter).toList();
  }

  bool get _capReached => _capMinutes > 0 && _earnedMinutesToday >= _capMinutes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          tooltip: 'Back to Login',
          onPressed: _handleLogout,
        ),
        title: const Text(
          'Child Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => _showParentalPinOverrideDialog(),
            tooltip: 'Parental Override',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                children: [
                  Text(
                    'Welcome, ${widget.childName}!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Ready to earn some screen time?',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  _buildEarnedTodayCard(),
                  const SizedBox(height: 20),

                  _buildTierFilter(),
                  const SizedBox(height: 16),
                  _buildPresetList(),
                  const SizedBox(height: 12),
                  _buildCustomButton(),

                  if (!_tasksLoading && _todaySubmissions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSubmissionsSection(),
                  ],

                  const SizedBox(height: 28),
                  const Text(
                    'Screen Time Management:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildScreenTimeWidget(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildEarnedTodayCard() {
    final progress = _capMinutes > 0
        ? (_earnedMinutesToday / _capMinutes).clamp(0.0, 1.0)
        : 0.0;
    final remaining = (_capMinutes - _earnedMinutesToday).clamp(0, _capMinutes);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kDarkGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EARNED TODAY',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatTime(_earnedMinutesToday),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${_formatTime(_capMinutes)}',
                style: const TextStyle(color: Colors.white60, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            remaining > 0
                ? '${_formatTime(remaining)} still available to earn today.'
                : 'You\'ve reached today\'s cap. Nice work!',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (_pendingCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$_pendingCount ${_pendingCount == 1 ? 'activity' : 'activities'} waiting for your parent',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTierFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _TierChip(
            label: 'All',
            active: _tierFilter == 'ALL',
            onTap: () => setState(() => _tierFilter = 'ALL'),
          ),
          const SizedBox(width: 8),
          ..._tiers.map(
            (t) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _TierChip(
                label: '${kTierMinutes[t]} min',
                active: _tierFilter == t,
                onTap: () => setState(() => _tierFilter = t),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetList() {
    final presets = _filteredPresets;
    return Column(
      children: presets
          .map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PresetCard(preset: p, onTap: () => _submitPreset(p)),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCustomButton() {
    return OutlinedButton.icon(
      onPressed: _submitCustom,
      icon: const Icon(Icons.add),
      label: const Text('Add your own activity'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54, width: 1.5),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSubmissionsSection() {
    final pending = _todaySubmissions
        .where((s) => s.status == 'pending')
        .toList();
    final resolved = _todaySubmissions
        .where((s) => s.status != 'pending')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pending.isNotEmpty) ...[
          const Text(
            'WAITING FOR PARENT',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ...pending.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SubmissionRow(task: s),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (resolved.isNotEmpty) ...[
          const Text(
            'RESOLVED TODAY',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ...resolved.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SubmissionRow(task: s),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _submitPreset(ProductiveTaskPreset preset) async {
    if (_capReached) {
      _showComeBackTomorrowDialog();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text(preset.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(child: Text(preset.title)),
          ],
        ),
        content: Text(
          'Worth ${_formatTime(kTierMinutes[preset.tier]!)} of screen time once approved.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Send to parent'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final task = ProductiveTask(
      id: ProductiveTaskService.generateTaskId(_session.childId),
      childId: _session.childId,
      childName: _session.displayName,
      parentUid: _session.parentUid,
      title: preset.title,
      emoji: preset.emoji,
      tier: preset.tier,
      category: preset.category,
      proposedMinutes: kTierMinutes[preset.tier]!,
      isCustom: false,
      status: 'pending',
      submittedAt: DateTime.now(),
    );

    try {
      await _taskService.submitTask(task);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${preset.emoji} Sent to your parent!'),
          backgroundColor: kAccentGreen,
        ),
      );
      _loadTodaySubmissions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitCustom() async {
    if (_capReached) {
      _showComeBackTomorrowDialog();
      return;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _CustomActivityDialog(),
    );
    if (result == null) return;

    final task = ProductiveTask(
      id: ProductiveTaskService.generateTaskId(_session.childId),
      childId: _session.childId,
      childName: _session.displayName,
      parentUid: _session.parentUid,
      title: result['title']!,
      emoji: '🌱',
      tier: 'S',
      category: 'Home',
      proposedMinutes: 15,
      isCustom: true,
      note: result['note']!.isEmpty ? null : result['note'],
      status: 'pending',
      submittedAt: DateTime.now(),
    );

    try {
      await _taskService.submitTask(task);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🌱 Custom activity sent to your parent!'),
          backgroundColor: kAccentGreen,
        ),
      );
      _loadTodaySubmissions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildScreenTimeWidget() {
    if (_usesFamilyActivityPicker) {
      return _buildFamilyActivitySummaryCard();
    }

    if (!_hasUsagePermission) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange),
        ),
        child: Column(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Screen Time Monitoring Disabled',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enable screen time permissions in device settings to track usage.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      UnifiedScreenTimeService.getPermissionInstructions(),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    if (_screenTimeStats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No screen time data available yet.',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: _selectedApps.map((app) {
        final appStats = _screenTimeStats[app];
        if (appStats == null) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildAppIcon(app),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'No usage data',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final usedTimeMs = (appStats['usedTime'] as num).toInt();
        final remainingTimeMs = (appStats['remainingTime'] as num).toDouble();
        final dailyLimitMs = (appStats['dailyLimit'] as num).toInt();
        final isBlocked = appStats['isBlocked'] as bool;

        final usedMinutes = (usedTimeMs / (1000 * 60)).round();
        final remainingMinutes = (remainingTimeMs / (1000 * 60)).round();
        final progress = dailyLimitMs > 0
            ? (usedTimeMs / dailyLimitMs).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isBlocked ? Colors.red.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isBlocked ? Border.all(color: Colors.red, width: 2) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAppIcon(app, blocked: isBlocked),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      app,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isBlocked ? Colors.red : Colors.black,
                      ),
                    ),
                  ),
                  if (isBlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'BLOCKED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isBlocked
                      ? Colors.red
                      : (progress > 0.8 ? Colors.orange : kAccentGreen),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Used: ${_formatTime(usedMinutes)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    'Remaining: ${_formatTime(remainingMinutes)}',
                    style: TextStyle(
                      color: isBlocked ? Colors.red : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (isBlocked)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Complete productive tasks to earn more screen time!',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFamilyActivitySummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kAccentGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.apps, color: kDarkGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Managed by Screen Time',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_familyActivityAppCount ${_familyActivityAppCount == 1 ? 'app' : 'apps'} and '
                  '$_familyActivityCategoryCount ${_familyActivityCategoryCount == 1 ? 'category' : 'categories'} '
                  'are blocked once your earned screen time runs out.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  Future<void> _showParentalPinOverrideDialog() async {
    final hasUsedOverrideToday = await _checkIfOverrideUsedToday();

    if (hasUsedOverrideToday) {
      _showOverrideLimitReachedDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ParentalPinOverrideDialog(
          childName: widget.childName,
          onOverrideApplied: _refreshScreenTimeOnly,
        );
      },
    );
  }

  Future<void> _refreshScreenTimeOnly() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final updatedStats = await _getScreenTimeStatsWithFirestoreLimits();
      if (mounted) {
        setState(() => _screenTimeStats = updatedStats);
      }
    } catch (e) {
      print('ChildDashboard: Error refreshing screen time stats: $e');
    }
  }

  Future<Map<String, dynamic>> _getScreenTimeStatsWithFirestoreLimits() async {
    try {
      final usageStats = await UnifiedScreenTimeService.getCurrentUsageStats();

      final childDoc = await _session.childRef().get();

      if (!childDoc.exists) return usageStats;

      final childData = childDoc.data()!;
      final Map<String, dynamic> appLimits = childData['appLimits'] ?? {};

      Map<String, dynamic> updatedStats = {};
      usageStats.forEach((appName, stats) {
        if (appLimits.containsKey(appName)) {
          final limitData = appLimits[appName];
          final firestoreLimitMinutes = limitData['dailyLimitMinutes'] ?? 60;
          final firestoreLimitMs = firestoreLimitMinutes * 60 * 1000;

          final usedTimeMs = stats['usedTime'] ?? 0;
          final earnedTimeMs = stats['earnedTime'] ?? 0;

          final remainingTimeMs = (firestoreLimitMs + earnedTimeMs - usedTimeMs)
              .clamp(0, double.infinity)
              .toInt();
          final totalAvailableTime = firestoreLimitMs + earnedTimeMs;
          final isBlocked = usedTimeMs >= totalAvailableTime;

          updatedStats[appName] = {
            ...stats,
            'dailyLimit': firestoreLimitMs,
            'remainingTime': remainingTimeMs,
            'isBlocked': isBlocked,
          };
        } else {
          updatedStats[appName] = stats;
        }
      });

      return updatedStats;
    } catch (e) {
      print('ChildDashboard: Error getting Firestore limits: $e');
      return await UnifiedScreenTimeService.getCurrentUsageStats();
    }
  }

  Future<bool> _checkIfOverrideUsedToday() async {
    try {
      final childDoc = await _session.childRef().get();

      if (!childDoc.exists) return false;

      final childData = childDoc.data()!;
      final lastOverrideDate = childData['lastParentalOverride'] as String?;
      final today = DateTime.now().toIso8601String().split('T')[0];

      return lastOverrideDate == today;
    } catch (e) {
      print('ParentalOverride: Error checking override usage: $e');
      return false;
    }
  }

  void _showOverrideLimitReachedDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.block, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              Text(
                'Daily Limit Reached',
                style: TextStyle(
                  color: kDarkGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            '${widget.childName} has already used the parental override today.\n\nThe override can only be used once per day. Please try again tomorrow.',
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  void _showComeBackTomorrowDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Text('⏳', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Text(
                'Come back tomorrow!',
                style: TextStyle(
                  color: kDarkGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            "You've earned all the screen time you can for today. Log more activities tomorrow to keep earning!",
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }
}

class _TierChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TierChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? kDarkGreen : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final ProductiveTaskPreset preset;
  final VoidCallback onTap;

  const _PresetCard({required this.preset, required this.onTap});

  String _fmt(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  @override
  Widget build(BuildContext context) {
    final minutes = kTierMinutes[preset.tier]!;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kAccentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    preset.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kTierLabel[preset.tier]!,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fmt(minutes),
                    style: TextStyle(
                      color: kDarkGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'screen time',
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  final ProductiveTask task;

  const _SubmissionRow({required this.task});

  String _fmt(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (task.status) {
      case 'approved':
        statusColor = Colors.green;
        statusLabel = '+${_fmt(task.awardedMinutes ?? task.proposedMinutes)}';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = 'Declined';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'Waiting';
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(task.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_fmt(task.proposedMinutes)}${task.isCustom ? ' · custom' : ''}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(width: 4),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
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

class _CustomActivityDialog extends StatefulWidget {
  @override
  State<_CustomActivityDialog> createState() => _CustomActivityDialogState();
}

class _CustomActivityDialogState extends State<_CustomActivityDialog> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _titleController.text.trim().length >= 2;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Your own activity'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Starts at 15 minutes. Your parent can adjust the time when approving.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            maxLength: 80,
            decoration: InputDecoration(
              hintText: 'What did you do?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            maxLength: 240,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add a quick note (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canSubmit
              ? () => Navigator.pop(context, {
                  'title': _titleController.text.trim(),
                  'note': _noteController.text.trim(),
                })
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccentGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Send to Parent'),
        ),
      ],
    );
  }
}



class _ParentalPinOverrideDialog extends StatefulWidget {
  final String childName;
  final VoidCallback? onOverrideApplied;

  const _ParentalPinOverrideDialog({
    required this.childName,
    this.onOverrideApplied,
  });

  @override
  State<_ParentalPinOverrideDialog> createState() =>
      _ParentalPinOverrideDialogState();
}

class _ParentalPinOverrideDialogState
    extends State<_ParentalPinOverrideDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            'Parental Override',
            style: TextStyle(color: kDarkGreen, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the parental PIN to grant ${widget.childName} an additional 15 minutes of screen time.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 5,
            decoration: InputDecoration(
              labelText: 'Parental PIN',
              hintText: 'Enter 5-digit PIN',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.lock),
              errorText: _errorMessage.isEmpty ? null : _errorMessage,
            ),
            onSubmitted: (_) => _validateAndOverride(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "This will add 15 minutes to today's screen time allowance.",
                    style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _validateAndOverride,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Override',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Future<void> _validateAndOverride() async {
    final pin = _pinController.text.trim();

    if (pin.length != 5) {
      setState(() => _errorMessage = 'PIN must be 5 digits');
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      setState(() => _errorMessage = 'PIN must contain only numbers');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final success = await _applyParentalOverride(pin);
      if (success) {
        Navigator.of(context).pop();
        _showOverrideSuccessDialog();
      } else {
        setState(() {
          _errorMessage = 'Incorrect PIN. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error applying override. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<bool> _applyParentalOverride(String pin) async {
    try {
      final session = ChildSessionService.requireSession();

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(session.parentUid)
          .get();
      if (!doc.exists) return false;

      final storedPin = doc.data()?['pin'];
      if (storedPin == null || pin != storedPin) return false;

      await _addBonusTimeToAllApps(15);
      return true;
    } catch (e) {
      print('ParentalOverride: Error - $e');
      return false;
    }
  }

  Future<void> _addBonusTimeToAllApps(int bonusMinutes) async {
    try {
      final session = ChildSessionService.requireSession();
      final childRef = session.childRef();
      final childDoc = await childRef.get();

      if (!childDoc.exists) return;

      final childData = childDoc.data()!;
      final Map<String, dynamic> appLimits = childData['appLimits'] ?? {};

      if (appLimits.isEmpty) {
        await _createInitialAppLimits(childData, bonusMinutes);
        return;
      }

      Map<String, dynamic> updatedLimits = {};
      appLimits.forEach((appName, limitData) {
        if (limitData is Map<String, dynamic>) {
          final currentLimit = limitData['dailyLimitMinutes'] ?? 0;
          updatedLimits[appName] = {
            ...limitData,
            'dailyLimitMinutes': currentLimit + bonusMinutes,
          };
        } else {
          updatedLimits[appName] = limitData;
        }
      });

      final today = DateTime.now().toIso8601String().split('T')[0];
      await childRef.update({
        'appLimits': updatedLimits,
        'lastParentalOverride': today,
      });

      await UnifiedScreenTimeService.updateScreenTimeRules();
    } catch (e) {
      print('ParentalOverride: Error adding bonus time - $e');
      rethrow;
    }
  }

  void _showOverrideSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              Text(
                'Override Applied!',
                style: TextStyle(
                  color: kDarkGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            '${widget.childName} has been granted an additional 15 minutes of screen time for today.',
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onOverrideApplied?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
  }

  Future<void> _createInitialAppLimits(
    Map<String, dynamic> childData,
    int bonusMinutes,
  ) async {
    try {
      final session = ChildSessionService.requireSession();
      final selectedApps = List<String>.from(childData['selectedApps'] ?? []);

      final settingsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(session.parentUid)
          .collection('settings')
          .doc('screenTimeRules')
          .get();

      double baseLimitHours = 1.0;
      if (settingsDoc.exists) {
        final settingsData = settingsDoc.data()!;
        final applySameForAll = settingsData['applySameForAll'] ?? false;
        if (applySameForAll) {
          baseLimitHours = (settingsData['unifiedRules']?['limit'] ?? 1.0)
              .toDouble();
        } else {
          // Prefer children[childId], fall back to the legacy
          // children[displayName] entry — see resolveChildRuleEntry.
          final childrenData =
              settingsData['children'] as Map<String, dynamic>? ?? {};
          final entry = resolveChildRuleEntry(
            childrenData: childrenData,
            parentUid: session.parentUid,
            childId: session.childId,
            displayName: session.displayName,
          );
          if (entry != null) {
            baseLimitHours = (entry['limit'] ?? 1.0).toDouble();
          }
        }
      }

      final newLimitMinutes = (baseLimitHours * 60).toInt() + bonusMinutes;

      Map<String, dynamic> appLimits = {};
      for (final appName in selectedApps) {
        appLimits[appName] = {'dailyLimitMinutes': newLimitMinutes};
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      await session.childRef().update({
        'appLimits': appLimits,
        'lastParentalOverride': today,
      });
    } catch (e) {
      print('ParentalOverride: Error creating initial app limits - $e');
      rethrow;
    }
  }
}
