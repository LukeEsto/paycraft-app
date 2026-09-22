import { describe, expect, it } from "vitest";
import { canTransitionQuote, transitionQuote } from "@/lib/quotes/state";

describe("quote state", () => {
  it("allows the feasibility acceptance journey", () => {
    expect(canTransitionQuote("DRAFT", "SENT")).toBe(true);
    expect(canTransitionQuote("SENT", "VIEWED")).toBe(true);
    expect(canTransitionQuote("VIEWED", "ACCEPTED")).toBe(true);
  });

  it("keeps accepted quotes terminal", () => {
    expect(() => transitionQuote("ACCEPTED", "DRAFT")).toThrow("Invalid quote transition");
  });
});
