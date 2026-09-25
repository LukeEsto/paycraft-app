import { describe, expect, it } from "vitest";
import {
  createVerificationCode,
  createVerificationGrant,
  hashVerificationCode,
  hashVerificationGrant,
  maskEmail,
} from "@/lib/invites/verification";

const pepper = "a-development-only-pepper-that-is-long-enough";
const inviteHash = "a".repeat(64);

describe("customer email verification secrets", () => {
  it("creates a fixed-length numeric verification code", () => {
    expect(createVerificationCode()).toMatch(/^\d{6}$/);
  });

  it("binds the stored code hash to its invite context", () => {
    const code = "012345";
    const first = hashVerificationCode(code, inviteHash, pepper);
    const second = hashVerificationCode(code, "b".repeat(64), pepper);
    expect(first).toMatch(/^[0-9a-f]{64}$/);
    expect(first).not.toContain(code);
    expect(second).not.toBe(first);
  });

  it("creates and hashes a high-entropy verification grant", () => {
    const grant = createVerificationGrant();
    const hash = hashVerificationGrant(grant, pepper);
    expect(grant).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(hash).toMatch(/^[0-9a-f]{64}$/);
    expect(hash).not.toContain(grant);
  });

  it("masks the recipient address in public status text", () => {
    expect(maskEmail("luke@example.com")).toBe("l***@example.com");
    expect(maskEmail("invalid-address")).toBe("the intended email address");
  });
});
