# ADR-008: Invite-bound customer email verification

## Status

Accepted for the feasibility build.

## Decision

A customer can start one email-verification challenge only through a valid, unexpired quote invite.
The server generates a cryptographically secure six-digit code, hashes it with the invite context and
the server-side pepper, and stores only that hash. The challenge expires after ten minutes and allows
five attempts.

Successful verification atomically marks the challenge and invite as verified, appends a
`CUSTOMER_EMAIL_VERIFIED` audit event, and stores the hash of a separate 256-bit verification grant.
The raw grant is held for thirty minutes in an HttpOnly, SameSite cookie. Later consequential actions
must prove both the invite token and the grant; client-rendered state is never authority.

The notification provider remains the in-memory mock. For feasibility testing, the raw code is
returned as an explicitly labelled mock-delivery receipt after the provider is called. It is never
stored in the database, audit log or application log. A production delivery implementation must
remove that receipt and deliver the code out of band.

## Consequences

- The verification code can succeed once and cannot be replayed to mint another grant.
- A grant is bound to one invite and quote and cannot authorise another tenant's quote.
- Incorrect attempts are counted and audited without recording the submitted code.
- Invalid, expired, exhausted and replayed challenges return the same public failure message.
- Resend, recovery, customer accounts and quote acceptance remain outside this package.
