
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'welcome_screen.dart';
import 'login_screen.dart';
import 'parent_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_selection.dart';
import 'child_age.dart';
import 'parent_setup_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _childController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final List<String> _children = [];

  void _addChild() {
    final name = _childController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _children.add(name);
        _childController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Set up FocusPass for your family',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 24),

                        const Text("Parent's Name",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.black),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Your name',
                            hintStyle: TextStyle(color: Colors.grey),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        const Text('Email',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.black),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'parent@example.com',
                            hintStyle: TextStyle(color: Colors.grey),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 3) {
                              return 'Email must be at least 3 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        const Text('Password',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.black),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Create a password',
                            hintStyle: TextStyle(color: Colors.grey),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              try {
                                final authResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                  email: _emailController.text.trim(),
                                  password: _passwordController.text.trim(),
                                );

                                final uid = authResult.user?.uid;

                                if (uid != null) {
                                  await FirebaseFirestore.instance.collection('users').doc(uid).set({
                                    'email': _emailController.text.trim(),
                                    'name': _nameController.text.trim(),
                                    'role': 'parent',
                                    'setupComplete': true, // Complete setup immediately
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ParentDashboardScreen(parentName: _nameController.text.trim()),
                                    ),
                                  );
                                }


                              } on FirebaseAuthException catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Account creation failed: ${e.message}')),
                                );
                              }
                            }
                          },

                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccentBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'Already have an account?',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                            'Log In',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),

                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const WelcomeScreen(autoLogin: false)),
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
          },
        ),
      ),
    );
  }
}
