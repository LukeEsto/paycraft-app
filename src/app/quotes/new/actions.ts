"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireCurrentTrade } from "@/lib/auth/current-trade";
import { quoteSchema } from "@/lib/quotes/quote-schema";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export interface QuoteState {
  message?: string;
  errors?: Record<string, string[]>;
}

export async function createQuote(
  _previousState: QuoteState,
  formData: FormData,
): Promise<QuoteState> {
  const descriptions = formData.getAll("itemDescription");
  const quantities = formData.getAll("itemQuantity");
  const unitAmounts = formData.getAll("itemUnitAmount");
  const itemCount = Math.max(descriptions.length, quantities.length, unitAmounts.length);

  const parsed = quoteSchema.safeParse({
    customerId: formData.get("customerId"),
    jobTitle: formData.get("jobTitle"),
    scope: formData.get("scope"),
    items: Array.from({ length: itemCount }, (_, index) => ({
      description: descriptions[index],
      quantity: quantities[index],
      unitAmount: unitAmounts[index],
    })),
  });

  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };

  const trade = await requireCurrentTrade();
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc("create_quote", {
    target_business_id: trade.businessId,
    target_customer_id: parsed.data.customerId,
    quote_job_title: parsed.data.jobTitle,
    quote_scope: parsed.data.scope,
    quote_items: parsed.data.items.map((item) => ({
      description: item.description,
      quantity: item.quantity,
      unit_amount_pence: item.unitAmount,
    })),
  });

  if (error) return { message: "We could not create this quote. Please check the details and try again." };

  revalidatePath("/dashboard");
  redirect("/dashboard?quote=created");
}
