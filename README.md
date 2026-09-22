# PayCraft Phase 1 feasibility build

This repository is intentionally limited to proving:

`trade registration -> customer -> quote -> secure customer access -> acceptance -> dashboard -> admin audit`

It is not the complete MVP. Payments and notifications are mocked, and no money is moved.

## Prerequisites

- Node.js 22 or newer (CI uses Node 24)
- npm
- Supabase CLI
- Docker or another Supabase-supported container runtime

## Application setup

```bash
cp .env.example .env.local
npm install
supabase start
npm run dev
```

Use the local keys printed by `supabase start` in `.env.local`. Generate a unique
`INVITE_TOKEN_PEPPER` of at least 32 random characters. Never commit `.env.local`.

## Checks

```bash
npm run lint
npm run typecheck
npm run test
npm run build
npx playwright install chromium
npm run test:e2e
```

Database/RLS and full vertical-slice E2E tests are introduced alongside the feature implementation.
The current Work execution environment does not include Docker, so migration application must also
be verified in a developer environment with local Supabase. Its network policy also prevented the
Playwright browser binary from downloading; CI installs Chromium before running the E2E test.

## Architecture

See `docs/architecture/` for recorded decisions. Schema changes must use SQL migrations under
`supabase/migrations/`; direct dashboard-only schema edits are not accepted.

## Security boundary

- Service-role credentials are server-only.
- Customer invite tokens are hashed before storage.
- Accepted quote versions and audit events are immutable.
- User-facing tables use RLS.
- Payment status does not represent money held by PayCraft.

## Current scope

Sprint 0 provides the application shell, design tokens, schema, RLS baseline, provider abstractions,
quality checks and documentation. The first bounded feature adds tradesperson registration, atomic
business onboarding, versioned consent records, audit events and a protected Jobs dashboard shell.
Customer and quote features remain outside the current implementation.
