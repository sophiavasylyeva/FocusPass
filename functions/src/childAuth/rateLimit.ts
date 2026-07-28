import * as admin from "firebase-admin";
import type { firestore } from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import { COLLECTIONS, type ChildLoginAttemptsDoc } from "./types";


const DEFAULT_MAX_FAILED_ATTEMPTS = 5;
const DEFAULT_LOCKOUT_DURATION_MS = 15 * 60 * 1000; // 15 minutes

export function getMaxFailedAttempts(): number {
  const raw = process.env.CHILD_LOGIN_MAX_ATTEMPTS;
  const parsed = raw ? Number.parseInt(raw, 10) : NaN;
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_MAX_FAILED_ATTEMPTS;
}

export function getLockoutDurationMs(): number {
  const raw = process.env.CHILD_LOGIN_LOCKOUT_MS;
  const parsed = raw ? Number.parseInt(raw, 10) : NaN;
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_LOCKOUT_DURATION_MS;
}

function attemptsRef(db: firestore.Firestore, lookupKey: string) {
  return db.collection(COLLECTIONS.childLoginAttempts).doc(lookupKey);
}


export async function assertNotLockedOut(
  db: firestore.Firestore,
  lookupKey: string,
): Promise<void> {
  const snapshot = await attemptsRef(db, lookupKey).get();
  const data = snapshot.data() as ChildLoginAttemptsDoc | undefined;
  const lockedUntil = data?.lockedUntil;

  if (lockedUntil && lockedUntil.toMillis() > Date.now()) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many attempts. Please try again later.",
    );
  }
}


export async function recordFailedAttempt(
  db: firestore.Firestore,
  lookupKey: string,
): Promise<void> {
  const ref = attemptsRef(db, lookupKey);
  const maxAttempts = getMaxFailedAttempts();
  const lockoutDurationMs = getLockoutDurationMs();

  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const data = snapshot.data() as ChildLoginAttemptsDoc | undefined;

    const previouslyLockedUntil = data?.lockedUntil;
    const isCurrentlyLocked =
      previouslyLockedUntil && previouslyLockedUntil.toMillis() > Date.now();
    const currentCount = isCurrentlyLocked ? data!.failedCount : (data?.failedCount ?? 0);
    const newCount = currentCount + 1;

    const update: ChildLoginAttemptsDoc & { lockedUntil: firestore.Timestamp | null } = {
      failedCount: newCount,
      lastFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      lockedUntil:
        newCount >= maxAttempts
          ? admin.firestore.Timestamp.fromMillis(Date.now() + lockoutDurationMs)
          : (previouslyLockedUntil ?? null),
    };

    tx.set(ref, update, { merge: true });
  });
}


export async function resetFailedAttempts(
  db: firestore.Firestore,
  lookupKey: string,
): Promise<void> {
  await attemptsRef(db, lookupKey).set(
    {
      failedCount: 0,
      lockedUntil: null,
    },
    { merge: true },
  );
}
