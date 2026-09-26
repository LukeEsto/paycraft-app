# ADR-009: Verified, version-bound quote acceptance

## Status

Accepted for the feasibility build.

## Decision

Quote acceptance is a single security-definer database transaction. The public server action hashes
the original invite capability and the HttpOnly F-07 verification grant, validates the displayed
quote/version/amount fields, and submits those values to `accept_quote`. Client state is never treated
as acceptance authority.

Each invite now records the exact immutable quote version delivered by `send_quote`. Resolution and
acceptance require that version to remain the quote's current version. A change therefore makes the
old link stale rather than silently allowing it to accept replacement scope or pricing.

The transaction locks the invite, verification and quote rows; validates their shared quote context,
expiry, revocation, verification and consumption state; moves the quote to `ACCEPTED`; snapshots the
accepted version, amount, currency and time; consumes the invite and grant; and appends one
`QUOTE_ACCEPTED` event. An exact concurrent/repeat request returns the existing result without another
transition or audit event. All other failures are returned to the customer through one generic message.

## Consequences

- A grant for one quote cannot accept another quote or another tenant's quote.
- Changed, expired, revoked, consumed and unverified quotes cannot be accepted.
- Accepted snapshots and their source quote versions are immutable.
- The confirmation UI reflects the authoritative database result, not submitted hidden fields.
- Acceptance records agreement to the quote only; it does not create a job, contract, signature,
  milestone or payment.
