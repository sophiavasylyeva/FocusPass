import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/child_session.dart';


class ChildSessionValidationException implements Exception {
  final String message;
  const ChildSessionValidationException(this.message);

  @override
  String toString() => 'ChildSessionValidationException: $message';
}


({ChildSession session, bool onboardingComplete})
validateAuthenticatedChildProfile({
  required String parentUid,
  required String childId,
  required String authUid,
  required bool exists,
  required Map<String, dynamic>? data,
}) {
  if (!exists || data == null) {
    throw const ChildSessionValidationException(
      'no child profile exists at the claimed parentUid/childId path',
    );
  }

  if (data['authEnabled'] == false) {
    throw const ChildSessionValidationException('child account is disabled');
  }

  final docAuthUid = data['authUid'] as String?;
  if (docAuthUid != null && docAuthUid != authUid) {
    throw const ChildSessionValidationException(
      'child profile authUid does not match the authenticated user',
    );
  }

  final session = ChildSession.fromAuthenticatedChild(
    parentUid: parentUid,
    childId: childId,
    childData: data,
  );
  final onboardingComplete = data['onboardingComplete'] == true;
  return (session: session, onboardingComplete: onboardingComplete);
}


class ChildSessionService {
  ChildSessionService._();

  static ChildSession? _currentSession;

  /// The active session, or `null` if no child is currently logged in on
  /// this device.
  static ChildSession? get currentSession => _currentSession;

  static bool get hasActiveSession => _currentSession != null;

  
  static void setSession(ChildSession session) {
    _currentSession = session;
  }

  static ChildSession requireSession() {
    final session = _currentSession;
    if (session == null) {
      throw StateError(
        'ChildSessionService.requireSession: no active child session. '
        'A child must be logged in before this operation can run.',
      );
    }
    return session;
  }

  
  static const _parentUidKey = 'current_parent_uid';
  static const _childIdKey = 'current_child_id';
  static const _usernameKey = 'current_child_username';
  static const _displayNameKey = 'current_child_name';

  
  static Future<void> persistSession(ChildSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_parentUidKey, session.parentUid);
    await prefs.setString(_childIdKey, session.childId);
    await prefs.setString(_usernameKey, session.username);
    await prefs.setString(_displayNameKey, session.displayName);
  }

  
  static Future<ChildSession?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final session = ChildSession.fromCache(
      parentUid: prefs.getString(_parentUidKey),
      childId: prefs.getString(_childIdKey),
      username: prefs.getString(_usernameKey),
      displayName: prefs.getString(_displayNameKey),
    );
    if (session != null) {
      _currentSession = session;
    }
    return session;
  }

  static Future<void> clearSession() async {
    _currentSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_parentUidKey);
    await prefs.remove(_childIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_displayNameKey);
  }

  
  static Future<({ChildSession session, bool onboardingComplete})>
  buildFromAuthenticatedUser({
    required String parentUid,
    required String childId,
    required String authUid,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final ref = db
        .collection('users')
        .doc(parentUid)
        .collection('children')
        .doc(childId);
    final snapshot = await ref.get();

    return validateAuthenticatedChildProfile(
      parentUid: parentUid,
      childId: childId,
      authUid: authUid,
      exists: snapshot.exists,
      data: snapshot.data(),
    );
  }

  
  static Future<({ChildSession session, bool onboardingComplete})>
  establishFromAuthenticatedUser({
    required User currentUser,
    required Map<String, dynamic>? claims,
    String? expectedParentUid,
    String? expectedChildId,
    FirebaseFirestore? firestore,
  }) async {
    final validated = validateChildAuthClaims(
      claims,
      expectedParentUid: expectedParentUid,
      expectedChildId: expectedChildId,
    );

    final result = await buildFromAuthenticatedUser(
      parentUid: validated.parentUid,
      childId: validated.childId,
      authUid: currentUser.uid,
      firestore: firestore,
    );

    setSession(result.session);
    await persistSession(result.session);
    return result;
  }
}
