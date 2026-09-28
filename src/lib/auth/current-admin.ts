import "server-only";

import { cache } from "react";
import { notFound } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export interface CurrentAdmin {
  userId: string;
  email: string;
  fullName: string;
}

export const requireCurrentAdmin = cache(async (): Promise<CurrentAdmin> => {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) notFound();

  const [{ data: role }, { data: profile }] = await Promise.all([
    supabase
      .from("user_roles")
      .select("role")
      .eq("user_id", user.id)
      .eq("role", "ADMIN")
      .maybeSingle(),
    supabase.from("profiles").select("full_name").eq("id", user.id).maybeSingle(),
  ]);

  if (!role || !profile) notFound();

  return {
    userId: user.id,
    email: user.email ?? "",
    fullName: profile.full_name,
  };
});
