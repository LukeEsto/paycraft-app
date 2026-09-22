import "server-only";

import { cache } from "react";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export interface CurrentTrade {
  userId: string;
  email: string;
  fullName: string;
  businessId: string;
  tradingName: string;
  primaryTrade: string;
}

export const requireCurrentTrade = cache(async (): Promise<CurrentTrade> => {
  const supabase = await createSupabaseServerClient();
  const { data: { user }, error: authError } = await supabase.auth.getUser();

  if (authError || !user) redirect("/register");

  const { data, error } = await supabase
    .from("business_memberships")
    .select("business_id, business_profiles!inner(trading_name, primary_trade)")
    .eq("user_id", user.id)
    .single();

  if (error || !data) throw new Error("Your PayCraft business profile could not be loaded.");

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("full_name")
    .eq("id", user.id)
    .single();

  if (profileError || !profile) throw new Error("Your PayCraft profile could not be loaded.");

  const business = data.business_profiles as unknown as { trading_name: string; primary_trade: string };

  return {
    userId: user.id,
    email: user.email ?? "",
    fullName: profile.full_name,
    businessId: data.business_id,
    tradingName: business.trading_name,
    primaryTrade: business.primary_trade,
  };
});
