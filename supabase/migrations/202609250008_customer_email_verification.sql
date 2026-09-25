alter table public.customer_verifications
  add column grant_token_hash text,
  add column grant_expires_at timestamptz,
  add column grant_consumed_at timestamptz,
  add constraint customer_verifications_grant_hash_check
    check (grant_token_hash is null or char_length(grant_token_hash) = 64),
  add constraint customer_verifications_grant_state_check
    check (
      (verified_at is null and grant_token_hash is null and grant_expires_at is null)
      or
      (verified_at is not null and grant_token_hash is not null and grant_expires_at is not null)
    ),
  add constraint customer_verifications_grant_consumption_check
    check (grant_consumed_at is null or verified_at is not null);

create unique index customer_verifications_one_per_invite_idx
  on public.customer_verifications(invite_id);
create unique index customer_verifications_grant_hash_idx
  on public.customer_verifications(grant_token_hash)
  where grant_token_hash is not null;

create or replace function public.start_quote_verification(
  candidate_token_hash text,
  verification_code_hash text,
  verification_expires_at timestamptz
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  invite_record record;
  new_verification_id uuid;
begin
  if candidate_token_hash !~ '^[0-9a-f]{64}$'
     or verification_code_hash !~ '^[0-9a-f]{64}$' then
    return null;
  end if;

  if verification_expires_at < now() + interval '1 minute'
     or verification_expires_at > now() + interval '15 minutes' then
    return null;
  end if;

  select
    i.id as invite_id,
    i.intended_email,
    q.id as quote_id,
    q.business_id
  into invite_record
  from public.customer_invites i
  join public.quotes q on q.id = i.quote_id
  where i.token_hash = candidate_token_hash
    and i.expires_at > now()
    and i.revoked_at is null
    and i.consumed_at is null
    and i.verified_at is null
    and q.status in ('SENT', 'VIEWED')
  for update of i;

  if invite_record.invite_id is null then
    return null;
  end if;

  if exists (
    select 1 from public.customer_verifications v
    where v.invite_id = invite_record.invite_id
  ) then
    return null;
  end if;

  insert into public.customer_verifications (invite_id, code_hash, expires_at)
  values (invite_record.invite_id, verification_code_hash, verification_expires_at)
  returning id into new_verification_id;

  insert into public.audit_events (
    business_id, event_type, actor_type, actor_id, entity_type, entity_id, metadata
  ) values (
    invite_record.business_id,
    'CUSTOMER_EMAIL_VERIFICATION_STARTED',
    'CUSTOMER',
    null,
    'QUOTE',
    invite_record.quote_id,
    jsonb_build_object(
      'invite_id', invite_record.invite_id,
      'verification_id', new_verification_id,
      'expires_at', verification_expires_at
    )
  );

  return invite_record.intended_email;
end;
$$;

create or replace function public.verify_quote_email(
  candidate_token_hash text,
  candidate_code_hash text,
  verification_grant_hash text,
  verification_grant_expires_at timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  verification_record record;
  next_attempt_count integer;
begin
  if candidate_token_hash !~ '^[0-9a-f]{64}$'
     or candidate_code_hash !~ '^[0-9a-f]{64}$'
     or verification_grant_hash !~ '^[0-9a-f]{64}$' then
    return false;
  end if;

  if verification_grant_expires_at < now() + interval '5 minutes'
     or verification_grant_expires_at > now() + interval '2 hours' then
    return false;
  end if;

  select
    v.id as verification_id,
    v.code_hash,
    v.expires_at as verification_expires_at,
    v.verified_at,
    v.attempt_count,
    i.id as invite_id,
    i.verified_at as invite_verified_at,
    q.id as quote_id,
    q.business_id
  into verification_record
  from public.customer_invites i
  join public.customer_verifications v on v.invite_id = i.id
  join public.quotes q on q.id = i.quote_id
  where i.token_hash = candidate_token_hash
    and i.expires_at > now()
    and i.revoked_at is null
    and i.consumed_at is null
    and q.status in ('SENT', 'VIEWED')
  for update of i, v;

  if verification_record.verification_id is null
     or verification_record.verified_at is not null
     or verification_record.invite_verified_at is not null
     or verification_record.verification_expires_at <= now()
     or verification_record.attempt_count >= 5 then
    return false;
  end if;

  if verification_record.code_hash <> candidate_code_hash then
    next_attempt_count := verification_record.attempt_count + 1;

    update public.customer_verifications
    set attempt_count = next_attempt_count
    where id = verification_record.verification_id;

    insert into public.audit_events (
      business_id, event_type, actor_type, actor_id, entity_type, entity_id, metadata
    ) values (
      verification_record.business_id,
      'CUSTOMER_EMAIL_VERIFICATION_FAILED',
      'CUSTOMER',
      null,
      'QUOTE',
      verification_record.quote_id,
      jsonb_build_object(
        'invite_id', verification_record.invite_id,
        'verification_id', verification_record.verification_id,
        'attempt_count', next_attempt_count
      )
    );

    return false;
  end if;

  update public.customer_verifications
  set
    verified_at = now(),
    grant_token_hash = verification_grant_hash,
    grant_expires_at = verification_grant_expires_at
  where id = verification_record.verification_id;

  update public.customer_invites
  set verified_at = now()
  where id = verification_record.invite_id;

  insert into public.audit_events (
    business_id, event_type, actor_type, actor_id, entity_type, entity_id, metadata
  ) values (
    verification_record.business_id,
    'CUSTOMER_EMAIL_VERIFIED',
    'CUSTOMER',
    null,
    'QUOTE',
    verification_record.quote_id,
    jsonb_build_object(
      'invite_id', verification_record.invite_id,
      'verification_id', verification_record.verification_id,
      'grant_expires_at', verification_grant_expires_at
    )
  );

  return true;
end;
$$;

create or replace function public.has_valid_quote_verification(
  candidate_token_hash text,
  candidate_grant_hash text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.customer_invites i
    join public.customer_verifications v on v.invite_id = i.id
    join public.quotes q on q.id = i.quote_id
    where i.token_hash = candidate_token_hash
      and v.grant_token_hash = candidate_grant_hash
      and v.verified_at is not null
      and v.grant_expires_at > now()
      and v.grant_consumed_at is null
      and i.verified_at is not null
      and i.expires_at > now()
      and i.revoked_at is null
      and i.consumed_at is null
      and q.status in ('SENT', 'VIEWED')
  );
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
    i.id as invite_id,
    i.viewed_at,
    i.verified_at,
    q.id as quote_id,
    q.business_id,
    q.status,
    b.trading_name,
    c.full_name as customer_name,
    v.id as version_id,
    v.job_title,
    v.scope,
    v.total_pence,
    v.currency
  into invite_record
  from public.customer_invites i
  join public.quotes q on q.id = i.quote_id
  join public.business_profiles b on b.id = q.business_id
  join public.customers c on c.id = q.customer_id
  join public.quote_versions v
    on v.quote_id = q.id and v.version_number = q.current_version
  where i.token_hash = candidate_token_hash
    and i.expires_at > now()
    and i.revoked_at is null
    and i.consumed_at is null
    and q.status in ('SENT', 'VIEWED')
  for update of i;

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
      jsonb_build_object('invite_id', invite_record.invite_id)
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

revoke all on function public.start_quote_verification(text, text, timestamptz) from public;
grant execute on function public.start_quote_verification(text, text, timestamptz) to anon, authenticated;

revoke all on function public.verify_quote_email(text, text, text, timestamptz) from public;
grant execute on function public.verify_quote_email(text, text, text, timestamptz) to anon, authenticated;

revoke all on function public.has_valid_quote_verification(text, text) from public;

comment on function public.start_quote_verification(text, text, timestamptz) is
  'Creates one short-lived hashed email challenge for a valid active quote invite.';
comment on function public.verify_quote_email(text, text, text, timestamptz) is
  'Atomically enforces challenge expiry and attempts, then issues one hashed quote-bound verification grant.';
comment on function public.has_valid_quote_verification(text, text) is
  'Internal predicate for later consequential customer actions; deliberately not executable by API roles.';
