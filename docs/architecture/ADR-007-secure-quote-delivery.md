# ADR-007: Secure mock quote delivery

## Status

Accepted for the feasibility build.

## Decision

Sending a quote creates a 256-bit opaque token in the server action and stores only its peppered
SHA-256 hash. The `send_quote` database function verifies business ownership and draft status,
creates a seven-day customer invite, transitions the quote to `SENT` and appends `QUOTE_SENT` in one
transaction. The customer email is taken from the tenant-owned customer record rather than caller
input.

The feasibility build uses only `MockNotificationProvider`. It returns the customer link to the
authenticated tradesperson as a development delivery preview. The raw token is never stored in the
database, audit metadata or application logs.

Public resolution hashes the candidate token server-side and calls `resolve_quote_invite`. The
function returns only quote-display fields, records the first view once, moves `SENT` to `VIEWED`,
and appends `QUOTE_VIEWED`. Invalid, expired, revoked and consumed links all produce the same result.

## Consequences

- There is no anonymous table access; the public capability is limited to one database function.
- Customer contact details and token hashes are not returned by public resolution.
- The public page is dynamic and marked `noindex, nofollow`.
- Live email or SMS, resend, verification and acceptance remain separate work packages.
