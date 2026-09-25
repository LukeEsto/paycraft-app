"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireCurrentTrade } from "@/lib/auth/current-trade";
import { customerSchema } from "@/lib/customers/customer-schema";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export interface CustomerState {
  message?: string;
  errors?: Record<string, string[]>;
}

export async function createCustomer(
  _previousState: CustomerState,
  formData: FormData,
): Promise<CustomerState> {
  const parsed = customerSchema.safeParse({
    fullName: formData.get("fullName"),
    email: formData.get("email"),
    phone: formData.get("phone"),
  });

  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors };

  const trade = await requireCurrentTrade();
  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.rpc("create_customer", {
    target_business_id: trade.businessId,
    customer_full_name: parsed.data.fullName,
    customer_email: parsed.data.email,
    customer_phone: parsed.data.phone || null,
  });

  if (error) {
    return { message: "We could not create this customer. Please check the details and try again." };
  }

  revalidatePath("/dashboard");
  redirect("/dashboard?customer=created");
}
