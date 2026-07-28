import * as admin from "firebase-admin";
import type { firestore } from "firebase-admin";
import { onCall, type CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

import { COLLECTIONS, type ChildProfileDoc } from "./types";
import type { DeleteChildAccountInput, DeleteChildAccountResult } from "./types";
import { requireAuthenticatedUid, requireParentRole, loadOwnedChildProfile } from "./authorization";
import { validateChildId } from "./validation";
import { normalizeUsername, normalizeFamilyCode } from "./normalization";
import { buildLookupKey } from "./lookup";

export interface DeleteChildAccountDeps {
  db: firestore.Firestore;
  auth: admin.auth.Auth;
}

function defaultDeps(): DeleteChildAccountDeps {
  return { db: admin.firestore(), auth: admin.auth() };
}


export async function deleteChildAccountHandler(
  request: CallableRequest<DeleteChildAccountInput>,
  deps: DeleteChildAccountDeps = defaultDeps(),
): Promise<DeleteChildAccountResult> {
  const { db, auth } = deps;

  const parentUid = requireAuthenticatedUid(request);
  await requireParentRole(db, parentUid);

  const data = request.data ?? ({} as DeleteChildAccountInput);
  const childId = validateChildId(data.childId);

  const childSnap = await loadOwnedChildProfile(db, parentUid, childId);
  const child = childSnap.data() as ChildProfileDoc;

  if (!child.authMigrated || !child.authUid) {
    logger.info("deleteChildAccount: no-op, child was never auth-migrated", {
      parentUid,
      childId,
    });
    return { success: true, authDisabled: false };
  }

  const authUid = child.authUid;

  await auth.updateUser(authUid, { disabled: true });
  await auth.revokeRefreshTokens(authUid);

  const now = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  const credentialsRef = db.collection(COLLECTIONS.childAuthCredentials).doc(authUid);
  batch.set(credentialsRef, { active: false, updatedAt: now }, { merge: true });

  const childRef = childSnap.ref;
  batch.set(childRef, { authEnabled: false }, { merge: true });

  if (child.username && child.familyCode) {
    const lookupKey = buildLookupKey(
      normalizeFamilyCode(child.familyCode),
      normalizeUsername(child.username),
    );
    const lookupRef = db.collection(COLLECTIONS.childLoginLookup).doc(lookupKey);
    batch.set(lookupRef, { active: false, updatedAt: now }, { merge: true });
  } else {
    logger.error(
      "deleteChildAccount: authMigrated child is missing username/familyCode; " +
        "could not locate its childLoginLookup doc to mark inactive",
      { parentUid, childId, authUid },
    );
  }

  await batch.commit();

  logger.info("deleteChildAccount: auth disabled", { parentUid, childId, authUid });

  return { success: true, authDisabled: true };
}

export const deleteChildAccount = onCall<DeleteChildAccountInput>((request) =>
  deleteChildAccountHandler(request),
);
