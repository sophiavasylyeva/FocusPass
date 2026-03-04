import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/educational_task.dart';
import '../models/educational_question.dart';
import '../services/educational_task_service.dart';
import '../services/unified_screen_time_service.dart';
import '../utils/constants.dart';
import 'child_dashboard_screen.dart';

class QuizScreen extends StatefulWidget {
  final String childName;
  final List<EducationalTask> tasks;
  final VoidCallback onQuizCompleted;

  const QuizScreen({
    Key? key,
    required this.childName,
    required this.tasks,
    required this.onQuizCompleted,
  }) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  final EducationalTaskService _taskService = EducationalTaskService();
  
  List<EducationalQuestion> _questions = [];
  List<EducationalTask> _taskSources = [];
  int _currentQuestionIndex = 0;
  Map<int, int?> _selectedAnswers = {};
  Map<int, bool> _answeredQuestions = {};
  bool _showingResult = false;
  bool _quizComplete = false;
  bool _isLoading = false;
  int _correctCount = 0;
  bool _showCelebration = false;
  String _celebrationText = '';
  
  static const int passingScore = 4;
  static const int totalQuestions = 5;
  static const int screenTimeReward = 15;

  static const List<String> _celebrationMessages = [
    '🎉 Great job!',
    '⭐ Awesome!',
    '🌟 Brilliant!',
    '🏆 Nailed it!',
    '✨ Amazing!',
  ];

  late AnimationController _correctScaleController;
  late Animation<double> _correctScaleAnimation;
  late AnimationController _celebrationController;
  late Animation<double> _celebrationFadeAnimation;
  late Animation<double> _celebrationSlideAnimation;
  late AnimationController _sparkleController;
  late Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();

    _correctScaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _correctScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _correctScaleController, curve: Curves.easeInOut));

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _celebrationFadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_celebrationController);
    _celebrationSlideAnimation = Tween<double>(begin: 20.0, end: -10.0)
        .animate(CurvedAnimation(parent: _celebrationController, curve: Curves.easeOut));

    _sparkleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _sparkleAnimation = CurvedAnimation(parent: _sparkleController, curve: Curves.easeOut);

    _celebrationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showCelebration = false;
        });
      }
    });

    _initializeQuiz();
  }

  @override
  void dispose() {
    _correctScaleController.dispose();
    _celebrationController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  void _initializeQuiz() {
    _questions = [];
    _taskSources = [];
    
    for (int i = 0; i < widget.tasks.length && _questions.length < totalQuestions; i++) {
      final task = widget.tasks[i];
      if (task.questions.isNotEmpty) {
        _questions.add(task.questions.first);
        _taskSources.add(task);
      }
    }
    
    _currentQuestionIndex = 0;
    _selectedAnswers = {};
    _answeredQuestions = {};
    _showingResult = false;
    _quizComplete = false;
    _correctCount = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kAccentGreen,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Generating new questions...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_quizComplete) {
      return _buildResultsScreen();
    }

    return _buildQuestionScreen();
  }

  Widget _buildQuestionScreen() {
    final question = _questions[_currentQuestionIndex];
    final hasAnswered = _answeredQuestions[_currentQuestionIndex] ?? false;

    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: Text('Question ${_currentQuestionIndex + 1} of $totalQuestions'),
        backgroundColor: kDarkGreen,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: _showExitConfirmation,
        ),
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
      body: Stack(
        children: [
          Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalQuestions, (index) {
                Color dotColor;
                if (_answeredQuestions.containsKey(index)) {
                  final wasCorrect = _selectedAnswers[index] == _questions[index].correctAnswerIndex;
                  dotColor = wasCorrect ? Colors.green : Colors.red;
                } else if (index == _currentQuestionIndex) {
                  dotColor = Colors.white;
                } else {
                  dotColor = Colors.white.withOpacity(0.3);
                }
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
            SizedBox(height: 8),
            Text(
              'Score: $_correctCount / ${_answeredQuestions.length}',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAccentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      question.subject,
                      style: TextStyle(
                        color: kAccentGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    question.question,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            
            Expanded(
              child: ListView.builder(
                itemCount: question.options.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedAnswers[_currentQuestionIndex] == index;
                  Color backgroundColor = Colors.white;
                  Color textColor = Colors.black;
                  IconData? trailingIcon;
                  
                  if (hasAnswered) {
                    if (index == question.correctAnswerIndex) {
                      backgroundColor = Colors.green;
                      textColor = Colors.white;
                      trailingIcon = Icons.check_circle;
                    } else if (isSelected && index != question.correctAnswerIndex) {
                      backgroundColor = Colors.red;
                      textColor = Colors.white;
                      trailingIcon = Icons.cancel;
                    } else {
                      backgroundColor = Colors.grey.withOpacity(0.3);
                      textColor = Colors.grey;
                    }
                  } else if (isSelected) {
                    backgroundColor = kAccentGreen.withOpacity(0.2);
                  }
                  
                  final isCorrectAnswer = hasAnswered && index == question.correctAnswerIndex;
                  final answerButton = Container(
                    margin: EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      onPressed: hasAnswered ? null : () => _selectAnswer(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: backgroundColor,
                        foregroundColor: textColor,
                        disabledBackgroundColor: backgroundColor,
                        disabledForegroundColor: textColor,
                        padding: EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              question.options[index],
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          if (trailingIcon != null && isCorrectAnswer)
                            AnimatedBuilder(
                              animation: _sparkleAnimation,
                              builder: (context, child) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.rotate(
                                      angle: _sparkleAnimation.value * 0.5,
                                      child: Opacity(
                                        opacity: (1.0 - _sparkleAnimation.value * 0.3).clamp(0.0, 1.0),
                                        child: Icon(Icons.auto_awesome, color: Colors.yellowAccent, size: 18),
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(trailingIcon!, color: textColor),
                                    SizedBox(width: 4),
                                    Transform.rotate(
                                      angle: -_sparkleAnimation.value * 0.5,
                                      child: Opacity(
                                        opacity: (1.0 - _sparkleAnimation.value * 0.3).clamp(0.0, 1.0),
                                        child: Icon(Icons.star, color: Colors.yellowAccent, size: 16),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                          else if (trailingIcon != null)
                            Icon(trailingIcon!, color: textColor),
                        ],
                      ),
                    ),
                  );

                  if (isCorrectAnswer) {
                    return AnimatedBuilder(
                      animation: _correctScaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _correctScaleAnimation.value,
                          child: child,
                        );
                      },
                      child: answerButton,
                    );
                  }
                  return answerButton;
                },
              ),
            ),
            
            if (!hasAnswered)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextButton(
                  onPressed: _showExitConfirmation,
                  child: Text(
                    'Exit Quiz',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70,
                    ),
                  ),
                ),
              ),
            if (hasAnswered) ...[
              Builder(
                builder: (context) {
                  final selectedIndex = _selectedAnswers[_currentQuestionIndex];
                  final isCorrect = selectedIndex == question.correctAnswerIndex;
                  final borderColor = isCorrect ? Colors.green : Colors.red;
                  final bgColor = isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1);

                  return Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: borderColor,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              isCorrect ? 'Correct!' : 'Incorrect',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: borderColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        if (!isCorrect) ...[
                          Text(
                            'The correct answer is: ${question.options[question.correctAnswerIndex]}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'You selected: ${question.options[selectedIndex!]}',
                            style: TextStyle(
                              color: Colors.red[700],
                            ),
                          ),
                          SizedBox(height: 8),
                        ],
                        Text(
                          question.explanation,
                          style: TextStyle(color: Colors.blueGrey[700]),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kAccentGreen,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _currentQuestionIndex < totalQuestions - 1 ? 'Next Question' : 'See Results',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
          if (_showCelebration)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _celebrationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _celebrationFadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _celebrationSlideAnimation.value),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _celebrationText,
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(2, 2)),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (i) {
                                  final delay = i * 0.15;
                                  final progress = (_celebrationFadeAnimation.value - delay).clamp(0.0, 1.0);
                                  return Transform.translate(
                                    offset: Offset(0, -20 * progress),
                                    child: Opacity(
                                      opacity: progress,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(
                                          [Icons.star, Icons.auto_awesome, Icons.star, Icons.auto_awesome, Icons.star][i],
                                          color: [Colors.yellow, Colors.amber, Colors.orangeAccent, Colors.yellow, Colors.amber][i],
                                          size: 24 + (i % 2) * 8.0,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsScreen() {
    final passed = _correctCount >= passingScore;
    
    return Scaffold(
      backgroundColor: passed ? kAccentGreen : Colors.orange[700],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                passed ? Icons.celebration : Icons.refresh,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              Text(
                passed ? 'Great Job!' : 'Keep Trying!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Score: $_correctCount / $totalQuestions',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                passed
                    ? 'You passed! You earned $screenTimeReward minutes of screen time.'
                    : 'You need at least $passingScore correct answers to pass.\nLet\'s try again with new questions!',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalQuestions, (index) {
                  final wasCorrect = _selectedAnswers[index] == _questions[index].correctAnswerIndex;
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      wasCorrect ? Icons.check_circle : Icons.cancel,
                      color: wasCorrect ? Colors.green[300] : Colors.red[300],
                      size: 32,
                    ),
                  );
                }),
              ),
              SizedBox(height: 48),
              if (passed)
                ElevatedButton(
                  onPressed: () => _completeQuizSuccess(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kAccentGreen,
                    padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Claim Screen Time',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => _retryWithNewQuestions(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.orange[700],
                    padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Try 5 New Questions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exit Quiz?'),
        content: Text('Are you sure you want to exit? Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Exit'),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      Navigator.pop(context);
    }
  }

  void _selectAnswer(int answerIndex) {
    final question = _questions[_currentQuestionIndex];
    final isCorrect = answerIndex == question.correctAnswerIndex;
    
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = answerIndex;
      _answeredQuestions[_currentQuestionIndex] = true;
      if (isCorrect) {
        _correctCount++;
        _showCelebration = true;
        _celebrationText = _celebrationMessages[Random().nextInt(_celebrationMessages.length)];
        _correctScaleController.forward(from: 0.0);
        _celebrationController.forward(from: 0.0);
        _sparkleController.forward(from: 0.0);
      }
    });
  }

  void _handleNext() {
    if (_currentQuestionIndex < totalQuestions - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      setState(() {
        _quizComplete = true;
      });
    }
  }

  Future<void> _completeQuizSuccess() async {
    setState(() {
      _isLoading = true;
    });

    try {
      for (final task in _taskSources) {
        final completedTask = task.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );
        await _taskService.completeTask(completedTask);
      }

      await UnifiedScreenTimeService.setCurrentChildName(widget.childName);
      await UnifiedScreenTimeService.addEarnedTime(screenTimeReward.toDouble());
      
      widget.onQuizCompleted();
      Navigator.pop(context);
    } catch (e) {
      print('QuizScreen: Error completing quiz: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving progress. Please try again.')),
      );
    }
  }

  Future<void> _retryWithNewQuestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _taskService.clearAllTasks(widget.childName);
      
      final childData = await _getChildData();
      final subjects = List<String>.from(childData['subjectsOfInterest'] ?? ['Math']);
      final ageRange = childData['ageRange'] ?? '14-16';
      
      await _taskService.generateDailyTasks(widget.childName, subjects, ageRange);
      
      final newTasks = await _taskService.fetchTasks(widget.childName);
      final today = DateTime.now();
      final todaysTasks = newTasks.where((task) {
        return task.assignedAt.day == today.day &&
               task.assignedAt.month == today.month &&
               task.assignedAt.year == today.year &&
               !task.isCompleted;
      }).toList();

      setState(() {
        _questions = [];
        _taskSources = [];
        
        for (int i = 0; i < todaysTasks.length && _questions.length < totalQuestions; i++) {
          final task = todaysTasks[i];
          if (task.questions.isNotEmpty) {
            _questions.add(task.questions.first);
            _taskSources.add(task);
          }
        }
        
        _currentQuestionIndex = 0;
        _selectedAnswers = {};
        _answeredQuestions = {};
        _showingResult = false;
        _quizComplete = false;
        _correctCount = 0;
        _isLoading = false;
      });
    } catch (e) {
      print('QuizScreen: Error generating new questions: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating new questions. Please try again.')),
      );
    }
  }

  Future<Map<String, dynamic>> _getChildData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('children')
          .doc(widget.childName)
          .get();
      
      if (childDoc.exists) {
        return childDoc.data() ?? {};
      }
      return {};
    } catch (e) {
      print('QuizScreen: Error fetching child data: $e');
      return {};
    }
  }
}
