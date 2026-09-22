# ADR-002: Secure customer quote access

Status: Accepted for the feasibility trial

## Decision

Customer quote links use at least 32 random bytes encoded as an opaque token. Only a peppered
SHA-256 hash is stored. Links expire and can be revoked or consumed. Viewing safe quote content and
performing an attributable acceptance are separate permissions.

Before acceptance, the customer verifies control of the intended email address. During this trial,
the verification message is delivered to a development-only mock outbox.

## Security requirements

- Invite tokens must not be written to application logs, audit metadata or analytics.
- Invalid and expired links return generic responses.
- Acceptance is server-side, transactional and idempotent.
- No anonymous direct-table policy is granted for invite resolution.
- Customer quote routes send `noindex` headers.
