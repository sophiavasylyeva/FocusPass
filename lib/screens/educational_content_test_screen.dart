import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/educational_task.dart';
import '../services/educational_task_service.dart';
import '../utils/constants.dart';
import 'quiz_screen.dart';
import 'child_dashboard_screen.dart';

class EducationalContentTestScreen extends StatefulWidget {
  final String childName;

  const EducationalContentTestScreen({Key? key, required this.childName}) : super(key: key);

  @override
  State<EducationalContentTestScreen> createState() => _EducationalContentTestScreenState();
}

class _EducationalContentTestScreenState extends State<EducationalContentTestScreen> {
  final EducationalTaskService _taskService = EducationalTaskService();
  List<EducationalTask> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeTasks();
  }

  Future<void> _initializeTasks() async {
    // First, check if we already have tasks for today
    final existingTasks = await _taskService.fetchTasks(widget.childName);
    final today = DateTime.now();
    
    final existingTodayTasks = existingTasks.where((task) {
      return task.assignedAt.day == today.day &&
             task.assignedAt.month == today.month &&
             task.assignedAt.year == today.year;
    }).toList();
    
    print('EducationalContentTestScreen: Found ${existingTodayTasks.length} existing tasks for today');
    
    // Only generate tasks if we don't have any for today
    if (existingTodayTasks.isEmpty) {
      print('EducationalContentTestScreen: No tasks found for today, generating new tasks');
      
      // Get child's actual selected subjects and age range from database
      final childData = await _getChildData(widget.childName);
      final subjects = childData['subjectsOfInterest'] ?? ['Math'];
      final ageRange = childData['ageRange'] ?? '14-16';
      
      print('EducationalContentTestScreen: Generating tasks for ${widget.childName} with subjects: $subjects');
      
      // Generate new daily tasks using child's actual preferences
      await _taskService.generateDailyTasks(widget.childName, List<String>.from(subjects), ageRange);
    } else {
      print('EducationalContentTestScreen: Using existing ${existingTodayTasks.length} tasks for today');
    }
    
    // Fetch only today's pending tasks (the 5 tasks that need to be completed)
    final allTasks = await _taskService.fetchTasks(widget.childName);
    
    // Filter to show only today's tasks that are not completed
    final todaysPendingTasks = allTasks.where((task) {
      final isToday = task.assignedAt.day == today.day &&
                      task.assignedAt.month == today.month &&
                      task.assignedAt.year == today.year;
      final isNotCompleted = !task.isCompleted;
      
      print('EducationalContentTestScreen: Task ${task.id} - isToday: $isToday, isNotCompleted: $isNotCompleted, assignedAt: ${task.assignedAt}');
      
      return isToday && isNotCompleted;
    }).toList();
    
    print('EducationalContentTestScreen: Filtered to ${todaysPendingTasks.length} pending tasks for today');
    
    setState(() {
      _tasks = todaysPendingTasks; // Only show the 5 pending tasks
      _isLoading = false;
    });
  }

  Future<Map<String, dynamic>> _getChildData(String childName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('EducationalContentTestScreen: No user logged in');
        return {};
      }

      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(childName)
          .get();
      
      if (childDoc.exists) {
        final data = childDoc.data() ?? {};
        print('EducationalContentTestScreen: Found child data for $childName: $data');
        return data;
      } else {
        print('EducationalContentTestScreen: No child data found for $childName');
        return {};
      }
    } catch (e) {
      print('EducationalContentTestScreen: Error fetching child data: $e');
      return {};
    }
  }

  void _startQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          childName: widget.childName,
          tasks: _tasks,
          onQuizCompleted: () {
            _refreshTasks();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: Text('Educational Tasks', style: TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Back to Dashboard',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => ChildDashboardScreen(childName: widget.childName),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_tasks.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 80),
                            SizedBox(height: 24),
                            Text(
                              'All Done!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'You earned 15 minutes of screen time!',
                              style: TextStyle(color: Colors.white, fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'New questions will be available for your next session.',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: kAccentGreen,
                                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              ),
                              child: Text('Back to Dashboard', style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.quiz, color: Colors.white, size: 80),
                          SizedBox(height: 24),
                          Text(
                            'Ready to Earn Screen Time?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow(Icons.help_outline, '5 questions to answer'),
                                SizedBox(height: 12),
                                _buildInfoRow(Icons.check_circle_outline, 'Get 4 or more correct to pass'),
                                SizedBox(height: 12),
                                _buildInfoRow(Icons.timer, 'Earn 15 minutes of screen time'),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Subjects: ${_tasks.map((t) => t.subject).toSet().join(", ")}',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _startQuiz,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: kAccentGreen,
                              padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              'Start Quiz',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }

  Future<void> _refreshTasks() async {
    setState(() {
      _isLoading = true;
    });
    
    // Fetch only today's pending tasks (the 5 tasks that need to be completed)
    final allTasks = await _taskService.fetchTasks(widget.childName);
    final today = DateTime.now();
    
    // Filter to show only today's tasks that are not completed
    final todaysPendingTasks = allTasks.where((task) {
      return task.assignedAt.day == today.day &&
             task.assignedAt.month == today.month &&
             task.assignedAt.year == today.year &&
             !task.isCompleted;
    }).toList();
    
    print('EducationalContentTestScreen: _refreshTasks found ${todaysPendingTasks.length} pending tasks');
    for (final task in todaysPendingTasks) {
      print('  - Task: ${task.subject} (${task.questions.length} questions)');
    }
    
    setState(() {
      _tasks = todaysPendingTasks;
      _isLoading = false;
    });
  }
}
