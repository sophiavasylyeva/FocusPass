import * as admin from "firebase-admin";
import type { firestore } from "firebase-admin";
import { onCall, HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

import { COLLECTIONS } from "./types";
import type {
  LoginChildInput,
  LoginChildResult,
  ChildLoginLookupDoc,
  ChildAuthCredentialsDoc,
} from "./types";
import { validateUsername, validateFamilyCode, validatePassword } from "./validation";
import { normalizeUsername, normalizeFamilyCode } from "./normalization";
import { buildLookupKey } from "./lookup";
import { verifyPassword } from "./password";
import {
  assertNotLockedOut,
  recordFailedAttempt,
  resetFailedAttempts,
} from "./rateLimit";

export interface LoginChildDeps {
  db: firestore.Firestore;
  auth: admin.auth.Auth;
}

function defaultDeps(): LoginChildDeps {
  return { db: admin.firestore(), auth: admin.auth() };
}

const INVALID_CREDENTIALS_MESSAGE = "Invalid family code, username, or password.";

export async function loginChildHandler(
  request: CallableRequest<LoginChildInput>,
  deps: LoginChildDeps = defaultDeps(),
): Promise<LoginChildResult> {
  const { db, auth } = deps;

  const data = request.data ?? ({} as LoginChildInput);
  const username = validateUsername(data.username);
  const familyCode = validateFamilyCode(data.familyCode);
  const password = validatePassword(data.password);

  const normalizedUsername = normalizeUsername(username);
  const normalizedFamilyCode = normalizeFamilyCode(familyCode);
  const lookupKey = buildLookupKey(normalizedFamilyCode, normalizedUsername);

  await assertNotLockedOut(db, lookupKey);

  const lookupSnap = await db
    .collection(COLLECTIONS.childLoginLookup)
    .doc(lookupKey)
    .get();

  if (!lookupSnap.exists) {
    await recordFailedAttempt(db, lookupKey);
    throw new HttpsError("invalid-argument", INVALID_CREDENTIALS_MESSAGE);
  }

  const lookup = lookupSnap.data() as ChildLoginLookupDoc;

  const credsSnap = await db
    .collection(COLLECTIONS.childAuthCredentials)
    .doc(lookup.authUid)
    .get();

  if (!credsSnap.exists) {
    logger.error("loginChild: lookup doc has no matching credentials doc", {
      lookupKey,
      authUid: lookup.authUid,
    });
    await recordFailedAttempt(db, lookupKey);
    throw new HttpsError("invalid-argument", INVALID_CREDENTIALS_MESSAGE);
  }

  const credentials = credsSnap.data() as ChildAuthCredentialsDoc;
  const passwordMatches = await verifyPassword(password, credentials.passwordHash);

  if (!passwordMatches) {
    await recordFailedAttempt(db, lookupKey);
    throw new HttpsError("invalid-argument", INVALID_CREDENTIALS_MESSAGE);
  }


  if (!lookup.active || !credentials.active) {
    logger.info("loginChild: correct password but account disabled", {
      parentUid: lookup.parentUid,
      childId: lookup.childId,
    });
    throw new HttpsError(
      "permission-denied",
      "This account has been disabled. Please contact your parent.",
    );
  }

  await resetFailedAttempts(db, lookupKey);

  const customToken = await auth.createCustomToken(lookup.authUid);

  logger.info("loginChild: successful login", {
    parentUid: lookup.parentUid,
    childId: lookup.childId,
  });

  return {
    customToken,
    parentUid: lookup.parentUid,
    childId: lookup.childId,
  };
}

export const loginChild = onCall<LoginChildInput>((request) => loginChildHandler(request));
