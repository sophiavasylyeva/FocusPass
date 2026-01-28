
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import 'parent_dashboard.dart';

class ParentSetupScreen extends StatefulWidget {
  final String parentUid;

  const ParentSetupScreen({Key? key, required this.parentUid}) : super(key: key);

  @override
  _ParentSetupScreenState createState() => _ParentSetupScreenState();
}

class _ParentSetupScreenState extends State<ParentSetupScreen> {
  final _pinController = TextEditingController();


  Future<void> _finishSetup() async {
    if (_pinController.text.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be exactly 5 digits')),
      );
      return;
    }

    final parentRef = FirebaseFirestore.instance.collection('users').doc(widget.parentUid);

    // Save PIN and mark setup as complete
    await parentRef.update({
      'pin': _pinController.text,
      'setupComplete': true,
    });

    final parentDoc = await parentRef.get();
    final parentName = parentDoc.data()?['name'] ?? 'Parent';

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ParentDashboardScreen(parentName: parentName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      body: _buildPinPage(),
    );
  }


  Widget _buildPinPage() {
    return _buildSetupCard(
      title: 'Set Parental PIN',
      subtitle: 'Create a 5-digit PIN to access parent settings and override limits.',
      content: TextField(
        controller: _pinController,
        keyboardType: TextInputType.number,
        maxLength: 5,
        decoration: const InputDecoration(
          hintText: 'Enter 5-digit PIN',
          fillColor: Colors.white,
          filled: true,
        ),
      ),
      onContinue: _finishSetup,
      continueText: 'Finish Setup',
    );
  }

  Widget _buildSetupCard({
    required String title,
    required String subtitle,
    required Widget content,
    required VoidCallback onContinue,
    String continueText = 'Continue',
  }) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Expanded(child: content),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onContinue,
                child: Text(continueText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

