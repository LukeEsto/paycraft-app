import "server-only";

import { requireCurrentTrade } from "@/lib/auth/current-trade";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export interface BusinessQuote {
  id: string;
  status: string;
  customerName: string;
  jobTitle: string;
  totalPence: number;
}

interface QuoteRow {
  id: string;
  status: string;
  current_version: number;
  customers: { full_name: string };
  quote_versions: Array<{ job_title: string; total_pence: number; version_number: number }>;
}

export async function getCurrentBusinessQuotes(): Promise<BusinessQuote[]> {
  const trade = await requireCurrentTrade();
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("quotes")
    .select("id, status, current_version, customers!inner(full_name), quote_versions(job_title, total_pence, version_number)")
    .eq("business_id", trade.businessId)
    .order("created_at", { ascending: false });

  if (error) throw new Error("Your quotes could not be loaded.");

  return ((data ?? []) as unknown as QuoteRow[]).map((quote) => {
    const version = quote.quote_versions.find((entry) => entry.version_number === quote.current_version);
    if (!version) throw new Error("A quote version could not be loaded.");
    return {
      id: quote.id,
      status: quote.status,
      customerName: quote.customers.full_name,
      jobTitle: version.job_title,
      totalPence: version.total_pence,
    };
  });
}

export function formatGbp(pence: number): string {
  return new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP" }).format(pence / 100);
}
