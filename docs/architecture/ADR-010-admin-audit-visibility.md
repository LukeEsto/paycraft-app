# ADR-010: Explicit, read-only admin audit visibility

## Status

Accepted for the feasibility build.

## Decision

The existing `ADMIN` database role is the sole authority for the internal `/admin/audit` route. Admin
access can be bootstrapped only by a database owner calling `grant_feasibility_admin`; the function
rejects JWT-backed callers, is unavailable to API roles, requires an onboarded user and records the
grant. There is no client-controlled admin claim or application provisioning UI.

The application uses its ordinary cookie-bound, anon-key Supabase client to query a
`security_invoker` view. The view requires `is_admin()`, remains subject to base-table RLS and exposes
only material events plus an allowlist of safe metadata keys. A second application-layer allowlist
provides defence in depth. Raw tokens, verification codes and hashes, contact details and unknown
future metadata are not projected.

The route is a server component with GET-only filtering and pagination. It contains no server action,
mutation RPC, service-role client, support action or impersonation capability.

## Consequences

- Ordinary business users retain their existing tenant-scoped audit reads and receive no rows from
  the cross-business admin view.
- Anonymous and customer-capability access cannot query the view.
- Admins can review cross-business event context but cannot mutate customers, quotes, acceptances or
  append-only audit records through the route.
- Admin provisioning remains a deliberate operator action for the feasibility trial; production role
  governance, reviews and offboarding are separate decisions.
