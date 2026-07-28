import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/child_session.dart';
import '../services/child_auth_service.dart';
import '../services/child_session_service.dart';
import 'parent_dashboard.dart';
import 'child_dashboard_screen.dart';
import 'app_selection.dart';
import 'welcome_screen.dart';

enum _LoginMode { parent, child }

bool shouldUseSecureChildLogin(String familyCodeInput) =>
    familyCodeInput.trim().isNotEmpty;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, ChildAuthService? childAuthService})
    : _childAuthService = childAuthService;

  final ChildAuthService? _childAuthService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _familyCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  _LoginMode _mode = _LoginMode.parent;

  late final ChildAuthService _childAuthService =
      widget._childAuthService ?? ChildAuthService();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }
  Future<void> _handleLogin() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await ChildSessionService.clearSession();
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }

      if (_mode == _LoginMode.parent) {
        await _handleParentLogin();
      } else {
        final familyCode = _familyCodeController.text.trim();
        if (shouldUseSecureChildLogin(familyCode)) {
          await _handleSecureChildLogin(familyCode: familyCode);
        } else {
          await _handleLegacyChildLogin();
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleParentLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final parentName = doc['name'] ?? 'Parent';

      if (_rememberMe) {
        await _saveLoginCredentials(email, password, true, parentName);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ParentDashboardScreen(parentName: parentName),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: ${e.message}')));
    }
  }

  Future<void> _handleSecureChildLogin({required String familyCode}) async {
    final username = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final loginResult = await _childAuthService.loginChild(
        familyCode: familyCode,
        username: username,
        password: password,
      );

      await FirebaseAuth.instance.signInWithCustomToken(
        loginResult.customToken,
      );
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw ChildAuthException.signInFailed();
      }

      final tokenResult = await currentUser.getIdTokenResult(true);

      final established =
          await ChildSessionService.establishFromAuthenticatedUser(
            currentUser: currentUser,
            claims: tokenResult.claims,
            expectedParentUid: loginResult.parentUid,
            expectedChildId: loginResult.childId,
          );

      // Non-sensitive development metadata only — never the family code,
      // username, password, custom token, or ID token.
      print(
        '✅ LoginScreen: secure child login succeeded, childId=${established.session.childId}',
      );

      if (!mounted) return;
      _navigateAfterChildLogin(
        established.session,
        established.onboardingComplete,
      );
    } on ChildAuthException catch (e) {
      print('❌ LoginScreen: secure child login failed, code=${e.code}');
      await _abortChildAuthSession();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } on FirebaseAuthException catch (e) {
      print('❌ LoginScreen: signInWithCustomToken failed, code=${e.code}');
      await _abortChildAuthSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ChildAuthException.signInFailed().message)),
      );
    } on ChildAuthClaimsException catch (e) {
      print('❌ LoginScreen: child claims validation failed: ${e.message}');
      await _abortChildAuthSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ChildAuthException.signInFailed().message)),
      );
    } on ChildSessionValidationException catch (e) {
      print('❌ LoginScreen: child session validation failed: ${e.message}');
      await _abortChildAuthSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ChildAuthException.signInFailed().message)),
      );
    }
  }

 
  Future<void> _abortChildAuthSession() async {
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
    await ChildSessionService.clearSession();
  }

  
  Future<void> _handleLegacyChildLogin() async {
    final username = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final query = await FirebaseFirestore.instance
          .collectionGroup('children')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: password)
          .get();

      if (query.docs.isEmpty) {
        // 0 results: invalid credentials.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid username or password')),
        );
        return;
      }

      if (query.docs.length > 1) {
       
        print(
          '❌ LoginScreen: legacy child login matched ${query.docs.length} documents '
          'for username "$username" — refusing to pick one arbitrarily.',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We couldn\'t sign you in. Please contact your parent for help.',
            ),
          ),
        );
        return;
      }

      // Exactly 1 result: safe to establish a stable session.
      final childDoc = query.docs.single;
      final session = ChildSession.fromDocument(childDoc);
      final onboardingComplete = childDoc.data()['onboardingComplete'] ?? false;

      ChildSessionService.setSession(session);
      await ChildSessionService.persistSession(session);

      // Save credentials if remember me is checked (legacy credential
      // cache, unrelated to ChildSession — left as-is).
      if (_rememberMe) {
        await _saveLoginCredentials(
          username,
          password,
          false,
          session.displayName,
        );
      }

      if (!mounted) return;
      _navigateAfterChildLogin(session, onboardingComplete);
    } catch (e) {
      print('❌ Legacy child login failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed. ${e.toString()}')));
    }
  }

  void _navigateAfterChildLogin(ChildSession session, bool onboardingComplete) {
    if (onboardingComplete) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChildDashboardScreen(childName: session.displayName),
        ),
      );
    } else {
      // Start with app selection for new child accounts
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AppSelectionScreen(childName: session.displayName),
        ),
      );
    }
  }

  Future<void> _saveLoginCredentials(
    String username,
    String password,
    bool isParent,
    String name,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_username', username);
    await prefs.setString('saved_password', password);
    await prefs.setBool('is_parent', isParent);
    await prefs.setString('saved_name', name);
    await prefs.setBool('remember_me', true);
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe) {
      final savedUsername = prefs.getString('saved_username') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';
      final isParent = prefs.getBool('is_parent') ?? true;

      setState(() {
        _emailController.text = savedUsername;
        _passwordController.text = savedPassword;
        _rememberMe = rememberMe;
        _mode = isParent ? _LoginMode.parent : _LoginMode.child;
      });
    }
  }

  String? _validateOptionalFamilyCode(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty)
      return null; // omitted -> legacy path, see _handleLogin
    return ChildAuthValidation.validateFamilyCode(trimmed);
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
                      const Text(
                        'Welcome Back!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Log in to your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => setState(
                                      () => _mode = _LoginMode.parent,
                                    ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _mode == _LoginMode.parent
                                    ? Colors.white
                                    : Colors.transparent,
                                foregroundColor: _mode == _LoginMode.parent
                                    ? kAccentBlue
                                    : Colors.white,
                                side: const BorderSide(color: Colors.white),
                              ),
                              child: const Text('Parent'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => setState(
                                      () => _mode = _LoginMode.child,
                                    ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _mode == _LoginMode.child
                                    ? Colors.white
                                    : Colors.transparent,
                                foregroundColor: _mode == _LoginMode.child
                                    ? kAccentBlue
                                    : Colors.white,
                                side: const BorderSide(color: Colors.white),
                              ),
                              child: const Text('Child'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _mode == _LoginMode.parent ? 'Email' : 'Child Username',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isSubmitting,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: _mode == _LoginMode.parent
                              ? 'Enter your email'
                              : 'Enter your child username',
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 3
                            ? 'Required'
                            : null,
                      ),
                      if (_mode == _LoginMode.child) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Family Code',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _familyCodeController,
                          enabled: !_isSubmitting,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.black),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Enter your family code',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          validator: _validateOptionalFamilyCode,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Older child accounts may continue without a family code.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isSubmitting,
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 6
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: _isSubmitting
                                ? null
                                : (value) {
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
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  _handleLogin();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Log In',
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
