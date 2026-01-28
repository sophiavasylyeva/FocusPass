import 'package:flutter/material.dart';
import '../screens/task_screen.dart';

class TaskCard extends StatelessWidget {
  final String taskTitle;

  TaskCard({required this.taskTitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: ListTile(
        title: Text(taskTitle),
        trailing: Icon(Icons.arrow_forward),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskScreen(taskTitle: taskTitle),
            ),
          );
        },
      ),
    );
  }
}
