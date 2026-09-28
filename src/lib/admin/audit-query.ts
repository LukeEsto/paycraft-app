export const ADMIN_AUDIT_PAGE_SIZE = 25;

export const MATERIAL_AUDIT_EVENT_TYPES = [
  "ACCOUNT_CREATED",
  "TRADE_ONBOARDING_COMPLETED",
  "CUSTOMER_CREATED",
  "QUOTE_CREATED",
  "QUOTE_SENT",
  "QUOTE_VIEWED",
  "CUSTOMER_EMAIL_VERIFICATION_STARTED",
  "CUSTOMER_EMAIL_VERIFICATION_FAILED",
  "CUSTOMER_EMAIL_VERIFIED",
  "QUOTE_ACCEPTED",
  "ADMIN_ROLE_GRANTED",
] as const;

export type MaterialAuditEventType = (typeof MATERIAL_AUDIT_EVENT_TYPES)[number];

export interface AdminAuditSearchParams {
  event?: string | string[];
  page?: string | string[];
}

export interface AdminAuditQuery {
  eventType?: MaterialAuditEventType;
  page: number;
}

const SAFE_METADATA_KEYS = new Set([
  "primary_trade",
  "version",
  "item_count",
  "total_pence",
  "invite_id",
  "quote_version_id",
  "verification_id",
  "expires_at",
  "attempt_count",
  "grant_expires_at",
  "accepted_version_id",
  "accepted_version_number",
  "accepted_amount_pence",
  "currency",
  "accepted_at",
]);

function first(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

export function parseAdminAuditQuery(params: AdminAuditSearchParams): AdminAuditQuery {
  const requestedEvent = first(params.event);
  const eventType = MATERIAL_AUDIT_EVENT_TYPES.find((event) => event === requestedEvent);
  const requestedPage = first(params.page);
  const page = requestedPage && /^[1-9]\d*$/.test(requestedPage)
    ? Math.min(Number(requestedPage), 10_000)
    : 1;

  return { eventType, page };
}

export function normalizeSafeAuditMetadata(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};

  return Object.fromEntries(
    Object.entries(value).filter(([key]) => SAFE_METADATA_KEYS.has(key)),
  );
}
