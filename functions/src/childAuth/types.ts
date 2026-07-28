import type { firestore } from "firebase-admin";

/** Firestore collection names for the child-auth backend. Centralized so
 * every module references the same literal strings. */
export const COLLECTIONS = {
  users: "users",
  children: "children",
  childLoginLookup: "childLoginLookup",
  childAuthCredentials: "childAuthCredentials",
  childLoginAttempts: "childLoginAttempts",
} as const;


export interface ChildCustomClaims {
  role: "child";
  parentUid: string;
  childId: string;
}


export interface ChildProfileDoc {
  name?: string;
  username?: string;
  /** Legacy plaintext credential field — untouched by this backend. */
  password?: string;
  familyCode?: string;
  authUid?: string;
  onboardingComplete?: boolean;
  createdAt?: firestore.FieldValue | firestore.Timestamp;
  authMigrated?: boolean;

  authEnabled?: boolean;
}


export interface ChildLoginLookupDoc {
  parentUid: string;
  childId: string;
  authUid: string;
  username: string;
  normalizedUsername: string;
  familyCode: string;
  normalizedFamilyCode: string;
  active: boolean;
  createdAt: firestore.FieldValue | firestore.Timestamp;
  updatedAt?: firestore.FieldValue | firestore.Timestamp;
}


export interface ChildAuthCredentialsDoc {
  passwordHash: string;
  parentUid: string;
  childId: string;
  active: boolean;
  createdAt: firestore.FieldValue | firestore.Timestamp;
  updatedAt: firestore.FieldValue | firestore.Timestamp;
}


export interface ChildLoginAttemptsDoc {
  failedCount: number;
  lastFailedAt?: firestore.FieldValue | firestore.Timestamp;
  lockedUntil?: firestore.Timestamp | null;
}

// ---- Callable function input/output contracts ----

export interface CreateChildAccountInput {
  childId: string;
  name: string;
  username: string;
  familyCode: string;
  password: string;
}

export interface CreateChildAccountResult {
  parentUid: string;
  childId: string;
  authUid: string;
  alreadyExisted: boolean;
}

export interface LoginChildInput {
  familyCode: string;
  username: string;
  password: string;
}

export interface LoginChildResult {
  customToken: string;
  parentUid: string;
  childId: string;
}

export interface ResetChildPasswordInput {
  childId: string;
  newPassword: string;
  revokeSessions?: boolean;
}

export interface ResetChildPasswordResult {
  success: true;
  sessionsRevoked: boolean;
}

export interface DeleteChildAccountInput {
  childId: string;
}

export interface DeleteChildAccountResult {
  success: true;
  authDisabled: boolean;
}
