"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireCurrentTrade } from "@/lib/auth/current-trade";
import { createInviteToken, hashInviteToken } from "@/lib/invites/token";
import { getNotificationProvider } from "@/lib/notifications/provider";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const sendQuoteSchema = z.object({ quoteId: z.uuid() });
const INVITE_LIFETIME_DAYS = 7;

export interface SendQuoteState {
  message?: string;
  previewLink?: string;
}

function requireConfiguration(name: "APP_URL" | "INVITE_TOKEN_PEPPER"): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not configured.`);
  return value;
}

function appUrl(): URL {
  const url = new URL(requireConfiguration("APP_URL"));
  if (url.protocol !== "https:" && !(url.protocol === "http:" && ["localhost", "127.0.0.1"].includes(url.hostname))) {
    throw new Error("APP_URL must use HTTPS outside local development.");
  }
  return url;
}

export async function sendQuote(
  _previousState: SendQuoteState,
  formData: FormData,
): Promise<SendQuoteState> {
  const parsed = sendQuoteSchema.safeParse({ quoteId: formData.get("quoteId") });
  if (!parsed.success) return { message: "This quote could not be selected." };

  const provider = getNotificationProvider();
  const trade = await requireCurrentTrade();
  const supabase = await createSupabaseServerClient();
  const { data, error: quoteError } = await supabase
    .from("quotes")
    .select("status, customers!inner(email)")
    .eq("id", parsed.data.quoteId)
    .eq("business_id", trade.businessId)
    .single();

  if (quoteError || !data || data.status !== "DRAFT") {
    return { message: "Only one of your draft quotes can be sent." };
  }

  const customer = data.customers as unknown as { email: string };
  const rawToken = createInviteToken();
  const expiresAt = new Date(Date.now() + INVITE_LIFETIME_DAYS * 24 * 60 * 60 * 1000);
  const previewLink = new URL(`/q/${rawToken}`, appUrl()).toString();
  const { error } = await supabase.rpc("send_quote", {
    target_business_id: trade.businessId,
    target_quote_id: parsed.data.quoteId,
    invite_token_hash: hashInviteToken(rawToken, requireConfiguration("INVITE_TOKEN_PEPPER")),
    invite_expires_at: expiresAt.toISOString(),
  });

  if (error) return { message: "This quote could not be sent. Refresh the page and try again." };

  await provider.send({
    to: customer.email,
    subject: `${trade.tradingName} sent you a PayCraft quote`,
    text: `Review your quote using this secure link: ${previewLink}`,
  });

  revalidatePath("/dashboard");
  return {
    message: `Mock delivery prepared for ${customer.email}. The link expires in ${INVITE_LIFETIME_DAYS} days.`,
    previewLink,
  };
}
