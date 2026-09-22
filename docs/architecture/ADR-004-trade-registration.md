# ADR-004: Transactional tradesperson registration

Status: Accepted for the feasibility trial

## Decision

Supabase Auth owns credentials and sessions. A restricted `auth.users` insert trigger creates the
PayCraft profile, hard-coded `TRADESPERSON` role, business, owner membership, versioned consent
records and onboarding audit events in the same database transaction.

The public registration action supplies validated metadata but cannot select an admin role. Missing
consent, an unsupported account type or an invalid business type rejects the authentication insert.

## Why

Calling Auth and then separately inserting application records could leave a half-created account if
the second operation failed. The database trigger makes the initial identity and business records
atomic while leaving credentials within the mature authentication provider.

## Security constraints

- The trigger is `security definer` with an empty search path.
- Public execution on the trigger function is revoked.
- The role is fixed to `TRADESPERSON`; client metadata cannot grant admin access.
- Passwords never enter the application database or audit log.
- Consent policy versions are recorded rather than only storing a boolean.
- Dashboard data is loaded through the server-only data-access layer and remains protected by RLS.
