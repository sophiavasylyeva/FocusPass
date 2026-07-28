

export function normalizeUsername(rawUsername: string): string {
  return rawUsername.trim().toLowerCase();
}

export function normalizeFamilyCode(rawFamilyCode: string): string {
  return rawFamilyCode.trim().toLowerCase();
}
