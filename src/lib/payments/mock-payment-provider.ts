import type { PaymentAction, PaymentProvider, PaymentStatus } from "./types";

export class MockPaymentProvider implements PaymentProvider {
  readonly name = "mock";
  private readonly states = new Map<string, PaymentStatus>();

  async createPayment(input: { jobId: string; amountPence: number; currency: "GBP" }): Promise<PaymentAction> {
    if (!Number.isSafeInteger(input.amountPence) || input.amountPence <= 0) {
      throw new Error("Payment amount must be a positive integer number of pence.");
    }

    const providerReference = `mock_${input.jobId}`;
    this.states.set(providerReference, "AWAITING_CUSTOMER_ACTION");
    return { providerReference, status: "AWAITING_CUSTOMER_ACTION" };
  }

  async getStatus(providerReference: string): Promise<PaymentStatus> {
    return this.states.get(providerReference) ?? "NOT_STARTED";
  }

  simulate(providerReference: string, status: PaymentStatus): void {
    this.states.set(providerReference, status);
  }
}
