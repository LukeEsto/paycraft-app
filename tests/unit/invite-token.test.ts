import { describe, expect, it } from "vitest";
import { createInviteToken, hashInviteToken, inviteTokenMatches } from "@/lib/invites/token";

const pepper = "a-development-only-pepper-that-is-long-enough";

describe("invite tokens", () => {
  it("stores and compares a hash rather than the raw token", () => {
    const token = createInviteToken();
    const hash = hashInviteToken(token, pepper);
    expect(hash).not.toContain(token);
    expect(inviteTokenMatches(token, hash, pepper)).toBe(true);
    expect(inviteTokenMatches(`${token}x`, hash, pepper)).toBe(false);
  });
});
