import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import 'create_account.dart';
import 'login_screen.dart';
import 'parent_dashboard.dart';
import 'child_dashboard_screen.dart';
import 'app_selection.dart';


class WelcomeScreen extends StatefulWidget {
  final bool autoLogin;
  const WelcomeScreen({super.key, this.autoLogin = true});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoLogin) {
      _checkAutoLogin();
    }
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    
    if (rememberMe) {
      final savedUsername = prefs.getString('saved_username') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';
      final isParent = prefs.getBool('is_parent') ?? false;
      final savedName = prefs.getString('saved_name') ?? '';
      
      if (savedUsername.isNotEmpty && savedPassword.isNotEmpty) {
        await _performAutoLogin(savedUsername, savedPassword, isParent, savedName);
      }
    }
  }

  Future<void> _performAutoLogin(String username, String password, bool isParent, String name) async {
    try {
      if (isParent) {
        // Parent auto-login
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: username,
          password: password,
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ParentDashboardScreen(parentName: name),
          ),
        );
      } else {
        // Child auto-login
        final query = await FirebaseFirestore.instance
            .collectionGroup('children')
            .where('username', isEqualTo: username)
            .where('password', isEqualTo: password)
            .get();

        if (query.docs.isNotEmpty) {
          final childDoc = query.docs.first;
          final childData = childDoc.data();
          final childName = childData['name'];
          final onboardingComplete = childData['onboardingComplete'] ?? false;

          if (onboardingComplete) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChildDashboardScreen(childName: childName),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AppSelectionScreen(childName: childName),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Auto-login failed, stay on welcome screen
      print('Auto-login failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAccentGreen,
      body: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              const SizedBox(height: 60), // Top padding

              // Centered Logo and Title
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FocusPass',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Image.asset(
                    'assets/images/logo.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ],
              ),

              // Buttons at the bottom
              // Buttons at the bottom
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateAccountScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Navigate to Log In screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}