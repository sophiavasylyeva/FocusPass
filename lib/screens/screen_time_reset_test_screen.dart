import 'package:flutter/material.dart';
import '../services/unified_screen_time_service.dart';

class ScreenTimeResetTestScreen extends StatefulWidget {
  const ScreenTimeResetTestScreen({Key? key}) : super(key: key);

  @override
  State<ScreenTimeResetTestScreen> createState() => _ScreenTimeResetTestScreenState();
}

class _ScreenTimeResetTestScreenState extends State<ScreenTimeResetTestScreen> {
  Map<String, dynamic> _usageStats = {};
  bool _isLoading = false;
  String _statusMessage = '';
  bool _showDebugInfo = false;

  @override
  void initState() {
    super.initState();
    _loadUsageStats();
  }

  Future<void> _loadUsageStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await UnifiedScreenTimeService.getCurrentUsageStats();
      setState(() {
        _usageStats = stats;
        _statusMessage = 'Usage stats loaded successfully';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error loading usage stats: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _performDailyReset() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Performing daily reset...';
    });

    try {
      await UnifiedScreenTimeService.performDailyReset();
      setState(() {
        _statusMessage = 'Daily reset completed successfully!';
        _usageStats.clear(); // Clear the displayed stats
      });
      
      // Reload stats to show the reset
      await Future.delayed(const Duration(seconds: 1));
      await _loadUsageStats();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error performing daily reset: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _forceCompleteReset() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Performing complete force reset...';
    });

    try {
      await UnifiedScreenTimeService.forceCompleteReset();
      setState(() {
        _statusMessage = 'Complete force reset completed! All screen time data has been cleared.';
        _usageStats.clear(); // Clear the displayed stats
      });
      
      // Reload stats to show the reset
      await Future.delayed(const Duration(seconds: 1));
      await _loadUsageStats();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error performing force reset: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTime(dynamic milliseconds) {
    if (milliseconds == null || milliseconds == 0) return '0m';
    
    final ms = milliseconds is int ? milliseconds : (milliseconds as double).toInt();
    final minutes = (ms / (1000 * 60)).round();
    
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      return remainingMinutes > 0 ? '${hours}h ${remainingMinutes}m' : '${hours}h';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Time Reset Test'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage.isEmpty ? 'Ready to test daily reset functionality' : _statusMessage,
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action buttons
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _loadUsageStats,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload Stats'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _performDailyReset,
                        icon: const Icon(Icons.restore),
                        label: const Text('Reset Daily'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _forceCompleteReset,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('FORCE COMPLETE RESET (Fix Stuck Data)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () {
                      setState(() {
                        _showDebugInfo = !_showDebugInfo;
                      });
                    },
                    icon: Icon(_showDebugInfo ? Icons.visibility_off : Icons.visibility),
                    label: Text(_showDebugInfo ? 'Hide Debug Info' : 'Show Debug Info'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Debug information
            if (_showDebugInfo) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  border: Border.all(color: Colors.purple[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Information',
                      style: TextStyle(
                        color: Colors.purple[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current Date: ${DateTime.now().toIso8601String().split('T')[0]}',
                      style: TextStyle(color: Colors.purple[700], fontSize: 12),
                    ),
                    Text(
                      'Current Time: ${DateTime.now().toIso8601String().split('T')[1].split('.')[0]}',
                      style: TextStyle(color: Colors.purple[700], fontSize: 12),
                    ),
                    Text(
                      'Apps Found: ${_usageStats.length}',
                      style: TextStyle(color: Colors.purple[700], fontSize: 12),
                    ),
                    if (_usageStats.isNotEmpty)
                      ...[
                        const SizedBox(height: 4),
                        Text(
                          'Raw Data:',
                          style: TextStyle(color: Colors.purple[800], fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        ..._usageStats.entries.map((entry) => 
                          Text(
                            '${entry.key}: ${entry.value}',
                            style: TextStyle(color: Colors.purple[600], fontSize: 10, fontFamily: 'monospace'),
                          )
                        ),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Loading indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            
            // Usage stats display
            if (!_isLoading && _usageStats.isNotEmpty) ...[
              Text(
                'Current Screen Time Usage',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _usageStats.length,
                  itemBuilder: (context, index) {
                    final appName = _usageStats.keys.elementAt(index);
                    final appData = _usageStats[appName];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  appName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: appData['isBlocked'] == true 
                                        ? Colors.red[100] 
                                        : Colors.green[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    appData['isBlocked'] == true ? 'BLOCKED' : 'ACTIVE',
                                    style: TextStyle(
                                      color: appData['isBlocked'] == true 
                                          ? Colors.red[800] 
                                          : Colors.green[800],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Used Today', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(
                                      _formatTime(appData['usedTime']),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Remaining', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(
                                      _formatTime(appData['remainingTime']),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: appData['isBlocked'] == true ? Colors.red : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Daily Limit: ${_formatTime(appData['dailyLimit'])}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  'Earned: ${_formatTime(appData['earnedTime'])}',
                                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            // Empty state
            if (!_isLoading && _usageStats.isEmpty) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.phone_android,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No usage data available',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use some restricted apps first, then reload stats',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
