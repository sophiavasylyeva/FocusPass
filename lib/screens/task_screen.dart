import 'package:flutter/material.dart';
import '../services/unified_screen_time_service.dart';
import '../utils/constants.dart';

class TaskScreen extends StatefulWidget {
  final String taskTitle;

  const TaskScreen({super.key, required this.taskTitle});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  bool _isCompleted = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      appBar: AppBar(
        title: Text(widget.taskTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: kDarkGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isCompleted ? Icons.check_circle : Icons.assignment,
                      size: 80,
                      color: _isCompleted ? kAccentGreen : Colors.grey,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.taskTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (!_isCompleted) ...
                      [
                        const Text(
                          'Complete this learning task to earn 15 minutes of screen time!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Task Instructions:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kAccentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _getTaskInstructions(),
                        ),
                      ]
                    else ...
                      [
                        const Text(
                          '🎉 Task Completed!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'You earned 15 minutes of screen time!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!_isCompleted)
              ElevatedButton(
                onPressed: _isLoading ? null : _completeTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Mark as Complete',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              )
            else
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Dashboard',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getTaskInstructions() {
    // Simple task instructions based on task title
    String instructions;
    if (widget.taskTitle.toLowerCase().contains('math')) {
      instructions = '• Solve 5 math problems\n• Show your work\n• Check your answers';
    } else if (widget.taskTitle.toLowerCase().contains('reading')) {
      instructions = '• Read for 10 minutes\n• Summarize what you read\n• Discuss with a parent';
    } else if (widget.taskTitle.toLowerCase().contains('science')) {
      instructions = '• Complete science worksheet\n• Conduct a simple experiment\n• Record your observations';
    } else {
      instructions = '• Complete the assigned activity\n• Take notes if needed\n• Ask questions if confused';
    }

    return Text(
      instructions,
      style: const TextStyle(
        fontSize: 14,
        height: 1.5,
      ),
    );
  }

  Future<void> _completeTask() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Add earned screen time (15 minutes)
      await UnifiedScreenTimeService.addEarnedTime(15.0);
      
      setState(() {
        _isCompleted = true;
        _isLoading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Task completed! You earned 15 minutes of screen time!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
