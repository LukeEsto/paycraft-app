"use server";

import { redirect } from "next/navigation";
import { tradeRegistrationSchema } from "@/lib/auth/registration-schema";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const TERMS_VERSION = "feasibility-v1";
const PRIVACY_VERSION = "feasibility-v1";

export interface RegistrationState {
  message?: string;
  errors?: Record<string, string[]>;
}

export async function registerTrade(
  _previousState: RegistrationState,
  formData: FormData,
): Promise<RegistrationState> {
  const parsed = tradeRegistrationSchema.safeParse({
    fullName: formData.get("fullName"),
    tradingName: formData.get("tradingName"),
    primaryTrade: formData.get("primaryTrade"),
    businessType: formData.get("businessType"),
    email: formData.get("email"),
    phone: formData.get("phone"),
    password: formData.get("password"),
    termsAccepted: formData.get("termsAccepted") === "on",
    privacyAccepted: formData.get("privacyAccepted") === "on",
  });

  if (!parsed.success) {
    return { errors: parsed.error.flatten().fieldErrors };
  }

  const values = parsed.data;
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.signUp({
    email: values.email,
    password: values.password,
    options: {
      data: {
        account_type: "TRADESPERSON",
        full_name: values.fullName,
        phone: values.phone,
        trading_name: values.tradingName,
        primary_trade: values.primaryTrade,
        business_type: values.businessType,
        terms_accepted: true,
        privacy_accepted: true,
        terms_version: TERMS_VERSION,
        privacy_version: PRIVACY_VERSION,
      },
    },
  });

  if (error) {
    return {
      message: error.message.toLowerCase().includes("already")
        ? "An account with this email already exists."
        : "We could not create your account. Please check your details and try again.",
    };
  }

  if (!data.session) redirect("/register/check-email");
  redirect("/dashboard");
}
