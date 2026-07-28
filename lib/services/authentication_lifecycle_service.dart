import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'child_session_service.dart';


abstract class AuthSignOutHandler {
  bool get hasCurrentUser;
  Future<void> signOut();
}

class FirebaseAuthSignOutHandler implements AuthSignOutHandler {
  FirebaseAuthSignOutHandler([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  bool get hasCurrentUser => _auth.currentUser != null;

  @override
  Future<void> signOut() => _auth.signOut();
}


class AuthenticationLifecycleService {
  AuthenticationLifecycleService({AuthSignOutHandler? authHandler})
    : _authHandler = authHandler ?? FirebaseAuthSignOutHandler();

  final AuthSignOutHandler _authHandler;

  static const _rememberMeKey = 'remember_me';
  static const _savedUsernameKey = 'saved_username';
  static const _savedPasswordKey = 'saved_password';
  static const _savedNameKey = 'saved_name';
  static const _isParentKey = 'is_parent';

 
  Future<void> logout({bool clearRememberedCredentials = true}) async {
    await _runStep('signOut', () async {
      if (_authHandler.hasCurrentUser) {
        await _authHandler.signOut();
      }
    });

    await _runStep('clearSession', ChildSessionService.clearSession);

    if (clearRememberedCredentials) {
      await _runStep('clearRememberedCredentials', _clearRememberedCredentials);
    }
  }

  Future<void> _clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_savedUsernameKey);
    await prefs.remove(_savedPasswordKey);
    await prefs.remove(_savedNameKey);
    await prefs.remove(_isParentKey);
  }

  Future<void> _runStep(String stepName, Future<void> Function() step) async {
    try {
      await step();
    } catch (e) {
      print(
        '⚠️ AuthenticationLifecycleService.logout: step "$stepName" failed: $e',
      );
    }
  }
}
