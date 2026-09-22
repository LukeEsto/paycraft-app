# ADR-001: Application baseline

Status: Accepted for the feasibility trial

## Decision

Use a single Next.js TypeScript application, local Supabase/Postgres, server-side privileged
operations, PostgreSQL Row Level Security and provider interfaces for notifications and payments.

## Why

- It follows the Phase 1 AI Build Specification.
- One repository keeps the feasibility slice understandable and inexpensive.
- PostgreSQL constraints and RLS provide durable isolation that browser checks cannot.
- Provider interfaces prevent mock payment and notification behaviour leaking into domain logic.

## Consequences

- Supabase CLI and a Docker-compatible runtime are required for local database integration tests.
- The browser receives only the public Supabase key. Elevated credentials stay server-side.
- A different payment provider can be introduced later without rewriting quote and job records.

## Rejected for this trial

- Native iOS/Android clients.
- Microservices or a monorepo.
- Live payment, email or SMS integrations.
- SQLite or an in-memory production substitute.
