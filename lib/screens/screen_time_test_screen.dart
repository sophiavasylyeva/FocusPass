import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/unified_screen_time_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import 'dart:async';
import 'dart:io';

class ScreenTimeTestScreen extends StatefulWidget {
  final String childName;
  
  const ScreenTimeTestScreen({super.key, required this.childName});

  @override
  State<ScreenTimeTestScreen> createState() => _ScreenTimeTestScreenState();
}

class _ScreenTimeTestScreenState extends State<ScreenTimeTestScreen> {
  bool _hasPermissions = false;
  Map<String, dynamic> _usageStats = {};
  List<String> _testLogs = [];
  Timer? _testTimer;
  bool _isTestingActive = false;
  int _testDuration = 0;
  String _simulatedApp = 'Instagram';
  
  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTest() async {
    _addLog('🔄 Starting initialization...');
    
    await UnifiedScreenTimeService.setCurrentChildName(widget.childName);
    _addLog('👤 Child name set to: ${widget.childName}');
    
    await UnifiedScreenTimeService.initialize();
    _addLog('⚙️ Screen time service initialized');
    
    final hasPermissions = await UnifiedScreenTimeService.hasPermissions();
    _addLog('🔍 Checking permissions...');
    
    final stats = await UnifiedScreenTimeService.getCurrentUsageStats();
    _addLog('📊 Getting usage stats...');
    
    setState(() {
      _hasPermissions = hasPermissions;
      _usageStats = stats;
    });
    
    _addLog('✅ Screen time service initialized');
    _addLog('📱 Platform: ${UnifiedScreenTimeService.getPlatformName()}');
    _addLog('🔐 Permissions: ${_hasPermissions ? 'Granted' : 'Denied'}');
    _addLog('📊 Apps being monitored: ${_usageStats.keys.join(', ')}');
    
    if (_usageStats.isEmpty) {
      _addLog('⚠️ No usage data found - this could mean:');
      _addLog('  • Usage stats permission not granted');
      _addLog('  • No apps have been used today');
      _addLog('  • App name mapping issue');
    }
    
    // Show more detailed info
    _addLog('📋 Detailed stats:');
    _usageStats.forEach((app, data) {
      _addLog('  • $app: ${data.toString()}');
    });
  }

  void _addLog(String message) {
    setState(() {
      _testLogs.insert(0, '${DateTime.now().toIso8601String().split('T')[1].split('.')[0]} - $message');
    });
  }

  Future<void> _startScreenTimeTest() async {
    if (!_hasPermissions) {
      _addLog('❌ Cannot start test - permissions not granted');
      _addLog('🔧 Please enable Usage Access for FocusPass in Android Settings');
      await _showPermissionDialog();
      return;
    }

    setState(() {
      _isTestingActive = true;
      _testDuration = 0;
    });

    _addLog('🚀 Starting real-time screen time monitoring');
    _addLog('📱 Monitoring actual usage of: $_simulatedApp');
    _addLog('⚠️ Note: Open $_simulatedApp now to test real usage tracking');
    
    _testTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      _testDuration += 10;
      
      // Update usage stats with real data
      final stats = await UnifiedScreenTimeService.getCurrentUsageStats();
      setState(() {
        _usageStats = stats;
      });
      
      // Check if app is blocked
      final appStats = _usageStats[_simulatedApp];
      if (appStats != null) {
        final isBlocked = appStats['isBlocked'] as bool;
        final usedTime = (appStats['usedTime'] as num).toInt();
        final remainingTime = (appStats['remainingTime'] as num).toDouble();
        
        _addLog('⏱️ Test duration: ${_testDuration}s');
        _addLog('📊 $_simulatedApp: Used ${(usedTime / (1000 * 60)).round()}m, Remaining ${(remainingTime / (1000 * 60)).round()}m');
        
        if (isBlocked) {
          _addLog('🚫 $_simulatedApp is now BLOCKED!');
          _addLog('🎯 Screen time limit reached - test successful!');
          _stopTest();
        }
      } else {
        _addLog('⚠️ No data for $_simulatedApp - try opening the app');
      }
      
      // Stop test after 5 minutes if nothing happens
      if (_testDuration >= 300) {
        _addLog('⏰ Test timeout - stopping after 5 minutes');
        _stopTest();
      }
    });
  }

  Future<void> _showPermissionDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usage Access Required'),
        content: const Text(
          'FocusPass needs Usage Access permission to monitor screen time.\n\n'
          'Steps:\n'
          '1. Go to Settings > Apps > Special Access\n'
          '2. Tap "Usage Access"\n'
          '3. Find FocusPass and enable it\n'
          '4. Return to this screen and try again'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _stopTest() {
    _testTimer?.cancel();
    setState(() {
      _isTestingActive = false;
    });
    _addLog('⏹️ Test stopped');
  }

  Future<void> _simulateTaskCompletion() async {
    const earnedMinutes = 15.0;
    await UnifiedScreenTimeService.addEarnedTime(earnedMinutes);
    _addLog('🎉 Simulated task completion - earned ${earnedMinutes}m');
    
    // Refresh stats
    final stats = await UnifiedScreenTimeService.getCurrentUsageStats();
    setState(() {
      _usageStats = stats;
    });
  }
  
  Future<void> _debugRealUsageStats() async {
    _addLog('🔍 Running usage stats debug...');
    if (Platform.isAndroid) {
      try {
        // Call the debug function we added
        await _callDebugFunction();
      } catch (e) {
        _addLog('❌ Debug function failed: $e');
      }
    } else {
      _addLog('⚠️ Debug function only available on Android');
    }
  }
  
  Future<void> _callDebugFunction() async {
    // Import the screen time service directly
    const platform = MethodChannel('com.focuspass.debug');
    try {
      await platform.invokeMethod('debugUsageStats');
    } catch (e) {
      _addLog('❌ Platform channel debug failed: $e');
      // Fallback: manually check usage stats
      await _manualDebugCheck();
    }
  }
  
  Future<void> _manualDebugCheck() async {
    try {
      // This is a basic check we can do from Dart side
      _addLog('📊 Manual debug check starting...');
      
      // Run the detailed debug function
      await UnifiedScreenTimeService.debugUsageStats();
      _addLog('🔍 Detailed debug completed (check console)');
      
      // Get current stats
      final stats = await UnifiedScreenTimeService.getCurrentUsageStats();
      _addLog('📱 Current stats: ${stats.keys.join(", ")}');
      
      // Check permissions
      final hasPermissions = await UnifiedScreenTimeService.hasPermissions();
      _addLog('🔐 Has permissions: $hasPermissions');
      
      // Show stats details
      stats.forEach((app, data) {
        final usedMinutes = (data['usedTime'] / (1000 * 60)).round();
        final remainingMinutes = (data['remainingTime'] / (1000 * 60)).round();
        final isBlocked = data['isBlocked'] as bool;
        _addLog('📊 $app: ${usedMinutes}m used, ${remainingMinutes}m remaining, blocked: $isBlocked');
      });
      
    } catch (e) {
      _addLog('❌ Manual debug failed: $e');
    }
  }

  Future<void> _testNotificationSystem() async {
    if (Platform.isAndroid) {
      await _testAndroidNotifications();
    } else if (Platform.isIOS) {
      await _testIOSNotifications();
    }
  }

  Future<void> _testAndroidNotifications() async {
    try {
      const platform = MethodChannel('com.focuspass.app_blocker');
      await platform.invokeMethod('showBlockingOverlay', {
        'appName': _simulatedApp,
        'message': 'TEST: Screen time limit reached! Complete tasks to earn more time.'
      });
      _addLog('🔔 Android notification test triggered');
    } catch (e) {
      _addLog('❌ Android notification test failed: $e');
    }
  }

  Future<void> _testIOSNotifications() async {
    try {
      const platform = MethodChannel('com.focuspass.screentime');
      await platform.invokeMethod('showTestNotification', {
        'title': 'Screen Time Limit Reached',
        'message': 'Complete learning tasks to earn more screen time!',
        'appName': _simulatedApp
      });
      _addLog('🔔 iOS notification test triggered');
    } catch (e) {
      _addLog('❌ iOS notification test failed: $e');
    }
  }

  Future<void> _openUsageStatsSettings() async {
    try {
      const platform = MethodChannel('com.focuspass.app_blocker');
      await platform.invokeMethod('openUsageStatsSettings');
      _addLog('⚙️ Opened usage stats settings');
      
      // Wait a bit then check permissions again
      await Future.delayed(Duration(seconds: 2));
      final hasPermissions = await UnifiedScreenTimeService.hasPermissions();
      setState(() {
        _hasPermissions = hasPermissions;
      });
      _addLog('🔄 Permission status updated: ${_hasPermissions ? 'Granted' : 'Still denied'}');
    } catch (e) {
      _addLog('❌ Failed to open settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: const Text('Screen Time Test', style: TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _hasPermissions ? Icons.check_circle : Icons.error,
                          color: _hasPermissions ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text('Permissions: ${_hasPermissions ? 'Granted' : 'Denied'}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _isTestingActive ? Icons.play_circle : Icons.pause_circle,
                          color: _isTestingActive ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text('Test Status: ${_isTestingActive ? 'Running' : 'Stopped'}'),
                      ],
                    ),
                    if (_isTestingActive) ...[
                      const SizedBox(height: 4),
                      Text('Test Duration: ${_testDuration}s'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Controls',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // App Selection
                    Row(
                      children: [
                        Text('Test App: '),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<String>(
                            value: _simulatedApp,
                            onChanged: (String? newValue) {
                              setState(() {
                                _simulatedApp = newValue!;
                              });
                            },
                            items: <String>['Instagram', 'TikTok', 'YouTube', 'Snapchat', 'Twitter']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Test Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _hasPermissions && !_isTestingActive
                              ? _startScreenTimeTest
                              : null,
                          icon: Icon(Icons.play_arrow),
                          label: Text('Start Test'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        
                        ElevatedButton.icon(
                          onPressed: _isTestingActive ? _stopTest : null,
                          icon: Icon(Icons.stop),
                          label: Text('Stop Test'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        
                        ElevatedButton.icon(
                          onPressed: _simulateTaskCompletion,
                          icon: Icon(Icons.star),
                          label: Text('Earn Time'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        
                        ElevatedButton.icon(
                          onPressed: () async {
                            await UnifiedScreenTimeService.resetScreenTimeToZero();
                            _addLog('🌀 Reset screen time to 0 minutes');

                            // Refresh stats to show updated screen time
                            final stats = await UnifiedScreenTimeService.getCurrentUsageStats();
                            setState(() {
                              _usageStats = stats;
                            });
                          },
                          icon: Icon(Icons.refresh),
                          label: Text('Reset to 0'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        
                        ElevatedButton.icon(
                          onPressed: _testNotificationSystem,
                          icon: Icon(Icons.notifications),
                          label: Text('Test Notification'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        
                        ElevatedButton.icon(
                          onPressed: _openUsageStatsSettings,
                          icon: Icon(Icons.settings),
                          label: Text('Open Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        
                        ElevatedButton.icon(
                          onPressed: _debugRealUsageStats,
                          icon: Icon(Icons.bug_report),
                          label: Text('Debug Stats'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Current Usage Stats
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Usage Stats',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (_usageStats.isEmpty)
                      Text('No usage data available')
                    else
                      ..._usageStats.entries.map((entry) {
                        final appName = entry.key;
                        final stats = entry.value;
                        final usedTime = ((stats['usedTime'] as num) / (1000 * 60)).round();
                        final remainingTime = ((stats['remainingTime'] as num) / (1000 * 60)).round();
                        final isBlocked = stats['isBlocked'] as bool;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isBlocked ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                            border: Border.all(
                              color: isBlocked ? Colors.red : Colors.green,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isBlocked ? Icons.block : Icons.check_circle,
                                color: isBlocked ? Colors.red : Colors.green,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appName,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text('Used: ${usedTime}m | Remaining: ${remainingTime}m'),
                                  ],
                                ),
                              ),
                              if (isBlocked)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'BLOCKED',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Logs
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Test Logs',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _testLogs.clear();
                            });
                          },
                          child: Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _testLogs.map((log) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              log,
                              style: TextStyle(
                                color: Colors.green,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
