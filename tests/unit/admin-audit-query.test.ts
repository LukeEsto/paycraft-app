import { describe, expect, it } from "vitest";
import { normalizeSafeAuditMetadata, parseAdminAuditQuery } from "@/lib/admin/audit-query";

describe("admin audit query", () => {
  it("accepts only known event filters and positive bounded pages", () => {
    expect(parseAdminAuditQuery({ event: "QUOTE_ACCEPTED", page: "3" })).toEqual({
      eventType: "QUOTE_ACCEPTED",
      page: 3,
    });
    expect(parseAdminAuditQuery({ event: "NOT_REAL", page: "-4" })).toEqual({
      eventType: undefined,
      page: 1,
    });
    expect(parseAdminAuditQuery({ page: "999999" }).page).toBe(10_000);
  });

  it("uses the first value for repeated query parameters", () => {
    expect(parseAdminAuditQuery({ event: ["QUOTE_SENT", "QUOTE_ACCEPTED"], page: ["2", "5"] })).toEqual({
      eventType: "QUOTE_SENT",
      page: 2,
    });
  });

  it("removes capability secrets and customer-sensitive metadata", () => {
    expect(normalizeSafeAuditMetadata({
      total_pence: 12_500,
      accepted_version_number: 2,
      token_hash: "secret-token-hash",
      code_hash: "secret-code-hash",
      verification_grant_hash: "secret-grant-hash",
      email: "customer@example.test",
      phone: "07123456789",
      nested: { password: "secret" },
    })).toEqual({
      total_pence: 12_500,
      accepted_version_number: 2,
    });
  });
});
