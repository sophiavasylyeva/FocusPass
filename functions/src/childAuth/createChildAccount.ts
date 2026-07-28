import * as admin from "firebase-admin";
import type { firestore } from "firebase-admin";
import { onCall, HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

import { COLLECTIONS, type ChildProfileDoc } from "./types";
import type {
  CreateChildAccountInput,
  CreateChildAccountResult,
  ChildLoginLookupDoc,
  ChildAuthCredentialsDoc,
  ChildCustomClaims,
} from "./types";
import { requireAuthenticatedUid, requireParentRole } from "./authorization";
import {
  validateChildId,
  validateName,
  validateUsername,
  validateFamilyCode,
  validatePassword,
} from "./validation";
import { normalizeUsername, normalizeFamilyCode } from "./normalization";
import { buildLookupKey } from "./lookup";
import { hashPassword } from "./password";

export interface CreateChildAccountDeps {
  db: firestore.Firestore;
  auth: admin.auth.Auth;
}

function defaultDeps(): CreateChildAccountDeps {
  return { db: admin.firestore(), auth: admin.auth() };
}

export async function createChildAccountHandler(
  request: CallableRequest<CreateChildAccountInput>,
  deps: CreateChildAccountDeps = defaultDeps(),
): Promise<CreateChildAccountResult> {
  const { db, auth } = deps;

  const parentUid = requireAuthenticatedUid(request);
  await requireParentRole(db, parentUid);

  const data = request.data ?? ({} as CreateChildAccountInput);
  const childId = validateChildId(data.childId);
  const name = validateName(data.name);
  const username = validateUsername(data.username);
  const familyCode = validateFamilyCode(data.familyCode);
  const password = validatePassword(data.password);

  const normalizedUsername = normalizeUsername(username);
  const normalizedFamilyCode = normalizeFamilyCode(familyCode);
  const lookupKey = buildLookupKey(normalizedFamilyCode, normalizedUsername);

  const childRef = db
    .collection(COLLECTIONS.users)
    .doc(parentUid)
    .collection(COLLECTIONS.children)
    .doc(childId) as firestore.DocumentReference<ChildProfileDoc>;

  const lookupRef = db
    .collection(COLLECTIONS.childLoginLookup)
    .doc(lookupKey) as firestore.DocumentReference<ChildLoginLookupDoc>;

  const [existingChildSnap, existingLookupSnap] = await Promise.all([
    childRef.get(),
    lookupRef.get(),
  ]);

  const existingChildData = existingChildSnap.data();
  if (existingChildData?.authMigrated && existingChildData.authUid) {
    const credsSnap = await db
      .collection(COLLECTIONS.childAuthCredentials)
      .doc(existingChildData.authUid)
      .get();
    if (credsSnap.exists && (credsSnap.data() as ChildAuthCredentialsDoc).active) {
      logger.info("createChildAccount: idempotent no-op, child already migrated", {
        parentUid,
        childId,
      });
      return {
        parentUid,
        childId,
        authUid: existingChildData.authUid,
        alreadyExisted: true,
      };
    }
  
    throw new HttpsError(
      "failed-precondition",
      "This child is marked as migrated but has no active credentials record. " +
        "Manual investigation is required before retrying.",
    );
  }

  if (existingLookupSnap.exists) {
    const existingLookup = existingLookupSnap.data() as ChildLoginLookupDoc;
    const sameChild =
      existingLookup.parentUid === parentUid && existingLookup.childId === childId;
    if (!sameChild) {
      throw new HttpsError(
        "already-exists",
        "This family code and username combination is already in use.",
      );
    }
   
  }

 
  const authUser = await auth.createUser({ disabled: false });
  const authUid = authUser.uid;

  try {
    const claims: ChildCustomClaims = { role: "child", parentUid, childId };
    await auth.setCustomUserClaims(authUid, claims);
  } catch (err) {
    await compensateDeleteAuthUser(auth, authUid, "setCustomUserClaims failed");
    throw new HttpsError("internal", "Failed to configure the new child account.");
  }

  try {
    const passwordHash = await hashPassword(password);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const batch = db.batch();

    const credentialsRef = db
      .collection(COLLECTIONS.childAuthCredentials)
      .doc(authUid) as firestore.DocumentReference<ChildAuthCredentialsDoc>;
    batch.set(credentialsRef, {
      passwordHash,
      parentUid,
      childId,
      active: true,
      createdAt: now,
      updatedAt: now,
    });

    const lookupDoc: ChildLoginLookupDoc = {
      parentUid,
      childId,
      authUid,
      username,
      normalizedUsername,
      familyCode,
      normalizedFamilyCode,
      active: true,
      createdAt: now,
    };
    batch.set(lookupRef, lookupDoc);

    batch.set(
      childRef,
      {
        name,
        username,
        familyCode,
        authUid,
        authMigrated: true,
        authEnabled: true,
        onboardingComplete: existingChildData?.onboardingComplete ?? false,
        createdAt: existingChildData?.createdAt ?? now,
      },
      { merge: true },
    );

    await batch.commit();
  } catch (err) {
    await compensateDeleteAuthUser(auth, authUid, "Firestore batch write failed");
    throw new HttpsError(
      "internal",
      "Failed to finish creating the child account. Please try again.",
    );
  }

  logger.info("createChildAccount: created new child auth account", {
    parentUid,
    childId,
    authUid,
  });

  return { parentUid, childId, authUid, alreadyExisted: false };
}

async function compensateDeleteAuthUser(
  auth: admin.auth.Auth,
  authUid: string,
  reason: string,
): Promise<void> {
  try {
    await auth.deleteUser(authUid);
    logger.error(
      `createChildAccount: compensating cleanup succeeded after ${reason}; ` +
        `deleted orphaned Auth user.`,
      { authUid },
    );
  } catch (cleanupErr) {
    logger.error(
      `createChildAccount: compensating cleanup FAILED after ${reason}; ` +
        `an orphaned Auth user may exist and requires manual deletion.`,
      { authUid, cleanupError: String(cleanupErr) },
    );
  }
}

export const createChildAccount = onCall<CreateChildAccountInput>((request) =>
  createChildAccountHandler(request),
);
