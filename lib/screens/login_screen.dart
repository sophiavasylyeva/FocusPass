import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'parent_dashboard.dart';
import 'child_dashboard_screen.dart';
import 'parent_setup_screen.dart';
import 'app_selection.dart';
import 'welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;

  void _handleLogin() async {
    final input = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (input.contains('@')) {
      // Parent login
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: input,
          password: password,
        );
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final parentName = doc['name'] ?? 'Parent';

        // Save credentials if remember me is checked
        if (_rememberMe) {
          await _saveLoginCredentials(input, password, true, parentName);
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ParentDashboardScreen(parentName: parentName),
          ),
        );
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.message}')),
        );
      }
    } else {
      // Child login
      try {
        final query = await FirebaseFirestore.instance
            .collectionGroup('children')
            .where('username', isEqualTo: input)
            .where('password', isEqualTo: password)
            .get();

        if (query.docs.isNotEmpty) {
          final childDoc = query.docs.first;
        final childData = childDoc.data();
        final childName = childData['name'];
        final onboardingComplete = childData['onboardingComplete'] ?? false;

        // Save credentials if remember me is checked
        if (_rememberMe) {
          await _saveLoginCredentials(input, password, false, childName);
        }

        if (onboardingComplete) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChildDashboardScreen(childName: childName),
            ),
          );
        } else {
          // Start with app selection for new child accounts
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AppSelectionScreen(childName: childName),
            ),
          );
        }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid username or password')),
          );
        }
      } catch (e) {
        print('❌ Firestore login failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed. ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveLoginCredentials(String username, String password, bool isParent, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_username', username);
    await prefs.setString('saved_password', password);
    await prefs.setBool('is_parent', isParent);
    await prefs.setString('saved_name', name);
    await prefs.setBool('remember_me', true);
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    
    if (rememberMe) {
      final savedUsername = prefs.getString('saved_username') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';
      
      setState(() {
        _emailController.text = savedUsername;
        _passwordController.text = savedPassword;
        _rememberMe = rememberMe;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48, // Account for padding
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                const Text('Welcome Back!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Log in to your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white70)),
                const SizedBox(height: 24),
                const Text('Email / Child Username',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Enter your email or child username',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) =>
                  value == null || value.trim().length < 3 ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const Text('Password',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Enter your password',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) =>
                  value == null || value.trim().length < 6 ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                      activeColor: kAccentBlue,
                      checkColor: Colors.white,
                    ),
                    const Text(
                      'Remember me',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _handleLogin();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    'Back to Home',
                    style: TextStyle(color: Colors.white),
                  ),
                      ),
                    ],
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
