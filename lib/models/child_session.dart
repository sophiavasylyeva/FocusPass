import 'package:cloud_firestore/cloud_firestore.dart';

/// Stable identity for the currently active child.
///
/// [parentUid] + [childId] together are the ONLY fields that may be used to
/// locate, read, update, or own child data. [username] and [displayName]
/// are metadata only:
///
/// - [username]: login/display metadata. Must not be used as an implicit
///   document path outside the session-creation flow (login already uses it
///   to find the child document once; after that, only [childId] and
///   [parentUid] should be used).
/// - [displayName]: the child's visible name (Firestore field `name`). Must
///   never be used for Firestore identity — display text only (e.g.
///   "Welcome, Alex!").
///
/// The canonical child document path is always:
/// `users/{parentUid}/children/{childId}`.
class ChildSession {
  final String parentUid;
  final String childId;
  final String username;
  final String displayName;

  const ChildSession({
    required this.parentUid,
    required this.childId,
    required this.username,
    required this.displayName,
  });

  /// Builds a session from a child document snapshot read at
  /// `users/{parentUid}/children/{childId}` (directly, or as the result of
  /// the legacy `collectionGroup('children')` login match).
  ///
  /// [childId] is derived from `childDoc.id` and [parentUid] from
  /// `childDoc.reference.parent.parent!.id` — both are only trustworthy when
  /// the document actually lives at `users/{parentUid}/children/{childId}`.
  /// This factory never returns an invalid session: it throws a
  /// [StateError] if the document isn't nested where expected, or if the
  /// resulting identity fields would be empty.
  factory ChildSession.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> childDoc,
  ) {
    final childId = childDoc.id;
    final parentRef = childDoc.reference.parent.parent;

    if (parentRef == null) {
      throw StateError(
        'ChildSession.fromDocument: document at "${childDoc.reference.path}" '
        'is not nested under users/{parentUid}/children/{childId}; refusing '
        'to derive a child session from it.',
      );
    }

    final parentUid = parentRef.id;
    final data = childDoc.data() ?? const <String, dynamic>{};
    final username = (data['username'] as String?) ?? '';
    final displayName = (data['name'] as String?) ?? '';

    if (parentUid.isEmpty || childId.isEmpty) {
      throw StateError(
        'ChildSession.fromDocument: refusing to create a session with an '
        'empty parentUid ("$parentUid") or childId ("$childId") for '
        'document "${childDoc.reference.path}".',
      );
    }

    return ChildSession(
      parentUid: parentUid,
      childId: childId,
      username: username,
      displayName: displayName,
    );
  }

  /// Builds a session from an ALREADY-VERIFIED Firebase Auth child
  /// principal: [parentUid] and [childId] must come from validated custom
  /// claims (see [validateChildAuthClaims]), never from client input or an
  /// unverified document path. [childData] is the child's profile document
  /// data, read directly from `users/{parentUid}/children/{childId}` (never
  /// a `collectionGroup` match) — see
  /// `ChildSessionService.buildFromAuthenticatedUser`, which is the only
  /// intended caller of this factory.
  ///
  /// Unlike [fromDocument], this never inspects the document's own path to
  /// derive identity — [parentUid]/[childId] are trusted inputs here by
  /// design, since the whole point of the secure login flow is that they
  /// were already proven correct by Firebase Auth's signed token, not by
  /// wherever a document happens to live.
  factory ChildSession.fromAuthenticatedChild({
    required String parentUid,
    required String childId,
    required Map<String, dynamic> childData,
  }) {
    if (parentUid.isEmpty || childId.isEmpty) {
      throw StateError(
        'ChildSession.fromAuthenticatedChild: refusing to create a session '
        'with an empty parentUid ("$parentUid") or childId ("$childId").',
      );
    }
    final username = (childData['username'] as String?) ?? '';
    final displayName = (childData['name'] as String?) ?? '';
    return ChildSession(
      parentUid: parentUid,
      childId: childId,
      username: username,
      displayName: displayName,
    );
  }

  /// Reconstructs a session purely from cached values (e.g. SharedPreferences)
  /// without touching Firestore. Returns `null` rather than throwing when the
  /// identity fields are missing, since "no cached session" is an expected,
  /// non-exceptional state (first launch, logged out, cleared cache).
  ///
  /// Callers that restore a session this way should still confirm the child
  /// document still exists (via [childRef]) before trusting it for writes —
  /// see `ChildSessionService.restoreSession`.
  static ChildSession? fromCache({
    required String? parentUid,
    required String? childId,
    required String? username,
    required String? displayName,
  }) {
    if (parentUid == null ||
        parentUid.isEmpty ||
        childId == null ||
        childId.isEmpty) {
      return null;
    }
    return ChildSession(
      parentUid: parentUid,
      childId: childId,
      username: username ?? '',
      displayName: displayName ?? '',
    );
  }

  /// The canonical, and only correct, reference to this child's profile
  /// document: `users/{parentUid}/children/{childId}`.
  DocumentReference<Map<String, dynamic>> childRef([
    FirebaseFirestore? firestore,
  ]) {
    final db = firestore ?? FirebaseFirestore.instance;
    return db
        .collection('users')
        .doc(parentUid)
        .collection('children')
        .doc(childId);
  }

  @override
  String toString() =>
      'ChildSession(parentUid: $parentUid, childId: $childId, username: $username)';

  @override
  bool operator ==(Object other) =>
      other is ChildSession &&
      other.parentUid == parentUid &&
      other.childId == childId &&
      other.username == username &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(parentUid, childId, username, displayName);
}

/// The three custom claims Firebase Auth puts on a child's ID token (see
/// functions/src/childAuth/types.ts `ChildCustomClaims`), decoded and
/// confirmed well-formed. Never constructed directly — only via
/// [validateChildAuthClaims].
class ChildAuthClaims {
  final String role;
  final String parentUid;
  final String childId;

  const ChildAuthClaims({
    required this.role,
    required this.parentUid,
    required this.childId,
  });
}

/// Thrown by [validateChildAuthClaims] when a signed-in Firebase Auth
/// user's custom claims don't prove a valid, matching child identity.
/// Callers must treat this as a hard authentication failure: sign the user
/// out and clear any [ChildSession] rather than continuing — see
/// login_screen.dart and welcome_screen.dart.
class ChildAuthClaimsException implements Exception {
  final String message;
  const ChildAuthClaimsException(this.message);

  @override
  String toString() => 'ChildAuthClaimsException: $message';
}

/// Validates the decoded custom claims from a child's Firebase ID token
/// (`currentUser.getIdTokenResult(true).claims`).
///
/// Checks, in order: `role` is exactly `"child"`; `parentUid` and `childId`
/// are both non-empty strings. If [expectedParentUid]/[expectedChildId] are
/// given (the interactive login flow passes the identity the `loginChild`
/// callable itself returned), they must match the claims exactly — this is
/// what proves the freshly-issued custom token actually corresponds to the
/// account that was just authenticated, not some other child's cached
/// token. Auto-login (welcome_screen.dart) has no separate callable result
/// to compare against, so it omits these and trusts the claims alone (which
/// is the whole point of an already-signed token).
///
/// Throws [ChildAuthClaimsException] on any failure; never returns a
/// partially-valid result.
ChildAuthClaims validateChildAuthClaims(
  Map<String, dynamic>? claims, {
  String? expectedParentUid,
  String? expectedChildId,
}) {
  final role = claims?['role'];
  if (role != 'child') {
    throw const ChildAuthClaimsException('missing or non-child "role" claim');
  }

  final parentUid = claims?['parentUid'];
  if (parentUid is! String || parentUid.isEmpty) {
    throw const ChildAuthClaimsException('missing or empty "parentUid" claim');
  }

  final childId = claims?['childId'];
  if (childId is! String || childId.isEmpty) {
    throw const ChildAuthClaimsException('missing or empty "childId" claim');
  }

  if (expectedParentUid != null && parentUid != expectedParentUid) {
    throw const ChildAuthClaimsException(
      'parentUid claim does not match the authenticated result',
    );
  }
  if (expectedChildId != null && childId != expectedChildId) {
    throw const ChildAuthClaimsException(
      'childId claim does not match the authenticated result',
    );
  }

  return ChildAuthClaims(role: role, parentUid: parentUid, childId: childId);
}
