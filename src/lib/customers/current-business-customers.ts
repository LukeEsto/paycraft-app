import "server-only";

import { requireCurrentTrade } from "@/lib/auth/current-trade";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export interface BusinessCustomer {
  id: string;
  fullName: string;
  email: string;
  phone: string | null;
  createdAt: string;
}

export async function getCurrentBusinessCustomers(): Promise<BusinessCustomer[]> {
  const trade = await requireCurrentTrade();
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("customers")
    .select("id, full_name, email, phone, created_at")
    .eq("business_id", trade.businessId)
    .order("created_at", { ascending: false });

  if (error) throw new Error("Your customers could not be loaded.");

  return (data ?? []).map((customer) => ({
    id: customer.id,
    fullName: customer.full_name,
    email: customer.email,
    phone: customer.phone,
    createdAt: customer.created_at,
  }));
}
