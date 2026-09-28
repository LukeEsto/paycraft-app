import "server-only";

import { requireCurrentAdmin, type CurrentAdmin } from "@/lib/auth/current-admin";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import {
  ADMIN_AUDIT_PAGE_SIZE,
  normalizeSafeAuditMetadata,
  type AdminAuditQuery,
  type MaterialAuditEventType,
} from "@/lib/admin/audit-query";

interface AdminAuditRow {
  id: string;
  event_type: MaterialAuditEventType;
  occurred_at: string;
  business_id: string | null;
  business_name: string | null;
  actor_type: string;
  actor_id: string | null;
  entity_type: string;
  entity_id: string;
  metadata: unknown;
}

export interface AdminAuditEvent {
  id: string;
  eventType: MaterialAuditEventType;
  occurredAt: string;
  businessId: string | null;
  businessName: string | null;
  actorType: string;
  actorId: string | null;
  entityType: string;
  entityId: string;
  metadata: Record<string, unknown>;
}

export interface AdminAuditPage {
  admin: CurrentAdmin;
  events: AdminAuditEvent[];
  page: number;
  pageCount: number;
  totalCount: number;
}

export async function getAdminAuditPage(query: AdminAuditQuery): Promise<AdminAuditPage> {
  const admin = await requireCurrentAdmin();
  const supabase = await createSupabaseServerClient();
  const from = (query.page - 1) * ADMIN_AUDIT_PAGE_SIZE;
  const to = from + ADMIN_AUDIT_PAGE_SIZE - 1;

  let request = supabase
    .from("admin_audit_feed")
    .select(
      "id, event_type, occurred_at, business_id, business_name, actor_type, actor_id, entity_type, entity_id, metadata",
      { count: "exact" },
    )
    .order("occurred_at", { ascending: false })
    .order("id", { ascending: false })
    .range(from, to);

  if (query.eventType) request = request.eq("event_type", query.eventType);

  const { data, error, count } = await request;
  if (error) throw new Error("The audit feed could not be loaded.");

  const totalCount = count ?? 0;

  return {
    admin,
    events: ((data ?? []) as unknown as AdminAuditRow[]).map((event) => ({
      id: event.id,
      eventType: event.event_type,
      occurredAt: event.occurred_at,
      businessId: event.business_id,
      businessName: event.business_name,
      actorType: event.actor_type,
      actorId: event.actor_id,
      entityType: event.entity_type,
      entityId: event.entity_id,
      metadata: normalizeSafeAuditMetadata(event.metadata),
    })),
    page: query.page,
    pageCount: Math.max(1, Math.ceil(totalCount / ADMIN_AUDIT_PAGE_SIZE)),
    totalCount,
  };
}
