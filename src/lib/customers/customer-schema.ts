import { z } from "zod";

export const customerSchema = z.object({
  fullName: z.string().trim().min(2, "Enter the customer name.").max(120),
  email: z.string().trim().toLowerCase().pipe(z.email("Enter a valid email address.")),
  phone: z
    .string()
    .trim()
    .max(30, "Use no more than 30 characters.")
    .refine((value) => value.length === 0 || value.length >= 7, "Enter a valid phone number."),
});

export type CustomerInput = z.infer<typeof customerSchema>;
