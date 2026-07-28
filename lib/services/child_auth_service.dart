import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;


bool isChildAuthMigrated(Map<String, dynamic> child) {
  final authUid = child['authUid'] as String?;
  return child['authMigrated'] == true && authUid != null && authUid.isNotEmpty;
}

class ChildAuthValidation {
  ChildAuthValidation._();

  static final RegExp usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
  static final RegExp familyCodePattern = RegExp(r'^[a-zA-Z0-9]{4,12}$');
  static const int minPasswordLength = 6;

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Please enter the child's name";
    }
    return null;
  }

  static String? validateUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (!usernamePattern.hasMatch(trimmed)) {
      return 'Username must be 3-20 characters: letters, numbers, and underscores only';
    }
    return null;
  }

  static String? validateFamilyCode(String? value) {
    final trimmed = value?.trim() ?? '';
    if (!familyCodePattern.hasMatch(trimmed)) {
      return 'Family code must be 4-12 characters: letters and numbers only';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    return null;
  }
}


class CreateChildAccountResult {
  final String parentUid;
  final String childId;
  final String authUid;

 
  final bool alreadyExisted;

  const CreateChildAccountResult({
    required this.parentUid,
    required this.childId,
    required this.authUid,
    required this.alreadyExisted,
  });

  factory CreateChildAccountResult.fromMap(Map<Object?, Object?> data) {
    return CreateChildAccountResult(
      parentUid: data['parentUid'] as String,
      childId: data['childId'] as String,
      authUid: data['authUid'] as String,
      alreadyExisted: data['alreadyExisted'] as bool? ?? false,
    );
  }
}


class ChildLoginResult {
  final String customToken;
  final String parentUid;
  final String childId;

  const ChildLoginResult({
    required this.customToken,
    required this.parentUid,
    required this.childId,
  });

  factory ChildLoginResult.fromMap(Map<Object?, Object?> data) {
    return ChildLoginResult(
      customToken: data['customToken'] as String,
      parentUid: data['parentUid'] as String,
      childId: data['childId'] as String,
    );
  }
}


class ResetChildPasswordResult {
  final bool success;
  final bool sessionsRevoked;

  const ResetChildPasswordResult({
    required this.success,
    required this.sessionsRevoked,
  });

  factory ResetChildPasswordResult.fromMap(Map<Object?, Object?> data) {
    return ResetChildPasswordResult(
      success: data['success'] as bool? ?? true,
      sessionsRevoked: data['sessionsRevoked'] as bool? ?? false,
    );
  }
}


class DeleteChildAccountResult {
  final bool success;

  final bool authDisabled;

  const DeleteChildAccountResult({
    required this.success,
    required this.authDisabled,
  });

  factory DeleteChildAccountResult.fromMap(Map<Object?, Object?> data) {
    return DeleteChildAccountResult(
      success: data['success'] as bool? ?? true,
      authDisabled: data['authDisabled'] as bool? ?? false,
    );
  }
}


class ChildAuthException implements Exception {
  final String code;
  final String message;

  const ChildAuthException(this.code, this.message);

  factory ChildAuthException.unauthenticated() => const ChildAuthException(
    'unauthenticated',
    'Your parent session has expired. Please sign in again.',
  );


  factory ChildAuthException.fromFirebaseFunctionsException(
    FirebaseFunctionsException e,
  ) {
    switch (e.code) {
      case 'unauthenticated':
        return ChildAuthException.unauthenticated();
      case 'permission-denied':
        return const ChildAuthException(
          'permission-denied',
          'You do not have permission to create this child account.',
        );
      case 'invalid-argument':
        return ChildAuthException(
          'invalid-argument',
          e.message ?? 'Some of the information provided is invalid.',
        );
      case 'already-exists':
        return const ChildAuthException(
          'already-exists',
          'A child account with this family code and username already exists.',
        );
      case 'failed-precondition':
        return const ChildAuthException(
          'failed-precondition',
          'This child account could not be created right now. Please contact support.',
        );
      case 'resource-exhausted':
        return const ChildAuthException(
          'resource-exhausted',
          'Too many requests. Please wait and try again.',
        );
      case 'internal':
      default:
        return const ChildAuthException(
          'internal',
          'Something went wrong. Please try again.',
        );
    }
  }

  
  factory ChildAuthException.fromLoginFailure(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'resource-exhausted':
        return const ChildAuthException(
          'resource-exhausted',
          'Too many failed attempts. Please wait and try again.',
        );
      case 'unavailable':
        return const ChildAuthException(
          'unavailable',
          'Unable to reach the server. Please check your connection and try again.',
        );
      case 'deadline-exceeded':
        return const ChildAuthException(
          'deadline-exceeded',
          'The request took too long. Please try again.',
        );
      case 'internal':
        return const ChildAuthException(
          'internal',
          'Something went wrong. Please try again.',
        );
      case 'invalid-argument':
      case 'permission-denied':
      case 'unauthenticated':
      case 'failed-precondition':
      default:
        return const ChildAuthException(
          'invalid-credentials',
          'Invalid family code, username, or password.',
        );
    }
  }

  
  factory ChildAuthException.signInFailed() => const ChildAuthException(
    'sign-in-failed',
    "We couldn't complete your sign-in. Please try again.",
  );

 
  factory ChildAuthException.fromParentManagementFailure(
    FirebaseFunctionsException e,
  ) {
    switch (e.code) {
      case 'unauthenticated':
        return ChildAuthException.unauthenticated();
      case 'permission-denied':
        return const ChildAuthException(
          'permission-denied',
          'You do not have permission to perform this action.',
        );
      case 'not-found':
        return const ChildAuthException(
          'not-found',
          'This child account could not be found.',
        );
      case 'invalid-argument':
        return ChildAuthException(
          'invalid-argument',
          e.message ?? 'Some of the information provided is invalid.',
        );
      case 'failed-precondition':
        return const ChildAuthException(
          'failed-precondition',
          'This action could not be completed right now. Please try again.',
        );
      case 'resource-exhausted':
        return const ChildAuthException(
          'resource-exhausted',
          'Too many requests. Please wait and try again.',
        );
      case 'unavailable':
        return const ChildAuthException(
          'unavailable',
          'Unable to reach the server. Please check your connection and try again.',
        );
      case 'deadline-exceeded':
        return const ChildAuthException(
          'deadline-exceeded',
          'The request took too long. Please try again.',
        );
      case 'internal':
      default:
        return const ChildAuthException(
          'internal',
          'Something went wrong. Please try again.',
        );
    }
  }
}


abstract class ChildAccountCallable {
  Future<Map<Object?, Object?>> createChildAccount(
    Map<String, dynamic> payload,
  );

  Future<Map<Object?, Object?>> loginChild(Map<String, dynamic> payload);

  Future<Map<Object?, Object?>> resetChildPassword(
    Map<String, dynamic> payload,
  );

  Future<Map<Object?, Object?>> deleteChildAccount(
    Map<String, dynamic> payload,
  );
}


class FirebaseChildAccountCallable implements ChildAccountCallable {
  FirebaseChildAccountCallable([FirebaseFunctions? functions])
    : _functions = functions ?? FirebaseFunctions.instance {
    _configureEmulatorsOnce();
  }

  final FirebaseFunctions _functions;

  static bool _emulatorConfigured = false;

  static void _configureEmulatorsOnce() {
    if (!kDebugMode || _emulatorConfigured) return;
    _emulatorConfigured = true;
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  }

  @override
  Future<Map<Object?, Object?>> createChildAccount(
    Map<String, dynamic> payload,
  ) async {
    final callable = _functions.httpsCallable('createChildAccount');
    final result = await callable.call(payload);
    return Map<Object?, Object?>.from(result.data as Map);
  }

  @override
  Future<Map<Object?, Object?>> loginChild(Map<String, dynamic> payload) async {
    final callable = _functions.httpsCallable('loginChild');
    final result = await callable.call(payload);
    return Map<Object?, Object?>.from(result.data as Map);
  }

  @override
  Future<Map<Object?, Object?>> resetChildPassword(
    Map<String, dynamic> payload,
  ) async {
    final callable = _functions.httpsCallable('resetChildPassword');
    final result = await callable.call(payload);
    return Map<Object?, Object?>.from(result.data as Map);
  }

  @override
  Future<Map<Object?, Object?>> deleteChildAccount(
    Map<String, dynamic> payload,
  ) async {
    final callable = _functions.httpsCallable('deleteChildAccount');
    final result = await callable.call(payload);
    return Map<Object?, Object?>.from(result.data as Map);
  }
}

class ChildAuthService {
  ChildAuthService({ChildAccountCallable? callable})
    : _callable = callable ?? FirebaseChildAccountCallable();

  final ChildAccountCallable _callable;

  
  static void requireAuthenticatedParent(String? currentUserUid) {
    if (currentUserUid == null) {
      throw ChildAuthException.unauthenticated();
    }
  }


  Future<CreateChildAccountResult> createChildAccount({
    required String childId,
    required String name,
    required String username,
    required String familyCode,
    required String password,
  }) async {
    try {
      final data = await _callable.createChildAccount({
        'childId': childId,
        'name': name,
        'username': username,
        'familyCode': familyCode,
        'password': password,
      });
      return CreateChildAccountResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      throw ChildAuthException.fromFirebaseFunctionsException(e);
    }
  }

  
  Future<ChildLoginResult> loginChild({
    required String familyCode,
    required String username,
    required String password,
  }) async {
    try {
      final data = await _callable.loginChild({
        'familyCode': familyCode,
        'username': username,
        'password': password,
      });
      return ChildLoginResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      throw ChildAuthException.fromLoginFailure(e);
    }
  }


  Future<ResetChildPasswordResult> resetChildPassword({
    required String childId,
    required String newPassword,
    bool revokeSessions = true,
  }) async {
    try {
      final data = await _callable.resetChildPassword({
        'childId': childId,
        'newPassword': newPassword,
        'revokeSessions': revokeSessions,
      });
      return ResetChildPasswordResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      throw ChildAuthException.fromParentManagementFailure(e);
    }
  }

  Future<DeleteChildAccountResult> deleteChildAccount({
    required String childId,
  }) async {
    try {
      final data = await _callable.deleteChildAccount({'childId': childId});
      return DeleteChildAccountResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      throw ChildAuthException.fromParentManagementFailure(e);
    }
  }
}
