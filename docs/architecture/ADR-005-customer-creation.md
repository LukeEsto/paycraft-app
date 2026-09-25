# ADR-005: Transactional, business-scoped customer creation

## Status

Accepted for the feasibility build.

## Decision

Authenticated tradespeople create customers through the `create_customer` database function. The
function verifies membership of the supplied business, creates the customer and appends a
`CUSTOMER_CREATED` audit event in one transaction. It does not accept an actor ID from the caller.

Customer reads remain protected by row-level security and are explicitly filtered to the current
business in the server-side data access layer. Administrators can inspect customers under the
existing read policy but cannot use this function to create customers for another business.

## Consequences

- A failed audit insert also rolls back the customer insert.
- Cross-business writes are rejected even if a caller tampers with request data.
- Customer contact details are not copied into audit metadata.
- The function and its isolation contract require migration tests in a local Supabase environment.
