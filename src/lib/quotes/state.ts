export const quoteStatuses = ["DRAFT", "SENT", "VIEWED", "ACCEPTED", "DECLINED", "EXPIRED", "CANCELLED"] as const;
export type QuoteStatus = (typeof quoteStatuses)[number];

const allowed: Record<QuoteStatus, ReadonlySet<QuoteStatus>> = {
  DRAFT: new Set(["SENT", "CANCELLED"]),
  SENT: new Set(["VIEWED", "ACCEPTED", "DECLINED", "EXPIRED", "CANCELLED"]),
  VIEWED: new Set(["ACCEPTED", "DECLINED", "EXPIRED", "CANCELLED"]),
  ACCEPTED: new Set(),
  DECLINED: new Set(),
  EXPIRED: new Set(),
  CANCELLED: new Set(),
};

export function canTransitionQuote(from: QuoteStatus, to: QuoteStatus): boolean {
  return allowed[from].has(to);
}

export function transitionQuote(from: QuoteStatus, to: QuoteStatus): QuoteStatus {
  if (!canTransitionQuote(from, to)) throw new Error(`Invalid quote transition: ${from} -> ${to}`);
  return to;
}
