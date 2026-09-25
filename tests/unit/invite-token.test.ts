import { describe, expect, it } from "vitest";
import { createInviteToken, hashInviteToken, inviteTokenMatches } from "@/lib/invites/token";

const pepper = "a-development-only-pepper-that-is-long-enough";

describe("invite tokens", () => {
  it("creates a 256-bit base64url capability token", () => {
    const first = createInviteToken();
    const second = createInviteToken();
    expect(first).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(second).not.toBe(first);
  });

  it("stores and compares a hash rather than the raw token", () => {
    const token = createInviteToken();
    const hash = hashInviteToken(token, pepper);
    expect(hash).not.toContain(token);
    expect(inviteTokenMatches(token, hash, pepper)).toBe(true);
    expect(inviteTokenMatches(`${token}x`, hash, pepper)).toBe(false);
  });
});
