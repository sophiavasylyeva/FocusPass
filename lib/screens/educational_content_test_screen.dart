import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/educational_task.dart';
import '../models/educational_question.dart';
import '../services/educational_task_service.dart';
import '../utils/constants.dart';

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

  void _showAllTasksCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.celebration, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text(
                '🎉 Congratulations!',
                style: TextStyle(
                  color: kDarkGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Excellent work! You answered all questions correctly and completed 5 tasks.\n\n'
            'You have earned 15 minutes of screen time!\n\n'
            '5 new educational tasks are now available for your next session.',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                // The educational content test screen should already refresh and show "all tasks completed"
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
                'Awesome!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: Text('Educational Content Test', style: TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  // Tasks Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Complete 5 Tasks to Earn 15 Minutes',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          // Temporary debug button to clear all tasks
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  final allTasks = await _taskService.fetchTasks(widget.childName);
                                  print('=== DEBUG: All tasks for ${widget.childName} ===');
                                  for (final task in allTasks) {
                                    print('Task: ${task.id}, Subject: ${task.subject}, Completed: ${task.isCompleted}, AssignedAt: ${task.assignedAt}');
                                  }
                                  print('=== Total: ${allTasks.length} tasks ===');
                                },
                                child: Text('Debug', style: TextStyle(color: Colors.white70, fontSize: 10)),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await _taskService.clearAllTasks(widget.childName);
                                  await _refreshTasks();
                                },
                                child: Text('Clear', style: TextStyle(color: Colors.white70, fontSize: 10)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tasks remaining: ${_tasks.length}/5',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  SizedBox(height: 16),
                  
                  Expanded(
                    child: _tasks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 64),
                                SizedBox(height: 16),
                                Text(
                                  '🎉 All 5 tasks completed!',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'You earned 15 minutes of screen time!\n5 new tasks will be generated for your next session.',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _tasks.length,
                            itemBuilder: (context, index) {
                              final task = _tasks[index];
                              return Container(
                                margin: EdgeInsets.only(bottom: 12),
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: task.isCompleted ? Colors.green.withOpacity(0.2) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: task.isCompleted ? Border.all(color: Colors.green, width: 2) : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          task.isCompleted ? Icons.check_circle : Icons.book,
                                          color: task.isCompleted ? Colors.green : kAccentGreen,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${task.subject} Task',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: task.isCompleted ? Colors.green : Colors.black,
                                            ),
                                          ),
                                        ),
                                        if (task.isCompleted)
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'COMPLETED',
                                              style: TextStyle(color: Colors.white, fontSize: 10),
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '${task.questions.length} question${task.questions.length > 1 ? 's' : ''} • ${task.subject}',
                                      style: TextStyle(
                                        color: task.isCompleted ? Colors.green[700] : Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (!task.isCompleted) ...[
                                      SizedBox(height: 12),
                                      ElevatedButton(
                                        onPressed: () => _startTask(task),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kAccentGreen,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text('Start Task'),
                                      ),
                                    ] else ...[
                                      SizedBox(height: 8),
                                      Text(
                                        'Score: ${task.correctAnswersCount}/${task.questions.length} (${task.scorePercentage.toStringAsFixed(0)}%)',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  
                ],
              ),
            ),
    );
  }

  void _startTask(EducationalTask task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskQuestionScreen(
          task: task,
          onTaskCompleted: (completedTask, completedAllFiveTasks) => _onTaskCompleted(completedTask, completedAllFiveTasks),
        ),
      ),
    );
  }

  void _onTaskCompleted(EducationalTask completedTask, bool completedAllFiveTasks) async {
    await _refreshTasks();
    
    // Show in-app dialog if all 5 tasks are completed
    if (completedAllFiveTasks) {
      // Wait a moment for the UI to update, then show dialog
      Future.delayed(Duration(milliseconds: 300), () {
        _showAllTasksCompletedDialog();
      });
    }
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
      _tasks = todaysPendingTasks; // Only show the 5 pending tasks
      _isLoading = false;
    });
  }
}

class TaskQuestionScreen extends StatefulWidget {
  final EducationalTask task;
  final Function(EducationalTask, bool) onTaskCompleted;

  const TaskQuestionScreen({
    Key? key,
    required this.task,
    required this.onTaskCompleted,
  }) : super(key: key);

  @override
  State<TaskQuestionScreen> createState() => _TaskQuestionScreenState();
}

class _TaskQuestionScreenState extends State<TaskQuestionScreen> {
  int _currentQuestionIndex = 0;
  Map<String, bool> _answers = {};
  bool _showingResult = false;
  int? _selectedAnswer;
  bool _isGeneratingNewQuestion = false;

  @override
  Widget build(BuildContext context) {
    final question = widget.task.questions[_currentQuestionIndex];
    final isLastQuestion = _currentQuestionIndex == widget.task.questions.length - 1;

    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: Text('${widget.task.subject} Question ${_currentQuestionIndex + 1}/${widget.task.questions.length}'),
        backgroundColor: kDarkGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / widget.task.questions.length,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 24),
            
            // Question
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                question.question,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(height: 24),
            
            // Options
            Expanded(
              child: ListView.builder(
                itemCount: question.options.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedAnswer == index;
                  Color backgroundColor = Colors.white;
                  Color textColor = Colors.black;
                  
                  if (_showingResult && isSelected) {
                    backgroundColor = index == question.correctAnswerIndex ? Colors.green : Colors.red;
                    textColor = Colors.white;
                  } else if (_showingResult && index == question.correctAnswerIndex) {
                    backgroundColor = Colors.green;
                    textColor = Colors.white;
                  } else if (isSelected) {
                    backgroundColor = kAccentGreen.withOpacity(0.2);
                  }
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      onPressed: _showingResult ? null : () => _selectAnswer(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: backgroundColor,
                        foregroundColor: textColor,
                        padding: EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        question.options[index],
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Explanation (shown after answer)
            if (_showingResult) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explanation:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      question.explanation,
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
            
            // Next/Complete Button
            if (_showingResult)
              _isGeneratingNewQuestion
                  ? Container(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Generating new question...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () => _handleNextAction(isLastQuestion),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: kAccentGreen,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _getButtonText(isLastQuestion),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  void _selectAnswer(int index) {
    setState(() {
      _selectedAnswer = index;
      _showingResult = true;
    });

    final question = widget.task.questions[_currentQuestionIndex];
    final isCorrect = index == question.correctAnswerIndex;
    _answers[question.id] = isCorrect;

    // If answer is incorrect, we'll need to generate a new question
    if (!isCorrect) {
      print('TaskQuestionScreen: Incorrect answer for ${question.subject} question. Will generate new question.');
    }
  }

  void _nextQuestion() {
    setState(() {
      _currentQuestionIndex++;
      _selectedAnswer = null;
      _showingResult = false;
    });
  }

  String _getButtonText(bool isLastQuestion) {
    final currentQuestion = widget.task.questions[_currentQuestionIndex];
    final isCorrect = _selectedAnswer != null && _selectedAnswer == currentQuestion.correctAnswerIndex;
    
    if (!isCorrect) {
      return 'Try New Question';
    } else if (isLastQuestion) {
      return 'Complete Task';
    } else {
      return 'Next Question';
    }
  }

  Future<void> _handleNextAction(bool isLastQuestion) async {
    final currentQuestion = widget.task.questions[_currentQuestionIndex];
    final isCorrect = _selectedAnswer != null && _selectedAnswer == currentQuestion.correctAnswerIndex;
    
    if (!isCorrect) {
      // Generate a new similar question for the same subject
      await _generateNewSimilarQuestion();
    } else if (isLastQuestion) {
      // All questions answered correctly, complete the task
      await _completeTask();
    } else {
      // Move to next question
      _nextQuestion();
    }
  }

  Future<void> _generateNewSimilarQuestion() async {
    setState(() {
      _isGeneratingNewQuestion = true;
    });

    try {
      final currentQuestion = widget.task.questions[_currentQuestionIndex];
      // Get the child's age range from the database
      final childData = await _getChildDataForTask();
      final ageRange = childData['ageRange'] ?? '14-16';
      
      final newQuestion = await EducationalTaskService().generateSimilarQuestion(
        currentQuestion.subject, 
        ageRange,
        _currentQuestionIndex
      );

      setState(() {
        // Replace current question with new one
        final oldQuestion = widget.task.questions[_currentQuestionIndex];
        widget.task.questions[_currentQuestionIndex] = newQuestion;
        
        // Remove the old incorrect answer from the answers map
        _answers.remove(oldQuestion.id);
        
        _selectedAnswer = null;
        _showingResult = false;
        _isGeneratingNewQuestion = false;
      });

      print('TaskQuestionScreen: Generated new ${currentQuestion.subject} question');
    } catch (e) {
      print('TaskQuestionScreen: Error generating new question: $e');
      setState(() {
        _isGeneratingNewQuestion = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating new question. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _getChildDataForTask() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('TaskQuestionScreen: No user logged in');
        return {};
      }

      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(widget.task.childName)
          .get();
      
      if (childDoc.exists) {
        return childDoc.data() ?? {};
      } else {
        print('TaskQuestionScreen: No child data found for ${widget.task.childName}');
        return {};
      }
    } catch (e) {
      print('TaskQuestionScreen: Error fetching child data: $e');
      return {};
    }
  }

  Future<void> _completeTask() async {
    // Verify all current questions have been answered correctly
    final currentQuestionIds = widget.task.questions.map((q) => q.id).toSet();
    final answeredCorrectly = currentQuestionIds.where((questionId) => 
      _answers[questionId] == true
    ).length;
    
    print('TaskQuestionScreen: Checking completion - ${answeredCorrectly}/${currentQuestionIds.length} questions answered correctly');
    print('TaskQuestionScreen: Current answers: $_answers');
    print('TaskQuestionScreen: Current question IDs: $currentQuestionIds');
    
    if (answeredCorrectly < currentQuestionIds.length) {
      print('TaskQuestionScreen: Cannot complete task - not all questions answered correctly');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All questions must be answered correctly to complete the task.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final completedTask = widget.task.copyWith(
      questionAnswers: _answers,
      isCompleted: true,
      completedAt: DateTime.now(),
    );

    final completedAllFiveTasks = await EducationalTaskService().completeTask(completedTask);
    
    widget.onTaskCompleted(completedTask, completedAllFiveTasks);
    Navigator.pop(context);
  }
}
