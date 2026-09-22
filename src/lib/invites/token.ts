import { createHash, randomBytes, timingSafeEqual } from "node:crypto";

export function createInviteToken(): string {
  return randomBytes(32).toString("base64url");
}

export function hashInviteToken(token: string, pepper: string): string {
  if (pepper.length < 32) throw new Error("Invite token pepper must contain at least 32 characters.");
  return createHash("sha256").update(`${pepper}:${token}`).digest("hex");
}

export function inviteTokenMatches(token: string, expectedHash: string, pepper: string): boolean {
  const actual = Buffer.from(hashInviteToken(token, pepper), "hex");
  const expected = Buffer.from(expectedHash, "hex");
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}
