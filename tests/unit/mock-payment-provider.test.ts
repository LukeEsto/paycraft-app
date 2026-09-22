import { describe, expect, it } from "vitest";
import { MockPaymentProvider } from "@/lib/payments/mock-payment-provider";

describe("MockPaymentProvider", () => {
  it("starts a valid mock payment without moving money", async () => {
    const provider = new MockPaymentProvider();
    const result = await provider.createPayment({ jobId: "job-1", amountPence: 50000, currency: "GBP" });
    expect(result.status).toBe("AWAITING_CUSTOMER_ACTION");
    expect(await provider.getStatus(result.providerReference)).toBe("AWAITING_CUSTOMER_ACTION");
  });

  it("rejects invalid amounts", async () => {
    const provider = new MockPaymentProvider();
    await expect(provider.createPayment({ jobId: "job-1", amountPence: 1.5, currency: "GBP" })).rejects.toThrow();
  });
});
