import { z } from "zod";

export const businessTypes = ["LIMITED_COMPANY", "SOLE_TRADER", "PARTNERSHIP", "OTHER"] as const;

export const tradeRegistrationSchema = z.object({
  fullName: z.string().trim().min(2, "Enter your full name.").max(120),
  tradingName: z.string().trim().min(2, "Enter your company or trading name.").max(160),
  primaryTrade: z.string().trim().min(2, "Select your primary trade.").max(100),
  businessType: z.enum(businessTypes, { error: "Select your business type." }),
  email: z.string().trim().toLowerCase().pipe(z.email("Enter a valid email address.")),
  phone: z.string().trim().min(7, "Enter a valid phone number.").max(30),
  password: z
    .string()
    .min(12, "Use at least 12 characters.")
    .regex(/[a-z]/, "Include a lowercase letter.")
    .regex(/[A-Z]/, "Include an uppercase letter.")
    .regex(/[0-9]/, "Include a number.")
    .regex(/[^A-Za-z0-9]/, "Include a special character."),
  termsAccepted: z.literal(true, { error: "Accept the Terms to continue." }),
  privacyAccepted: z.literal(true, { error: "Accept the Privacy Notice to continue." }),
});

export type TradeRegistration = z.infer<typeof tradeRegistrationSchema>;
