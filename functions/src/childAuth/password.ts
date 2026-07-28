import bcrypt from "bcryptjs";

const DEFAULT_BCRYPT_WORK_FACTOR = 12;

export function getBcryptWorkFactor(): number {
  const raw = process.env.BCRYPT_WORK_FACTOR;
  if (!raw) return DEFAULT_BCRYPT_WORK_FACTOR;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed < 4 || parsed > 15) {
    return DEFAULT_BCRYPT_WORK_FACTOR;
  }
  return parsed;
}

export async function hashPassword(plaintextPassword: string): Promise<string> {
  const workFactor = getBcryptWorkFactor();
  return bcrypt.hash(plaintextPassword, workFactor);
}

export async function verifyPassword(
  plaintextPassword: string,
  passwordHash: string,
): Promise<boolean> {
  return bcrypt.compare(plaintextPassword, passwordHash);
}
