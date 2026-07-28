import { HttpsError } from "firebase-functions/v2/https";

const USERNAME_PATTERN = /^[a-zA-Z0-9_]{3,20}$/;

const FAMILY_CODE_PATTERN = /^[a-zA-Z0-9]{4,12}$/;

const MIN_PASSWORD_LENGTH = 6;

function requireNonEmptyString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required.`);
  }
  return value;
}

export function validateChildId(childId: unknown): string {
  return requireNonEmptyString(childId, "childId");
}

export function validateName(name: unknown): string {
  const trimmed = requireNonEmptyString(name, "name").trim();
  if (trimmed.length === 0) {
    throw new HttpsError("invalid-argument", "name is required.");
  }
  return trimmed;
}

export function validateUsername(username: unknown): string {
  const value = requireNonEmptyString(username, "username").trim();
  if (!USERNAME_PATTERN.test(value)) {
    throw new HttpsError(
      "invalid-argument",
      "username must be 3-20 characters and contain only letters, numbers, and underscores.",
    );
  }
  return value;
}

export function validateFamilyCode(familyCode: unknown): string {
  const value = requireNonEmptyString(familyCode, "familyCode").trim();
  if (!FAMILY_CODE_PATTERN.test(value)) {
    throw new HttpsError(
      "invalid-argument",
      "familyCode must be 4-12 characters and contain only letters and numbers.",
    );
  }
  return value;
}

export function validatePassword(password: unknown): string {
  if (typeof password !== "string" || password.length < MIN_PASSWORD_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
    );
  }
  return password;
}

export { MIN_PASSWORD_LENGTH, USERNAME_PATTERN, FAMILY_CODE_PATTERN };
