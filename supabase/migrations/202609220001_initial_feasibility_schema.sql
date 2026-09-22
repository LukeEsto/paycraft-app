create extension if not exists pgcrypto;

create type public.app_role as enum ('TRADESPERSON', 'ADMIN');
create type public.business_type as enum ('LIMITED_COMPANY', 'SOLE_TRADER', 'PARTNERSHIP', 'OTHER');
create type public.quote_status as enum ('DRAFT', 'SENT', 'VIEWED', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'CANCELLED');
create type public.job_status as enum ('PENDING_START', 'ACTIVE', 'AWAITING_CUSTOMER_REVIEW', 'ISSUE_RAISED', 'ON_HOLD', 'COMPLETED', 'CANCELLED');
create type public.payment_status as enum (
  'NOT_STARTED', 'AWAITING_CUSTOMER_ACTION', 'PROCESSING', 'CONFIRMED',
  'PARTIALLY_CONFIRMED', 'FAILED', 'CANCELLED', 'REFUND_PENDING',
  'PARTIALLY_REFUNDED', 'REFUNDED', 'DISPUTED'
);
create type public.actor_type as enum ('USER', 'CUSTOMER', 'ADMIN', 'SYSTEM');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 1 and 120),
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table public.business_profiles (
  id uuid primary key default gen_random_uuid(),
  trading_name text not null check (char_length(trading_name) between 1 and 160),
  primary_trade text not null check (char_length(primary_trade) between 1 and 100),
  business_type public.business_type not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.business_memberships (
  business_id uuid not null references public.business_profiles(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  membership_role text not null default 'OWNER' check (membership_role in ('OWNER')),
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);

create table public.consent_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  consent_type text not null check (consent_type in ('TERMS', 'PRIVACY')),
  policy_version text not null,
  accepted_at timestamptz not null default now(),
  unique (user_id, consent_type, policy_version)
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.business_profiles(id) on delete restrict,
  full_name text not null check (char_length(full_name) between 1 and 120),
  email text not null check (email = lower(email)),
  phone text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.business_profiles(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  status public.quote_status not null default 'DRAFT',
  current_version integer not null default 1 check (current_version > 0),
  accepted_version_id uuid,
  accepted_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'ACCEPTED') = (accepted_at is not null))
);

create table public.quote_versions (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete restrict,
  version_number integer not null check (version_number > 0),
  job_title text not null check (char_length(job_title) between 1 and 160),
  scope text not null check (char_length(scope) between 1 and 10000),
  total_pence integer not null check (total_pence > 0),
  currency text not null default 'GBP' check (currency = 'GBP'),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (quote_id, version_number)
);

alter table public.quotes
  add constraint quotes_accepted_version_fk
  foreign key (accepted_version_id) references public.quote_versions(id) on delete restrict;

create table public.quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_version_id uuid not null references public.quote_versions(id) on delete cascade,
  sequence integer not null check (sequence > 0),
  description text not null check (char_length(description) between 1 and 1000),
  quantity numeric(12, 3) not null default 1 check (quantity > 0),
  unit_amount_pence integer not null check (unit_amount_pence >= 0),
  line_total_pence integer not null check (line_total_pence >= 0),
  unique (quote_version_id, sequence)
);

create table public.customer_invites (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete restrict,
  token_hash text not null unique check (char_length(token_hash) = 64),
  intended_email text not null check (intended_email = lower(intended_email)),
  expires_at timestamptz not null,
  viewed_at timestamptz,
  verified_at timestamptz,
  consumed_at timestamptz,
  revoked_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (expires_at > created_at)
);

create table public.customer_verifications (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.customer_invites(id) on delete cascade,
  code_hash text not null check (char_length(code_hash) = 64),
  expires_at timestamptz not null,
  verified_at timestamptz,
  attempt_count integer not null default 0 check (attempt_count between 0 and 10),
  created_at timestamptz not null default now()
);

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.business_profiles(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  quote_id uuid not null unique references public.quotes(id) on delete restrict,
  accepted_quote_version_id uuid not null references public.quote_versions(id) on delete restrict,
  status public.job_status not null default 'PENDING_START',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.payment_records (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null unique references public.jobs(id) on delete restrict,
  provider_name text not null default 'mock' check (provider_name = 'mock'),
  provider_reference text,
  status public.payment_status not null default 'NOT_STARTED',
  amount_pence integer not null check (amount_pence > 0),
  currency text not null default 'GBP' check (currency = 'GBP'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.business_profiles(id) on delete restrict,
  event_type text not null check (char_length(event_type) between 1 and 100),
  actor_type public.actor_type not null,
  actor_id uuid,
  entity_type text not null check (char_length(entity_type) between 1 and 50),
  entity_id uuid not null,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index customers_business_id_idx on public.customers(business_id);
create index quotes_business_status_idx on public.quotes(business_id, status);
create index quotes_customer_id_idx on public.quotes(customer_id);
create index quote_versions_quote_id_idx on public.quote_versions(quote_id);
create index jobs_business_status_idx on public.jobs(business_id, status);
create index audit_events_entity_idx on public.audit_events(entity_type, entity_id, occurred_at desc);
create index audit_events_business_idx on public.audit_events(business_id, occurred_at desc);

comment on table public.payment_records is 'Neutral provider status only. Never represents funds held by PayCraft.';
comment on column public.customer_invites.token_hash is 'SHA-256 hash of an opaque invite token; raw tokens must not be stored.';
