import { createHash } from "node:crypto";

export function buildLookupKey(
  normalizedFamilyCode: string,
  normalizedUsername: string,
): string {
  const separator = String.fromCharCode(0);
  const input = normalizedFamilyCode + separator + normalizedUsername;
  return createHash("sha256").update(input, "utf8").digest("hex");
}
