# ADR-006: Transactional versioned quote creation

## Status

Accepted for the feasibility build.

## Decision

Draft quotes are created through the `create_quote` database function. It verifies the authenticated
user's business membership and that the selected customer belongs to the same business. It then
creates the quote, immutable first version, calculated line items and `QUOTE_CREATED` audit event in
one transaction.

The database calculates every line total and the quote total from validated quantity and unit-price
inputs. Callers cannot supply a trusted total, actor ID, version number or quote status. Direct inserts
and updates to quote tables are removed from authenticated RLS policies; later lifecycle changes must
use narrowly scoped transactional functions.

## Consequences

- Cross-business customer references are rejected inside the database.
- A failed version, item or audit insert rolls back the complete quote.
- Existing quote and item read policies continue to support business members and administrators.
- Quote delivery, invite creation and status transition to `SENT` remain a separate bounded feature.
