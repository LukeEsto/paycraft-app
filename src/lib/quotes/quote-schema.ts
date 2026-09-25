import { z } from "zod";

const moneyPattern = /^\d{1,7}(?:\.\d{1,2})?$/;
const quantityPattern = /^\d{1,4}(?:\.\d{1,3})?$/;

export function poundsToPence(value: string): number {
  const [pounds, pennies = ""] = value.split(".");
  return Number(pounds) * 100 + Number(pennies.padEnd(2, "0"));
}

export const quoteItemSchema = z.object({
  description: z.string().trim().min(1, "Enter an item description.").max(1000),
  quantity: z
    .string()
    .trim()
    .regex(quantityPattern, "Enter a quantity with up to three decimal places.")
    .refine((value) => Number(value) > 0 && Number(value) <= 10000, "Quantity must be greater than zero."),
  unitAmount: z
    .string()
    .trim()
    .regex(moneyPattern, "Enter a valid amount with up to two decimal places.")
    .transform(poundsToPence),
});

export const quoteSchema = z.object({
  customerId: z.uuid("Select a customer."),
  jobTitle: z.string().trim().min(2, "Enter a job title.").max(160),
  scope: z.string().trim().min(10, "Describe the work included in this quote.").max(10000),
  items: z.array(quoteItemSchema).min(1, "Add at least one quote item.").max(25),
});

export type QuoteInput = z.infer<typeof quoteSchema>;
