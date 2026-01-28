import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'manage_children_screen.dart';
import 'screen_time_rules.dart';
import 'pin_setup_screen.dart';
import 'weekly_reports_screen.dart';
import '../services/weekly_report_service.dart';
import 'login_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String parentName;

  const ParentDashboardScreen({super.key, required this.parentName});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  Map<String, dynamic>? _screenTimeSettings;
  bool _showNotification = true;

  @override
  void initState() {
    super.initState();
    _initializeWeeklyReports();
  }

  Future<void> _initializeWeeklyReports() async {
    // Schedule weekly report notifications if not already scheduled
    try {
      await WeeklyReportService.scheduleWeeklyReportNotification();
    } catch (e) {
      print('Error initializing weekly reports: $e');
    }
  }

  // Handle the result from ScreenTimeRulesScreen
  void _handleScreenTimeSettings(Map<String, dynamic>? settings) {
    if (settings != null) {
      setState(() {
        _screenTimeSettings = settings;
      });

      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Screen time rules saved successfully!'),
          backgroundColor: kAccentBlue,
          duration: const Duration(seconds: 2),
        ),
      );
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
        title: const Text(
          'Parent Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
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
                        "IMPORTANT: Once you've added you children's profiles and set the screen time rules, join your child in downloading and logging into FocusPass on their devices with the username and passwords they've set up to select which apps you wan to prevent doomscrolling for and to set up their curated educational content content and let FocusPass do its thing!",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          height: 1.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showNotification = false;
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            if (_showNotification) const SizedBox(height: 16),
            Text(
              'Welcome, ${widget.parentName}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.person, color: kAccentBlue),
                      title: const Text('Manage Children'),
                      subtitle: const Text('Add or remove child profiles'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ManageChildrenScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.timer, color: kAccentBlue),
                      title: const Text('Set Screen Time Rules'),
                      subtitle: Text(_screenTimeSettings != null
                          ? 'Rules configured ✓'
                          : 'Define daily limits'),
                      trailing: _screenTimeSettings != null
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                          : null,
                      onTap: () async {
                        final result = await Navigator.push<Map<String, dynamic>>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ScreenTimeRulesScreen(),
                          ),
                        );
                        _handleScreenTimeSettings(result);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.bar_chart, color: kAccentBlue),
                      title: const Text('View Reports'),
                      subtitle: const Text('View weekly screen time and learning reports'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const WeeklyReportsScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.security, color: kAccentBlue),
                      title: const Text('Set Parental PIN'),
                      subtitle: const Text('Set up or change your PIN'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const PinSetupScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
