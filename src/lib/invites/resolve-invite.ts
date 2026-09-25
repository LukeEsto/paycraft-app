import "server-only";

import { hashInviteToken } from "@/lib/invites/token";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export interface PublicQuoteItem {
  description: string;
  quantity: number;
  unit_amount_pence: number;
  line_total_pence: number;
}

export interface PublicQuote {
  quote_id: string;
  trading_name: string;
  customer_name: string;
  job_title: string;
  scope: string;
  total_pence: number;
  currency: "GBP";
  items: PublicQuoteItem[];
}

function invitePepper(): string {
  const pepper = process.env.INVITE_TOKEN_PEPPER;
  if (!pepper) throw new Error("INVITE_TOKEN_PEPPER is not configured.");
  return pepper;
}

export async function resolveInviteToken(token: string): Promise<PublicQuote | null> {
  if (!/^[A-Za-z0-9_-]{43}$/.test(token)) return null;

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("resolve_quote_invite", {
    candidate_token_hash: hashInviteToken(token, invitePepper()),
  });

  if (error || !data) return null;
  return data as PublicQuote;
}
