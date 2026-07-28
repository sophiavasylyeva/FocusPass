import * as admin from "firebase-admin";
import type { firestore } from "firebase-admin";
import { onCall, HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

import { COLLECTIONS } from "./types";
import type { ResetChildPasswordInput, ResetChildPasswordResult } from "./types";
import { requireAuthenticatedUid, requireParentRole, loadOwnedChildProfile } from "./authorization";
import { validateChildId, validatePassword } from "./validation";
import { hashPassword } from "./password";

export interface ResetChildPasswordDeps {
  db: firestore.Firestore;
  auth: admin.auth.Auth;
}

function defaultDeps(): ResetChildPasswordDeps {
  return { db: admin.firestore(), auth: admin.auth() };
}

export async function resetChildPasswordHandler(
  request: CallableRequest<ResetChildPasswordInput>,
  deps: ResetChildPasswordDeps = defaultDeps(),
): Promise<ResetChildPasswordResult> {
  const { db, auth } = deps;

  const parentUid = requireAuthenticatedUid(request);
  await requireParentRole(db, parentUid);

  const data = request.data ?? ({} as ResetChildPasswordInput);
  const childId = validateChildId(data.childId);
  const newPassword = validatePassword(data.newPassword);
  const revokeSessions = data.revokeSessions ?? true;

  const childSnap = await loadOwnedChildProfile(db, parentUid, childId);
  const child = childSnap.data();

  if (!child?.authMigrated || !child.authUid) {
    throw new HttpsError(
      "failed-precondition",
      "This child does not yet have a migrated authentication account.",
    );
  }

  const authUid = child.authUid;
  const passwordHash = await hashPassword(newPassword);

  await db
    .collection(COLLECTIONS.childAuthCredentials)
    .doc(authUid)
    .set(
      {
        passwordHash,
        parentUid,
        childId,
        active: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  if (revokeSessions) {
    await auth.revokeRefreshTokens(authUid);
  }

  logger.info("resetChildPassword: password reset", {
    parentUid,
    childId,
    revokeSessions,
  });

  return { success: true, sessionsRevoked: revokeSessions };
}

export const resetChildPassword = onCall<ResetChildPasswordInput>((request) =>
  resetChildPasswordHandler(request),
);
