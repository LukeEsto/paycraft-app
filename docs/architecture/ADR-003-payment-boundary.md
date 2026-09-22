# ADR-003: Payment boundary

Status: Accepted for the feasibility trial

## Decision

Only `MockPaymentProvider` is permitted. The core application stores neutral payment status and a
provider reference; it does not store balances, card data or fields implying that PayCraft has custody.

Quote, job and payment statuses remain independent state models. Quote acceptance may create a job
and a `NOT_STARTED` payment record, but it never confirms or releases a payment.

## Prohibited wording and behaviour

- PayCraft holds or safeguards funds.
- PayCraft releases money.
- Guaranteed payment, escrow protection or workmanship.
- Any claim that PayCraft is FCA authorised.
