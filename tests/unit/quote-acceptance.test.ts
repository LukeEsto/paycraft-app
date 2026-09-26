import { describe, expect, it } from "vitest";
import {
  parseQuoteAcceptanceResult,
  quoteAcceptanceRequestSchema,
} from "@/lib/quotes/acceptance";

const request = {
  token: "A".repeat(43),
  quoteId: "11111111-1111-4111-8111-111111111111",
  versionId: "22222222-2222-4222-8222-222222222222",
  versionNumber: "1",
  totalPence: "125000",
};

describe("quote acceptance boundary validation", () => {
  it("accepts an exact strongly typed quote snapshot", () => {
    expect(quoteAcceptanceRequestSchema.parse(request)).toEqual({
      ...request,
      versionNumber: 1,
      totalPence: 125000,
    });
  });

  it("rejects malformed client-supplied identifiers and amounts", () => {
    expect(quoteAcceptanceRequestSchema.safeParse({ ...request, versionId: "another-quote" }).success).toBe(false);
    expect(quoteAcceptanceRequestSchema.safeParse({ ...request, totalPence: "0" }).success).toBe(false);
    expect(quoteAcceptanceRequestSchema.safeParse({ ...request, versionNumber: "1.5" }).success).toBe(false);
  });

  it("accepts only a complete authoritative database result", () => {
    const result = parseQuoteAcceptanceResult({
      accepted: true,
      already_accepted: false,
      quote_id: request.quoteId,
      accepted_version_id: request.versionId,
      accepted_version_number: 1,
      accepted_amount_pence: 125000,
      currency: "GBP",
      accepted_at: "2026-09-26T08:30:00+00:00",
    });

    expect(result?.accepted_amount_pence).toBe(125000);
    expect(parseQuoteAcceptanceResult({ ...result, currency: "USD" })).toBeNull();
    expect(parseQuoteAcceptanceResult({ accepted: true })).toBeNull();
  });
});
