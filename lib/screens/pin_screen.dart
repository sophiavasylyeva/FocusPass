
import 'package:flutter/material.dart';

class PinScreen extends StatefulWidget {
  final Function(String) onPinVerified;

  const PinScreen({Key? key, required this.onPinVerified}) : super(key: key);

  @override
  _PinScreenState createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _pinController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter PIN'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 5,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Parental PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                widget.onPinVerified(_pinController.text);
                Navigator.pop(context);
              },
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}

