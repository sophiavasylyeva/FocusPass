import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../models/child_session.dart';
import '../services/child_session_service.dart';
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
   
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final tokenResult = await currentUser.getIdTokenResult(true);
        if (tokenResult.claims?['role'] == 'child') {
          
          await _tryAuthenticatedChildAutoLogin(
            currentUser,
            tokenResult.claims!,
          );
          return;
        }
        
      } catch (e) {
        
        print(
          '⚠️ WelcomeScreen: could not read auth claims for auto-login: $e',
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe) {
      final savedUsername = prefs.getString('saved_username') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';
      final isParent = prefs.getBool('is_parent') ?? false;
      final savedName = prefs.getString('saved_name') ?? '';

      if (savedUsername.isNotEmpty && savedPassword.isNotEmpty) {
        await _performAutoLogin(
          savedUsername,
          savedPassword,
          isParent,
          savedName,
        );
      }
    }
  }

 
  Future<void> _tryAuthenticatedChildAutoLogin(
    User currentUser,
    Map<String, dynamic> claims,
  ) async {
    try {
      final established =
          await ChildSessionService.establishFromAuthenticatedUser(
            currentUser: currentUser,
            claims: claims,
          );

      // Non-sensitive development metadata only.
      print(
        '✅ WelcomeScreen: authenticated child auto-login, childId=${established.session.childId}',
      );

      if (!mounted) return;
      if (established.onboardingComplete) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChildDashboardScreen(
              childName: established.session.displayName,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AppSelectionScreen(childName: established.session.displayName),
          ),
        );
      }
    } catch (e) {
      print('❌ WelcomeScreen: authenticated child auto-login failed: $e');
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
      await ChildSessionService.clearSession();
    }
  }

  Future<void> _performAutoLogin(
    String username,
    String password,
    bool isParent,
    String name,
  ) async {
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
        
        final restored = await ChildSessionService.restoreSession();

        if (restored != null) {
          final childDoc = await restored.childRef().get();

          if (!childDoc.exists) {
          
            await ChildSessionService.clearSession();
          } else {
            final session = ChildSession.fromDocument(childDoc);
            ChildSessionService.setSession(session);
            await ChildSessionService.persistSession(session);
            final onboardingComplete =
                childDoc.data()?['onboardingComplete'] ?? false;

            if (!mounted) return;
            if (onboardingComplete) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ChildDashboardScreen(childName: session.displayName),
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AppSelectionScreen(childName: session.displayName),
                ),
              );
            }
            return;
          }
        }

        
        final query = await FirebaseFirestore.instance
            .collectionGroup('children')
            .where('username', isEqualTo: username)
            .where('password', isEqualTo: password)
            .get();

        if (query.docs.length == 1) {
          final childDoc = query.docs.single;
          final session = ChildSession.fromDocument(childDoc);
          ChildSessionService.setSession(session);
          await ChildSessionService.persistSession(session);
          final onboardingComplete =
              childDoc.data()['onboardingComplete'] ?? false;

          if (!mounted) return;
          if (onboardingComplete) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ChildDashboardScreen(childName: session.displayName),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AppSelectionScreen(childName: session.displayName),
              ),
            );
          }
        } else if (query.docs.length > 1) {
       
          print(
            '❌ WelcomeScreen: auto-login matched ${query.docs.length} child '
            'documents for username "$username" — refusing to pick one '
            'arbitrarily.',
          );
        }
        // 0 matches: stay on welcome screen silently (unchanged behavior).
      }
    } catch (e) {
      // Auto-login failed, stay on welcome screen
      print('Auto-login failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A7B1E),
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
                  Image.asset(
                    'assets/images/logo.png',
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ],
              ),

              Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateAccountScreen(),
                        ),
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
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
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
