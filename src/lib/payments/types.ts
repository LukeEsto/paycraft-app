export const paymentStatuses = [
  "NOT_STARTED",
  "AWAITING_CUSTOMER_ACTION",
  "PROCESSING",
  "CONFIRMED",
  "PARTIALLY_CONFIRMED",
  "FAILED",
  "CANCELLED",
  "REFUND_PENDING",
  "PARTIALLY_REFUNDED",
  "REFUNDED",
  "DISPUTED",
] as const;

export type PaymentStatus = (typeof paymentStatuses)[number];

export interface PaymentAction {
  providerReference: string;
  status: PaymentStatus;
  redirectUrl?: string;
}

export interface PaymentProvider {
  readonly name: string;
  createPayment(input: { jobId: string; amountPence: number; currency: "GBP" }): Promise<PaymentAction>;
  getStatus(providerReference: string): Promise<PaymentStatus>;
}
