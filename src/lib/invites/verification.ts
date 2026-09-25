import { createHash, randomBytes, randomInt } from "node:crypto";

function requirePepper(pepper: string): void {
  if (pepper.length < 32) throw new Error("Invite token pepper must contain at least 32 characters.");
}

export function createVerificationCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, "0");
}

export function hashVerificationCode(code: string, inviteTokenHash: string, pepper: string): string {
  requirePepper(pepper);
  if (!/^\d{6}$/.test(code) || !/^[0-9a-f]{64}$/.test(inviteTokenHash)) {
    throw new Error("Invalid verification code context.");
  }
  return createHash("sha256").update(`${pepper}:verification-code:${inviteTokenHash}:${code}`).digest("hex");
}

export function createVerificationGrant(): string {
  return randomBytes(32).toString("base64url");
}

export function hashVerificationGrant(grant: string, pepper: string): string {
  requirePepper(pepper);
  if (!/^[A-Za-z0-9_-]{43}$/.test(grant)) throw new Error("Invalid verification grant.");
  return createHash("sha256").update(`${pepper}:verification-grant:${grant}`).digest("hex");
}

export function maskEmail(email: string): string {
  const [localPart, domain] = email.split("@");
  if (!localPart || !domain) return "the intended email address";
  return `${localPart[0]}${"*".repeat(Math.max(3, localPart.length - 1))}@${domain}`;
}
