import type { Metadata } from "next";
import Link from "next/link";
import {
  MATERIAL_AUDIT_EVENT_TYPES,
  parseAdminAuditQuery,
  type AdminAuditSearchParams,
} from "@/lib/admin/audit-query";
import { getAdminAuditPage } from "@/lib/admin/audit";

export const metadata: Metadata = {
  title: "Audit events | PayCraft Admin",
  robots: { index: false, follow: false },
};

interface AdminAuditPageProps {
  searchParams: Promise<AdminAuditSearchParams>;
}

function displayEventType(eventType: string): string {
  return eventType.toLowerCase().split("_").map((part) => (
    part.charAt(0).toUpperCase() + part.slice(1)
  )).join(" ");
}

function pageHref(page: number, eventType?: string) {
  return {
    pathname: "/admin/audit" as const,
    query: { page: String(page), ...(eventType ? { event: eventType } : {}) },
  };
}

export default async function AdminAuditPage({ searchParams }: AdminAuditPageProps) {
  const query = parseAdminAuditQuery(await searchParams);
  const result = await getAdminAuditPage(query);

  return (
    <main className="admin-shell">
      <header className="admin-header">
        <div>
          <div className="brand">PayCraft</div>
          <p>Internal audit</p>
        </div>
        <div className="user-chip" aria-label={`Signed in as ${result.admin.fullName}`}>
          {result.admin.fullName}
        </div>
      </header>

      <section className="admin-content" aria-labelledby="audit-title">
        <div>
          <div className="eyebrow">Read-only feasibility view</div>
          <h1 id="audit-title" className="admin-title">Material audit events</h1>
          <p>Authoritative activity across PayCraft businesses. This route cannot change application state.</p>
        </div>

        <form className="audit-filters" method="get">
          <div className="field">
            <label htmlFor="event">Event type</label>
            <select id="event" name="event" defaultValue={query.eventType ?? ""}>
              <option value="">All material events</option>
              {MATERIAL_AUDIT_EVENT_TYPES.map((eventType) => (
                <option key={eventType} value={eventType}>{displayEventType(eventType)}</option>
              ))}
            </select>
          </div>
          <button className="button" type="submit">Filter</button>
        </form>

        <div className="audit-summary" aria-live="polite">
          <strong>{result.totalCount}</strong> {result.totalCount === 1 ? "event" : "events"}
          <span>Page {result.page} of {result.pageCount}</span>
        </div>

        {result.events.length === 0 ? (
          <div className="empty-state compact-empty">
            <h2>No matching events</h2>
            <p>Change the event filter or return to the first page.</p>
          </div>
        ) : (
          <ol className="audit-list">
            {result.events.map((event) => (
              <li key={event.id} className="audit-event">
                <div className="audit-event-heading">
                  <strong>{displayEventType(event.eventType)}</strong>
                  <time dateTime={event.occurredAt}>{new Date(event.occurredAt).toLocaleString("en-GB")}</time>
                </div>
                <dl>
                  <div><dt>Business</dt><dd>{event.businessName ?? "Platform"}</dd></div>
                  <div><dt>Actor</dt><dd>{event.actorType}{event.actorId ? ` · ${event.actorId}` : ""}</dd></div>
                  <div><dt>Entity</dt><dd>{event.entityType} · {event.entityId}</dd></div>
                </dl>
                {Object.keys(event.metadata).length > 0 && (
                  <details>
                    <summary>Safe event metadata</summary>
                    <pre>{JSON.stringify(event.metadata, null, 2)}</pre>
                  </details>
                )}
              </li>
            ))}
          </ol>
        )}

        <nav className="audit-pagination" aria-label="Audit pagination">
          {result.page > 1 ? (
            <Link className="button secondary-button" href={pageHref(result.page - 1, query.eventType)}>Previous</Link>
          ) : <span />}
          {result.page < result.pageCount && (
            <Link className="button secondary-button" href={pageHref(result.page + 1, query.eventType)}>Next</Link>
          )}
        </nav>
      </section>
    </main>
  );
}
