import { HttpsError } from "firebase-functions/v2/https";
import type { CallableRequest } from "firebase-functions/v2/https";
import type { firestore } from "firebase-admin";
import { COLLECTIONS, type ChildProfileDoc } from "./types";

export function requireAuthenticatedUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "This operation requires an authenticated parent.",
    );
  }
  return uid;
}

export async function requireParentRole(
  db: firestore.Firestore,
  parentUid: string,
): Promise<firestore.DocumentData> {
  const parentDoc = await db.collection(COLLECTIONS.users).doc(parentUid).get();

  if (!parentDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Caller does not have a parent account.",
    );
  }

  const data = parentDoc.data() ?? {};
  if (data.role !== "parent") {
    throw new HttpsError(
      "permission-denied",
      "Caller is not authorized to manage child accounts.",
    );
  }

  return data;
}

export async function loadOwnedChildProfile(
  db: firestore.Firestore,
  parentUid: string,
  childId: string,
): Promise<firestore.DocumentSnapshot<ChildProfileDoc>> {
  const ref = db
    .collection(COLLECTIONS.users)
    .doc(parentUid)
    .collection(COLLECTIONS.children)
    .doc(childId) as firestore.DocumentReference<ChildProfileDoc>;

  const snapshot = await ref.get();
  if (!snapshot.exists) {
    throw new HttpsError(
      "not-found",
      "No child profile was found for this parent and childId.",
    );
  }
  return snapshot;
}
