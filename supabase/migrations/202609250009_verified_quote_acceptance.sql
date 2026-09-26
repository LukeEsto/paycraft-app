alter table public.customer_invites
  add column quote_version_id uuid references public.quote_versions(id) on delete restrict;

update public.customer_invites invite
set quote_version_id = version.id
from public.quotes quote
join public.quote_versions version
  on version.quote_id = quote.id and version.version_number = quote.current_version
where quote.id = invite.quote_id;

alter table public.customer_invites
  alter column quote_version_id set not null;

create index customer_invites_quote_version_id_idx
  on public.customer_invites(quote_version_id);

create or replace function public.guard_accepted_quote_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.quotes quote
    where quote.accepted_version_id = old.id and quote.status = 'ACCEPTED'
  ) then
    raise exception 'Accepted quote versions are immutable';
  end if;

  if exists (
    select 1 from public.customer_invites invite
    where invite.quote_version_id = old.id
  ) then
    raise exception 'Delivered quote versions are immutable';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create or replace function public.guard_delivered_quote_items()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  old_version_id uuid := case when tg_op in ('UPDATE', 'DELETE') then old.quote_version_id else null end;
  new_version_id uuid := case when tg_op in ('INSERT', 'UPDATE') then new.quote_version_id else null end;
begin
  if exists (
    select 1
    from public.customer_invites invite
    where invite.quote_version_id = old_version_id
       or invite.quote_version_id = new_version_id
  ) or exists (
    select 1
    from public.quotes quote
    where quote.status = 'ACCEPTED'
      and (quote.accepted_version_id = old_version_id or quote.accepted_version_id = new_version_id)
  ) then
    raise exception 'Delivered quote items are immutable';
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger quote_items_delivered_immutable
before insert or update or delete on public.quote_items
for each row execute function public.guard_delivered_quote_items();

alter table public.quotes
  add column accepted_amount_pence integer,
  add column accepted_currency text;

update public.quotes quote
set
  accepted_amount_pence = version.total_pence,
  accepted_currency = version.currency
from public.quote_versions version
where quote.status = 'ACCEPTED'
  and quote.accepted_version_id = version.id;

alter table public.quotes
  add constraint quotes_acceptance_snapshot_check
  check (
    (
      status = 'ACCEPTED'
      and accepted_version_id is not null
      and accepted_at is not null
      and accepted_amount_pence > 0
      and accepted_currency = 'GBP'
    )
    or
    (
      status <> 'ACCEPTED'
      and accepted_version_id is null
      and accepted_at is null
      and accepted_amount_pence is null
      and accepted_currency is null
    )
  );

create or replace function public.guard_quote_acceptance_snapshot()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status = 'ACCEPTED' and (
    new.status is distinct from old.status
    or new.business_id is distinct from old.business_id
    or new.customer_id is distinct from old.customer_id
    or new.current_version is distinct from old.current_version
    or new.accepted_version_id is distinct from old.accepted_version_id
    or new.accepted_at is distinct from old.accepted_at
    or new.accepted_amount_pence is distinct from old.accepted_amount_pence
    or new.accepted_currency is distinct from old.accepted_currency
  ) then
    raise exception 'Accepted quote snapshot is immutable';
  end if;

  if old.status <> 'ACCEPTED' and new.status = 'ACCEPTED' then
    if coalesce(current_setting('paycraft.accept_quote', true), '') <> 'true' then
      raise exception 'Quote acceptance must use the acceptance function';
    end if;

    if not exists (
      select 1
      from public.quote_versions version
      where version.id = new.accepted_version_id
        and version.quote_id = new.id
        and version.version_number = new.current_version
        and version.total_pence = new.accepted_amount_pence
        and version.currency = new.accepted_currency
    ) then
      raise exception 'Invalid accepted quote snapshot';
    end if;
  end if;

  return new;
end;
$$;

create trigger quotes_acceptance_snapshot_immutable
before update on public.quotes
for each row execute function public.guard_quote_acceptance_snapshot();

create or replace function public.send_quote(
  target_business_id uuid,
  target_quote_id uuid,
  invite_token_hash text,
  invite_expires_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  customer_email text;
  current_version_id uuid;
  new_invite_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.business_memberships membership
    where membership.business_id = target_business_id
      and membership.user_id = current_user_id
  ) then
    raise exception 'Business membership required';
  end if;

  select customer.email, version.id
  into customer_email, current_version_id
  from public.quotes quote
  join public.customers customer on customer.id = quote.customer_id
  join public.quote_versions version
    on version.quote_id = quote.id and version.version_number = quote.current_version
  where quote.id = target_quote_id
    and quote.business_id = target_business_id
    and customer.business_id = target_business_id
    and quote.status = 'DRAFT'
  for update of quote;

  if customer_email is null or current_version_id is null then
    raise exception 'Draft quote not found';
  end if;

  if invite_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid invite token hash';
  end if;

  if invite_expires_at < now() + interval '5 minutes'
     or invite_expires_at > now() + interval '30 days' then
    raise exception 'Invalid invite expiry';
  end if;

  insert into public.customer_invites (
    quote_id, quote_version_id, token_hash, intended_email, expires_at, created_by
  ) values (
    target_quote_id, current_version_id, invite_token_hash, customer_email, invite_expires_at, current_user_id
  )
  returning id into new_invite_id;

  update public.quotes
  set status = 'SENT', updated_at = now()
  where id = target_quote_id;

  insert into public.audit_events (
    business_id, event_type, actor_type, actor_id, entity_type, entity_id, metadata
  ) values (
    target_business_id,
    'QUOTE_SENT',
    'USER',
    current_user_id,
    'QUOTE',
    target_quote_id,
    jsonb_build_object(
      'invite_id', new_invite_id,
      'quote_version_id', current_version_id,
      'expires_at', invite_expires_at
    )
  );

  return new_invite_id;
end;
$$;

create or replace function public.resolve_quote_invite(candidate_token_hash text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  invite_record record;
  quote_items_json jsonb;
begin
  if candidate_token_hash !~ '^[0-9a-f]{64}$' then
    return null;
  end if;

  select
    invite.id as invite_id,
    invite.viewed_at,
    invite.verified_at,
    quote.id as quote_id,
    quote.business_id,
    business.trading_name,
    customer.full_name as customer_name,
    version.id as version_id,
    version.version_number,
    version.job_title,
    version.scope,
    version.total_pence,
    version.currency
  into invite_record
  from public.customer_invites invite
  join public.quotes quote on quote.id = invite.quote_id
  join public.business_profiles business on business.id = quote.business_id
  join public.customers customer on customer.id = quote.customer_id
  join public.quote_versions version
    on version.id = invite.quote_version_id and version.quote_id = quote.id
  where invite.token_hash = candidate_token_hash
    and invite.expires_at > now()
    and invite.revoked_at is null
    and invite.consumed_at is null
    and quote.status in ('SENT', 'VIEWED')
    and quote.current_version = version.version_number
  for update of invite;

  if invite_record.invite_id is null then
    return null;
  end if;

  if invite_record.viewed_at is null then
    update public.customer_invites
    set viewed_at = now()
    where id = invite_record.invite_id;

    update public.quotes
    set status = 'VIEWED', updated_at = now()
    where id = invite_record.quote_id and status = 'SENT';

    insert into public.audit_events (
      business_id, event_type, actor_type, actor_id, entity_type, entity_id, metadata
    ) values (
      invite_record.business_id,
      'QUOTE_VIEWED',
      'CUSTOMER',
      null,
      'QUOTE',
      invite_record.quote_id,
      jsonb_build_object(
        'invite_id', invite_record.invite_id,
        'quote_version_id', invite_record.version_id
      )
    );
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'description', item.description,
        'quantity', item.quantity,
        'unit_amount_pence', item.unit_amount_pence,
        'line_total_pence', item.line_total_pence
      ) order by item.sequence
    ),
    '[]'::jsonb
  ) into quote_items_json
  from public.quote_items item
  where item.quote_version_id = invite_record.version_id;

  return jsonb_build_object(
    'quote_id', invite_record.quote_id,
    'version_id', invite_record.version_id,
    'version_number', invite_record.version_number,
    'trading_name', invite_record.trading_name,
    'customer_name', invite_record.customer_name,
    'job_title', invite_record.job_title,
    'scope', invite_record.scope,
    'total_pence', invite_record.total_pence,
    'currency', invite_record.currency,
    'email_verified', invite_record.verified_at is not null,
    'items', quote_items_json
  );
end;
$$;

create or replace function public.accept_quote(
  candidate_token_hash text,
  candidate_grant_hash text,
  expected_quote_id uuid,
  expected_version_id uuid,
  expected_version_number integer,
  expected_total_pence integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  acceptance_record record;
  acceptance_time timestamptz;
begin
  if candidate_token_hash !~ '^[0-9a-f]{64}$'
     or candidate_grant_hash !~ '^[0-9a-f]{64}$'
     or expected_version_number < 1
     or expected_total_pence < 1 then
    return null;
  end if;

  select
    invite.id as invite_id,
    invite.expires_at as invite_expires_at,
    invite.verified_at as invite_verified_at,
    invite.consumed_at as invite_consumed_at,
    invite.revoked_at as invite_revoked_at,
    verification.id as verification_id,
    verification.verified_at as verification_verified_at,
    verification.grant_expires_at,
    verification.grant_consumed_at,
    quote.id as quote_id,
    quote.business_id,
    quote.status,
    quote.current_version,
    quote.accepted_version_id,
    quote.accepted_at,
    quote.accepted_amount_pence,
    quote.accepted_currency,
    version.id as version_id,
    version.version_number,
    version.total_pence,
    version.currency
  into acceptance_record
  from public.customer_invites invite
  join public.customer_verifications verification on verification.invite_id = invite.id
  join public.quotes quote on quote.id = invite.quote_id
  join public.quote_versions version
    on version.id = invite.quote_version_id and version.quote_id = quote.id
  where invite.token_hash = candidate_token_hash
    and verification.grant_token_hash = candidate_grant_hash
    and quote.id = expected_quote_id
    and version.id = expected_version_id
    and version.version_number = expected_version_number
    and version.total_pence = expected_total_pence
  for update of invite, verification, quote;

  if acceptance_record.invite_id is null then
    return null;
  end if;

  if acceptance_record.status = 'ACCEPTED'
     and acceptance_record.accepted_version_id = acceptance_record.version_id
     and acceptance_record.accepted_amount_pence = acceptance_record.total_pence
     and acceptance_record.accepted_currency = acceptance_record.currency
     and acceptance_record.accepted_at is not null
     and acceptance_record.invite_consumed_at is not null
     and acceptance_record.grant_consumed_at is not null then
    return jsonb_build_object(
      'accepted', true,
      'already_accepted', true,
      'quote_id', acceptance_record.quote_id,
      'accepted_version_id', acceptance_record.version_id,
      'accepted_version_number', acceptance_record.version_number,
      'accepted_amount_pence', acceptance_record.total_pence,
      'currency', acceptance_record.currency,
      'accepted_at', acceptance_record.accepted_at
    );
  end if;

  if acceptance_record.status not in ('SENT', 'VIEWED')
     or acceptance_record.current_version <> acceptance_record.version_number
     or acceptance_record.invite_expires_at <= now()
     or acceptance_record.invite_revoked_at is not null
     or acceptance_record.invite_consumed_at is not null
     or acceptance_record.invite_verified_at is null
     or acceptance_record.verification_verified_at is null
     or acceptance_record.grant_expires_at <= now()
     or acceptance_record.grant_consumed_at is not null then
    return null;
  end if;

  acceptance_time := now();
  perform set_config('paycraft.accept_quote', 'true', true);

  update public.quotes
  set
    status = 'ACCEPTED',
    accepted_version_id = acceptance_record.version_id,
    accepted_at = acceptance_time,
    accepted_amount_pence = acceptance_record.total_pence,
    accepted_currency = acceptance_record.currency,
    updated_at = acceptance_time
  where id = acceptance_record.quote_id;

  perform set_config('paycraft.accept_quote', 'false', true);

  update public.customer_verifications
  set grant_consumed_at = acceptance_time
  where id = acceptance_record.verification_id;

  update public.customer_invites
  set consumed_at = acceptance_time
  where id = acceptance_record.invite_id;

  insert into public.audit_events (
    business_id, event_type, actor_type, actor_id, entity_type, entity_id, metadata
  ) values (
    acceptance_record.business_id,
    'QUOTE_ACCEPTED',
    'CUSTOMER',
    null,
    'QUOTE',
    acceptance_record.quote_id,
    jsonb_build_object(
      'invite_id', acceptance_record.invite_id,
      'verification_id', acceptance_record.verification_id,
      'accepted_version_id', acceptance_record.version_id,
      'accepted_version_number', acceptance_record.version_number,
      'accepted_amount_pence', acceptance_record.total_pence,
      'currency', acceptance_record.currency,
      'accepted_at', acceptance_time
    )
  );

  return jsonb_build_object(
    'accepted', true,
    'already_accepted', false,
    'quote_id', acceptance_record.quote_id,
    'accepted_version_id', acceptance_record.version_id,
    'accepted_version_number', acceptance_record.version_number,
    'accepted_amount_pence', acceptance_record.total_pence,
    'currency', acceptance_record.currency,
    'accepted_at', acceptance_time
  );
end;
$$;

revoke all on function public.accept_quote(text, text, uuid, uuid, integer, integer) from public;
grant execute on function public.accept_quote(text, text, uuid, uuid, integer, integer) to anon, authenticated;

comment on column public.customer_invites.quote_version_id is
  'Immutable quote version presented by this capability; a changed current version invalidates the invite.';
comment on column public.quotes.accepted_amount_pence is
  'Immutable amount snapshot copied from the accepted quote version.';
comment on function public.accept_quote(text, text, uuid, uuid, integer, integer) is
  'Atomically validates an invite and quote-bound verification grant, snapshots acceptance, consumes both capabilities and audits the transition.';
