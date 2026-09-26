import { z } from "zod";

export const quoteAcceptanceRequestSchema = z.object({
  token: z.string().regex(/^[A-Za-z0-9_-]{43}$/),
  quoteId: z.string().uuid(),
  versionId: z.string().uuid(),
  versionNumber: z.coerce.number().int().positive(),
  totalPence: z.coerce.number().int().positive(),
});

const quoteAcceptanceResultSchema = z.object({
  accepted: z.literal(true),
  already_accepted: z.boolean(),
  quote_id: z.string().uuid(),
  accepted_version_id: z.string().uuid(),
  accepted_version_number: z.number().int().positive(),
  accepted_amount_pence: z.number().int().positive(),
  currency: z.literal("GBP"),
  accepted_at: z.string().datetime({ offset: true }),
});

export type QuoteAcceptanceResult = z.infer<typeof quoteAcceptanceResultSchema>;

export function parseQuoteAcceptanceResult(value: unknown): QuoteAcceptanceResult | null {
  const parsed = quoteAcceptanceResultSchema.safeParse(value);
  return parsed.success ? parsed.data : null;
}
