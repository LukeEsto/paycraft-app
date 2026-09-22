import { describe, expect, it } from "vitest";
import { tradeRegistrationSchema } from "@/lib/auth/registration-schema";

const validRegistration = {
  fullName: "Luke Esfahani",
  tradingName: "Example Plumbing Ltd",
  primaryTrade: "Plumber",
  businessType: "LIMITED_COMPANY",
  email: "trade@example.com",
  phone: "07123456789",
  password: "LongPassword!2026",
  termsAccepted: true,
  privacyAccepted: true,
} as const;

describe("trade registration validation", () => {
  it("accepts a complete trade registration", () => {
    expect(tradeRegistrationSchema.safeParse(validRegistration).success).toBe(true);
  });

  it("requires both consent records", () => {
    const result = tradeRegistrationSchema.safeParse({ ...validRegistration, privacyAccepted: false });
    expect(result.success).toBe(false);
  });

  it("normalises the email address", () => {
    const result = tradeRegistrationSchema.parse({ ...validRegistration, email: " Trade@Example.COM " });
    expect(result.email).toBe("trade@example.com");
  });

  it("rejects weak passwords", () => {
    const result = tradeRegistrationSchema.safeParse({ ...validRegistration, password: "password123" });
    expect(result.success).toBe(false);
  });
});
