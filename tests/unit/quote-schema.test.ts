import { describe, expect, it } from "vitest";
import { poundsToPence, quoteSchema } from "@/lib/quotes/quote-schema";

const validQuote = {
  customerId: "3a2f7d72-b326-4c5d-9fbf-18fbad700e07",
  jobTitle: "Kitchen rewiring",
  scope: "Replace the consumer unit and rewire the kitchen.",
  items: [{ description: "Electrical labour", quantity: "2.5", unitAmount: "240.50" }],
};

describe("quote validation", () => {
  it("accepts and normalises a valid draft quote", () => {
    const result = quoteSchema.parse(validQuote);
    expect(result.items[0]).toEqual({ description: "Electrical labour", quantity: "2.5", unitAmount: 24050 });
  });

  it("converts pounds to integer pence without floating-point arithmetic", () => {
    expect(poundsToPence("19.9")).toBe(1990);
    expect(poundsToPence("19.99")).toBe(1999);
  });

  it("rejects excess currency precision", () => {
    const result = quoteSchema.safeParse({ ...validQuote, items: [{ ...validQuote.items[0], unitAmount: "10.999" }] });
    expect(result.success).toBe(false);
  });

  it("requires at least one item and a meaningful scope", () => {
    expect(quoteSchema.safeParse({ ...validQuote, scope: "Short", items: [] }).success).toBe(false);
  });
});
