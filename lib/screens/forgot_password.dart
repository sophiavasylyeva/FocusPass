import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import 'login_screen.dart';

import 'welcome_screen.dart';

String? validateResetEmail(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Please enter your email address';
  }
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailPattern.hasMatch(trimmed)) {
    return 'Please enter a valid email address';
  }
  return null;
}


const String kPasswordResetPrivacySafeMessage =
    'If an account exists for this email, a password reset link has been sent.';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _handleSendResetLink() async {
    if (_isSubmitting) return; // guard against double submission
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final email = _emailController.text.trim();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showPrivacySafeSuccess();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _showPrivacySafeSuccess();
          break;
        case 'invalid-email':
          _showMessage('Please enter a valid email address.');
          break;
        case 'too-many-requests':
          _showMessage('Too many requests. Please wait and try again.');
          break;
        default:
          print(
            '❌ ForgotPassword: sendPasswordResetEmail failed, code=${e.code}',
          );
          _showMessage('Something went wrong. Please try again.');
      }
    } catch (e) {
      print('❌ ForgotPassword: unexpected error: $e');
      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showPrivacySafeSuccess() =>
      _showMessage(kPasswordResetPrivacySafeMessage);

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Forgot Password?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Enter your email and we'll send you a link to reset\nyour password",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Email Address',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isSubmitting,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'parent@example.com',
                    hintStyle: TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  validator: validateResetEmail,
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSendResetLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Send Reset Link',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),

                const SizedBox(height: 16),

                OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 16),

                TextButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const WelcomeScreen(autoLogin: false),
                            ),
                          );
                        },
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text(
                    'Back to Welcome',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
