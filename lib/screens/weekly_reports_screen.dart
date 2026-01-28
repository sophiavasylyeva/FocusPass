import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../services/weekly_report_service.dart';

class WeeklyReportsScreen extends StatefulWidget {
  const WeeklyReportsScreen({super.key});

  @override
  State<WeeklyReportsScreen> createState() => _WeeklyReportsScreenState();
}

class _WeeklyReportsScreenState extends State<WeeklyReportsScreen> {
  List<String> _children = [];
  String? _selectedChild;
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final childrenQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .get();

      setState(() {
        _children = childrenQuery.docs
            .map((doc) => doc.data()['name'] as String)
            .toList();
        if (_children.isNotEmpty) {
          _selectedChild = _children.first;
          _loadReports();
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      print('Error loading children: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReports() async {
    if (_selectedChild == null) return;

    setState(() {
      _isLoading = true;
    });

    final reports = await WeeklyReportService.getChildReports(_selectedChild!);
    
    setState(() {
      _reports = reports;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: const Text(
          'Weekly Reports',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : _children.isEmpty
              ? const Center(
                  child: Text(
                    'No children found.\nAdd children in the Parent Dashboard first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Child selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedChild,
                          isExpanded: true,
                          underline: const SizedBox(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedChild = newValue;
                            });
                            _loadReports();
                          },
                          items: _children.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Reports list
                      Expanded(
                        child: _reports.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.bar_chart,
                                      size: 64,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No reports available yet',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Reports are automatically generated weekly on Fridays at 9 PM\nafter your child has used the app for a week',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _reports.length,
                                itemBuilder: (context, index) {
                                  final report = _reports[index];
                                  return _buildReportCard(report);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final weekStart = DateTime.parse(report['weekStart']);
    final weekEnd = DateTime.parse(report['weekEnd']);
    final averageScreenTime = (report['averageScreenTime'] ?? 0.0).toDouble();
    final totalScreenTime = (report['totalScreenTime'] ?? 0.0).toDouble();
    final appUsage = report['appUsage'] as List<dynamic>? ?? [];
    final learningTopics = report['learningTopics'] as List<dynamic>? ?? [];
    final daysActive = report['daysActive'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kAccentBlue,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kMintGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$daysActive day${daysActive == 1 ? '' : 's'} active',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Screen time summary
            _buildSectionHeader('📱 Screen Time Summary'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Daily Average',
                    '${averageScreenTime.toStringAsFixed(0)} min',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Weekly Total',
                    '${totalScreenTime.toStringAsFixed(0)} min',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top apps
            if (appUsage.isNotEmpty) ...[
              _buildSectionHeader('🏆 Most Used Apps'),
              const SizedBox(height: 8),
              ...appUsage.take(3).map((app) => _buildAppUsageItem(app)),
              const SizedBox(height: 16),
            ],

            // Learning topics
            if (learningTopics.isNotEmpty) ...[
              _buildSectionHeader('🎓 Learning Topics'),
              const SizedBox(height: 8),
              ...learningTopics.take(3).map((topic) => _buildLearningTopicItem(topic)),
            ],

            if (appUsage.isEmpty && learningTopics.isEmpty) ...[
              const Center(
                child: Text(
                  'No activity data available for this week',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppUsageItem(Map<String, dynamic> app) {
    final appName = app['appName'] ?? 'Unknown';
    final totalMinutes = app['totalUsageMinutes'] ?? 0;
    final avgMinutes = app['averageUsageMinutes'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              appName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${totalMinutes}m total',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${avgMinutes}m/day',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLearningTopicItem(Map<String, dynamic> topic) {
    final subject = topic['subject'] ?? 'Unknown';
    final questionsAnswered = topic['questionsAnswered'] ?? 0;
    final accuracy = (topic['accuracy'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$questionsAnswered questions',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accuracy >= 80 ? Colors.green : accuracy >= 60 ? Colors.orange : Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${accuracy.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}