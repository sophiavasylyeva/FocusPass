
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import '../services/unified_screen_time_service.dart';
import '../services/educational_task_service.dart';
import '../services/overlay_notification_service.dart';
import '../models/educational_task.dart';
import 'screen_time_test_screen.dart';
import 'educational_content_test_screen.dart';
import 'login_screen.dart';

class ChildDashboardScreen extends StatefulWidget {
  final String childName;

  const ChildDashboardScreen({super.key, required this.childName});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> {
  String? _ageRange;
  List<String> _selectedApps = [];
  List<String> _subjectsOfInterest = [];
  bool _isLoading = true;
  Map<String, dynamic> _screenTimeStats = {};
  bool _hasUsagePermission = false;
  List<EducationalTask> _pendingTasks = [];
  bool _tasksLoading = false;

  @override
  void initState() {
    super.initState();
    fetchChildData();
    _initializeScreenTime();
  }

  Future<void> fetchChildData() async {
    try {
      final query = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('name', isEqualTo: widget.childName)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        setState(() {
          _ageRange = data['ageRange'] ?? 'Not set';
          _selectedApps = List<String>.from(data['selectedApps'] ?? []);
          _subjectsOfInterest = List<String>.from(data['subjectsOfInterest'] ?? []);
          _isLoading = false;
        });
        
        // Load educational tasks after child data is loaded
        _loadEducationalTasks();
      } else {
        setState(() {
          _isLoading = false;
        });
        print('❌ Child not found');
      }
    } catch (e) {
      print('❌ Error fetching child data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeScreenTime() async {
    // Set current child name for screen time service
    await UnifiedScreenTimeService.setCurrentChildName(widget.childName);
    
    // Initialize screen time service
    await UnifiedScreenTimeService.initialize();
    
    // Check permissions
    final hasPermission = await UnifiedScreenTimeService.hasPermissions();
    
    setState(() {
      _hasUsagePermission = hasPermission;
    });
    
    // Get initial stats
    final stats = await _getScreenTimeStatsWithFirestoreLimits();
    setState(() {
      _screenTimeStats = stats;
    });
    
    // Start periodic updates of screen time stats
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (mounted) {
        final updatedStats = await _getScreenTimeStatsWithFirestoreLimits();
        setState(() {
          _screenTimeStats = updatedStats;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadEducationalTasks() async {
    print('📚 _loadEducationalTasks: Starting - subjects: $_subjectsOfInterest, age: $_ageRange');
    
    if (_subjectsOfInterest.isEmpty || _ageRange == null) {
      print('📚 _loadEducationalTasks: Waiting for child data - subjects empty: ${_subjectsOfInterest.isEmpty}, age null: ${_ageRange == null}');
      return;
    }

    setState(() {
      _tasksLoading = true;
    });

    try {
      final taskService = EducationalTaskService();
      
      print('📚 _loadEducationalTasks: Generating daily tasks for ${widget.childName}');
      // Generate daily tasks if they don't exist
      await taskService.generateDailyTasks(widget.childName, _subjectsOfInterest, _ageRange!);
      
      print('📚 _loadEducationalTasks: Fetching tasks for ${widget.childName}');
      // Load all tasks for this child
      final allTasks = await taskService.fetchTasks(widget.childName);
      
      print('📚 _loadEducationalTasks: Found ${allTasks.length} total tasks');
      
      // Filter to only today's pending tasks that match selected subjects
      final now = DateTime.now();
      bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
      
      final Set<String> allowedSubjects = _subjectsOfInterest.map((s) => s.toLowerCase()).toSet();
      
      final todaysMatchingPending = allTasks.where((task) {
        final matchesDay = isSameDay(task.assignedAt, now);
        final matchesSubject = allowedSubjects.contains(task.subject.toLowerCase());
        return matchesDay && matchesSubject && !task.isCompleted;
      }).toList();
      
      // Ensure only one task per subject (pick the latest by assignedAt if multiple)
      final Map<String, EducationalTask> latestPerSubject = {};
      for (final task in todaysMatchingPending) {
        final key = task.subject.toLowerCase();
        if (!latestPerSubject.containsKey(key) || task.assignedAt.isAfter(latestPerSubject[key]!.assignedAt)) {
          latestPerSubject[key] = task;
        }
      }
      final pendingTasks = latestPerSubject.values.toList();
      
      print('📚 _loadEducationalTasks: After filtering, ${pendingTasks.length} pending tasks for today and selected subjects');
      
      setState(() {
        _pendingTasks = pendingTasks;
        _tasksLoading = false;
      });
    } catch (e) {
      print('❌ Error loading educational tasks: $e');
      setState(() {
        _tasksLoading = false;
      });
    }
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
        title: const Text('Child Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.school),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EducationalContentTestScreen(childName: widget.childName),
                ),
              );
            },
            tooltip: 'Educational Tasks',
          ),
          // Screen Time Test button - Hidden from production
          // IconButton(
          //   icon: const Icon(Icons.bug_report),
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => ScreenTimeTestScreen(childName: widget.childName),
          //       ),
          //     );
          //   },
          //   tooltip: 'Screen Time Test',
          // ),
          // Clear All Tasks button - Hidden from production (testing tool)
          // IconButton(
          //   icon: const Icon(Icons.clear_all),
          //   onPressed: () async {
          //     final taskService = EducationalTaskService();
          //     await taskService.clearAllTasks(widget.childName);
          //     _loadEducationalTasks(); // Reload tasks
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       const SnackBar(
          //         content: Text('🗑️ All tasks cleared! New tasks will be generated.'),
          //         backgroundColor: Colors.orange,
          //       ),
          //     );
          //   },
          //   tooltip: 'Clear All Tasks (Testing)',
          // ),
          // Found Apps in Data button - Hidden from production
          // IconButton(
          //   icon: const Icon(Icons.analytics),
          //   onPressed: () async {
          //     // Debug: Run comprehensive diagnosis
          //     print('🔍 DEBUG: Running comprehensive diagnosis...');
          //     final diagnosis = await UnifiedScreenTimeService.diagnoseProblem();
          //     final stats = await UnifiedScreenTimeService.getCurrentUsageStats();
          //     setState(() {
          //       _screenTimeStats = stats;
          //     });
          //     
          //     // Show detailed results
          //     final hasPermission = diagnosis['hasPermission'] ?? false;
          //     final message = hasPermission 
          //       ? 'Found ${stats.length} apps with data. Check console for details.'
          //       : 'NO PERMISSIONS! Go to Settings > Apps > Special Access > Usage Access > FocusPass';
          //     
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       SnackBar(
          //         content: Text('🔍 $message'),
          //         backgroundColor: hasPermission ? Colors.blue : Colors.red,
          //         duration: const Duration(seconds: 5),
          //       ),
          //     );
          //   },
          //   tooltip: 'Debug Diagnosis',
          // ),
          // Test Notifications button - Hidden from production (testing tool)
          // IconButton(
          //   icon: const Icon(Icons.notifications),
          //   onPressed: () {
          //     // Test overlay notifications
          //     OverlayNotificationService.showScreenTimeWarning(
          //       context: context,
          //       appName: 'YouTube',
          //       remainingMinutes: 5,
          //     );
          //   },
          //   tooltip: 'Test Notifications',
          // ),
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
            const SizedBox(height: 12),
            const SizedBox(height: 20),

            // ⏰ Screen Time Section
            const Text(
              'Screen Time Management:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 12),
            _buildScreenTimeWidget(),
            const SizedBox(height: 24),
            
            // 📝 Manage Subjects Section
            _buildManageSubjectsWidget(),
            const SizedBox(height: 24),

            // 📚 Educational Tasks Section
            _buildEducationalTasksWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenTimeWidget() {
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Please enable screen time permissions in device settings to track usage.',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                // Show platform-specific instructions
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(UnifiedScreenTimeService.getPermissionInstructions()),
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
                Icon(Icons.phone_android, color: kAccentGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Text('No usage data', style: TextStyle(color: Colors.grey)),
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

        final progress = dailyLimitMs > 0 ? (usedTimeMs / dailyLimitMs).clamp(0.0, 1.0) : 0.0;

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
                  Icon(
                    isBlocked ? Icons.block : Icons.phone_android,
                    color: isBlocked ? Colors.red : kAccentGreen,
                  ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'BLOCKED',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isBlocked ? Colors.red : (progress > 0.8 ? Colors.orange : kAccentGreen),
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
                    style: TextStyle(color: isBlocked ? Colors.red : Colors.grey[600]),
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
                            'Complete learning tasks to earn more screen time!',
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

  Widget _buildEducationalTasksWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Educational Tasks:',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.school, color: kAccentGreen, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Complete Educational Tasks',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Answer questions to earn screen time for your apps',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EducationalContentTestScreen(childName: widget.childName),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Start Learning'),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  final List<String> _allSubjects = [
    'Math', 'Science', 'English', 'History', 'Art', 'Coding', 'Geography',
  ];

  Widget _buildManageSubjectsWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Subjects:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            TextButton.icon(
              onPressed: _showAddSubjectDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Subject', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: kDarkGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _subjectsOfInterest.map((subject) {
            return Chip(
              label: Text(subject, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              backgroundColor: kDarkGreen,
              deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white70),
              onDeleted: () => _removeSubject(subject),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showAddSubjectDialog() {
    final availableSubjects = _allSubjects
        .where((s) => !_subjectsOfInterest.contains(s))
        .toList();

    if (availableSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already added all available subjects.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add a Subject'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableSubjects.map((subject) {
              return ListTile(
                title: Text(subject),
                leading: const Icon(Icons.add_circle_outline),
                onTap: () {
                  Navigator.of(context).pop();
                  _addSubject(subject);
                },
              );
            }).toList(),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
      },
    );
  }

  Future<void> _addSubject(String subject) async {
    setState(() {
      _subjectsOfInterest.add(subject);
    });
    await _updateSubjectsInFirestore();
    _loadEducationalTasks();
  }

  Future<void> _removeSubject(String subject) async {
    if (_subjectsOfInterest.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must have at least one subject selected.')),
      );
      return;
    }
    setState(() {
      _subjectsOfInterest.remove(subject);
    });
    await _updateSubjectsInFirestore();
    _loadEducationalTasks();
  }

  Future<void> _updateSubjectsInFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(widget.childName)
          .update({
        'subjectsOfInterest': _subjectsOfInterest,
      });
    } catch (e) {
      print('Error updating subjects: $e');
    }
  }

  void _startTask(EducationalTask task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EducationalContentTestScreen(childName: widget.childName),
      ),
    );
  }
  
  void _onTaskCompleted(EducationalTask completedTask) {
    // Reload tasks to refresh the UI
    _loadEducationalTasks();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Task completed! You earned ${completedTask.screenTimeRewardMinutes} minutes!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTime(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  Future<void> _showParentalPinOverrideDialog() async {
    // Check if parental override has already been used today
    final hasUsedOverrideToday = await _checkIfOverrideUsedToday();
    
    if (hasUsedOverrideToday) {
      _showOverrideLimitReachedDialog();
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _ParentalPinOverrideDialog(childName: widget.childName, onOverrideApplied: _refreshScreenTimeOnly);
      },
    );
  }

  Future<void> _refreshScreenTimeOnly() async {
    try {
      print('ChildDashboard: Refreshing screen time stats after parental override...');
      
      // Give Firestore a moment to propagate the changes
      await Future.delayed(Duration(milliseconds: 300));
      
      // Get the updated stats from Firestore (this already includes the bonus calculation)
      final updatedStats = await _getScreenTimeStatsWithFirestoreLimits();
      
      if (mounted) {
        setState(() {
          _screenTimeStats = updatedStats;
        });
        print('ChildDashboard: Screen time stats refreshed successfully. Found ${updatedStats.length} apps.');
        
        // Log the updated remaining times for debugging
        updatedStats.forEach((appName, stats) {
          final remainingMinutes = (stats['remainingTime'] as num) ~/ (60 * 1000);
          print('ChildDashboard: $appName remaining time: ${remainingMinutes}m');
        });
      }
    } catch (e) {
      print('ChildDashboard: Error refreshing screen time stats: $e');
    }
  }

  Future<Map<String, dynamic>> _getScreenTimeStatsWithFirestoreLimits() async {
    try {
      print('ChildDashboard: Getting screen time stats with Firestore limits...');
      
      // Get usage data from the screen time service
      final usageStats = await UnifiedScreenTimeService.getCurrentUsageStats();
      print('ChildDashboard: Got ${usageStats.length} apps from UnifiedScreenTimeService');
      print('ChildDashboard: UnifiedScreenTimeService stats:');
      usageStats.forEach((appName, stats) {
        final usedMinutes = (stats['usedTime'] as num) ~/ (60 * 1000);
        final remainingMinutes = (stats['remainingTime'] as num) ~/ (60 * 1000);
        final limitMinutes = (stats['dailyLimit'] as num) ~/ (60 * 1000);
        print('  $appName: used ${usedMinutes}m, remaining ${remainingMinutes}m, limit ${limitMinutes}m');
      });
      
      // Get app limits from Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('ChildDashboard: No user logged in');
        return usageStats;
      }

      print('ChildDashboard: About to read from Firestore path: users/${user.uid}/children/${widget.childName}');
      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(widget.childName)
          .get();
      
      if (!childDoc.exists) {
        print('ChildDashboard: Child document does not exist at path users/${user.uid}/children/${widget.childName}');
        return usageStats;
      }

      final childData = childDoc.data()!;
      print('ChildDashboard: Full child document data: $childData');
      final Map<String, dynamic> appLimits = childData['appLimits'] ?? {};
      print('ChildDashboard: Got ${appLimits.length} app limits from Firestore');
      
      // Log the specific app limits for debugging
      appLimits.forEach((appName, limitData) {
        if (limitData is Map<String, dynamic>) {
          final limitMinutes = limitData['dailyLimitMinutes'] ?? 0;
          print('ChildDashboard: Firestore limit for $appName: ${limitMinutes}m');
        }
      });
      
      // Combine usage data with updated limits from Firestore
      Map<String, dynamic> updatedStats = {};
      usageStats.forEach((appName, stats) {
        if (appLimits.containsKey(appName)) {
          final limitData = appLimits[appName];
          final firestoreLimitMinutes = limitData['dailyLimitMinutes'] ?? 60;
          final firestoreLimitMs = firestoreLimitMinutes * 60 * 1000;
          
          final usedTimeMs = stats['usedTime'] ?? 0;
          final earnedTimeMs = stats['earnedTime'] ?? 0;
          
          // Simple calculation: Use Firestore limit directly and calculate remaining time
          final remainingTimeMs = (firestoreLimitMs + earnedTimeMs - usedTimeMs).clamp(0, double.infinity).toInt();
          
          // Determine if the app should be blocked
          final totalAvailableTime = firestoreLimitMs + earnedTimeMs;
          final isBlocked = usedTimeMs >= totalAvailableTime;
          
          updatedStats[appName] = {
            ...stats,
            'dailyLimit': firestoreLimitMs,
            'remainingTime': remainingTimeMs,
            'isBlocked': isBlocked,
          };
          
          print('ChildDashboard: Updated $appName - firestore limit: ${firestoreLimitMinutes}m, used: ${usedTimeMs ~/ (60 * 1000)}m, remaining: ${remainingTimeMs ~/ (60 * 1000)}m');
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(widget.childName)
          .get();
      
      if (!childDoc.exists) return false;

      final childData = childDoc.data()!;
      final lastOverrideDate = childData['lastParentalOverride'] as String?;
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      print('ParentalOverride: Last override date: $lastOverrideDate, Today: $today');
      
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
              Icon(Icons.block, color: Colors.red, size: 28),
              SizedBox(width: 8),
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
            '${widget.childName} has already reached their screen time for today.\n\nThe parental override can only be used once per day. Please try again tomorrow.',
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
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

class _ParentalPinOverrideDialog extends StatefulWidget {
  final String childName;
  final VoidCallback? onOverrideApplied;

  const _ParentalPinOverrideDialog({required this.childName, this.onOverrideApplied});

  @override
  State<_ParentalPinOverrideDialog> createState() => _ParentalPinOverrideDialogState();
}

class _ParentalPinOverrideDialogState extends State<_ParentalPinOverrideDialog> {
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
          Icon(Icons.admin_panel_settings, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text(
            'Parental Override',
            style: TextStyle(
              color: kDarkGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the parental PIN to grant ${widget.childName} an additional 15 minutes of screen time.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
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
              prefixIcon: Icon(Icons.lock),
              errorText: _errorMessage.isEmpty ? null : _errorMessage,
            ),
            onSubmitted: (_) => _validateAndOverride(),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This will add 15 minutes to today\'s screen time allowance.',
                    style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text('Override', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Future<void> _validateAndOverride() async {
    final pin = _pinController.text.trim();
    
    if (pin.length != 5) {
      setState(() {
        _errorMessage = 'PIN must be 5 digits';
      });
      return;
    }

    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      setState(() {
        _errorMessage = 'PIN must contain only numbers';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Validate PIN and apply override
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
      print('ParentalOverride: Error - $e');
    }
  }

  Future<bool> _applyParentalOverride(String pin) async {
    try {
      // Fetch the actual parental PIN from Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('ParentalOverride: No user logged in');
        return false;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!doc.exists) {
        print('ParentalOverride: No user document found');
        return false;
      }

      final storedPin = doc.data()?['pin'];
      if (storedPin == null) {
        print('ParentalOverride: No PIN set in parent settings');
        return false;
      }

      if (pin != storedPin) {
        print('ParentalOverride: PIN mismatch');
        return false;
      }

      // Grant 15 minutes of additional screen time by updating each app's limits
      await _addBonusTimeToAllApps(15);
      print('ParentalOverride: Added 15 minutes bonus time for ${widget.childName}');
      return true;
    } catch (e) {
      print('ParentalOverride: Error - $e');
      return false;
    }
  }

  Future<void> _addBonusTimeToAllApps(int bonusMinutes) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('ParentalOverride: No user logged in');
        return;
      }

      // Get all the child's app limits
      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(widget.childName)
          .get();
      
      if (!childDoc.exists) {
        print('ParentalOverride: Child document does not exist');
        return;
      }

      final childData = childDoc.data()!;
      final Map<String, dynamic> appLimits = childData['appLimits'] ?? {};
      
      // If appLimits is empty, we need to create them from selectedApps and screen time rules
      if (appLimits.isEmpty) {
        print('ParentalOverride: No appLimits found, creating them from selectedApps and screen time rules');
        await _createInitialAppLimits(childData, bonusMinutes);
        return;
      }
      
      // Add bonus time to each app's daily limit
      Map<String, dynamic> updatedLimits = {};
      print('ParentalOverride: Found ${appLimits.length} apps to update');
      print('ParentalOverride: Original appLimits contents:');
      appLimits.forEach((appName, limitData) {
        print('  $appName: $limitData');
      });
      
      appLimits.forEach((appName, limitData) {
        if (limitData is Map<String, dynamic>) {
          final currentLimit = limitData['dailyLimitMinutes'] ?? 0;
          final newLimit = currentLimit + bonusMinutes;
          updatedLimits[appName] = {
            ...limitData,
            'dailyLimitMinutes': newLimit,
          };
          print('ParentalOverride: Updated $appName limit: ${currentLimit}m → ${newLimit}m');
        } else {
          print('ParentalOverride: WARNING - $appName limitData is not a Map: $limitData');
          updatedLimits[appName] = limitData;
        }
      });
      
      print('ParentalOverride: Final updatedLimits to save:');
      updatedLimits.forEach((appName, limitData) {
        print('  $appName: $limitData');
      });

      // Update the limits in Firestore and record the override date
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD format
      print('ParentalOverride: About to write to Firestore path: users/${user.uid}/children/${widget.childName}');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(widget.childName)
          .update({
            'appLimits': updatedLimits,
            'lastParentalOverride': today,
          });

      print('ParentalOverride: Successfully updated Firestore with new limits and recorded override date: $today');
      
      // Verify the update worked by reading back
      final verifyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(widget.childName)
          .get();
      
      if (verifyDoc.exists) {
        final verifyLimits = verifyDoc.data()!['appLimits'] ?? {};
        print('ParentalOverride: Verified Firestore limits:');
        verifyLimits.forEach((app, data) {
          if (data is Map<String, dynamic>) {
            print('  - $app: ${data['dailyLimitMinutes']}m');
          }
        });
      }

      // Force update the screen time rules in the unified service to sync with Firestore
      await UnifiedScreenTimeService.updateScreenTimeRules();
      
      print('ParentalOverride: Successfully added $bonusMinutes minutes to all apps and updated unified service');
    } catch (e) {
      print('ParentalOverride: Error adding bonus time - $e');
      throw e;
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
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
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
            '${widget.childName} has been granted an additional 15 minutes of screen time for today.\n\nThe extra time has been added to all app limits and should now be visible in the Screen Time Management section below. The updated remaining time may take a few moments to appear.',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Single refresh call to avoid glitchy multiple updates
                widget.onOverrideApplied?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentGreen,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
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

  Future<void> _createInitialAppLimits(Map<String, dynamic> childData, int bonusMinutes) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final selectedApps = List<String>.from(childData['selectedApps'] ?? []);
      print('ParentalOverride: Creating app limits for selected apps: $selectedApps');
      
      // Get the parent's screen time rules to determine the base daily limit
      final settingsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('screenTimeRules')
          .get();
      
      double baseLimitHours = 1.0; // Default 1 hour
      
      if (settingsDoc.exists) {
        final settingsData = settingsDoc.data()!;
        final applySameForAll = settingsData['applySameForAll'] ?? false;
        
        if (applySameForAll) {
          baseLimitHours = (settingsData['unifiedRules']?['limit'] ?? 1.0).toDouble();
        } else {
          final childrenData = settingsData['children'] as Map<String, dynamic>? ?? {};
          if (childrenData.containsKey(widget.childName)) {
            baseLimitHours = (childrenData[widget.childName]['limit'] ?? 1.0).toDouble();
          }
        }
      }
      
      final baseLimitMinutes = (baseLimitHours * 60).toInt();
      final newLimitMinutes = baseLimitMinutes + bonusMinutes;
      
      print('ParentalOverride: Base limit: ${baseLimitMinutes}m, adding bonus: ${bonusMinutes}m, new limit: ${newLimitMinutes}m');
      
      // Create appLimits for each selected app
      Map<String, dynamic> appLimits = {};
      for (final appName in selectedApps) {
        appLimits[appName] = {
          'dailyLimitMinutes': newLimitMinutes,
        };
      }
      
      print('ParentalOverride: Created initial appLimits: $appLimits');
      
      // Save to Firestore and record the override date
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD format
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(widget.childName)
          .update({
            'appLimits': appLimits,
            'lastParentalOverride': today,
          });
      
      print('ParentalOverride: Successfully created and saved initial appLimits with bonus and recorded override date: $today');
      
    } catch (e) {
      print('ParentalOverride: Error creating initial app limits: $e');
      throw e;
    }
  }

}
