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

  select c.email into customer_email
  from public.quotes q
  join public.customers c on c.id = q.customer_id
  where q.id = target_quote_id
    and q.business_id = target_business_id
    and c.business_id = target_business_id
    and q.status = 'DRAFT'
  for update of q;

  if customer_email is null then
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
    quote_id, token_hash, intended_email, expires_at, created_by
  ) values (
    target_quote_id, invite_token_hash, customer_email, invite_expires_at, current_user_id
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
    jsonb_build_object('invite_id', new_invite_id, 'expires_at', invite_expires_at)
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
    i.id as invite_id,
    i.viewed_at,
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
    'items', quote_items_json
  );
end;
$$;

revoke all on function public.send_quote(uuid, uuid, text, timestamptz) from public;
grant execute on function public.send_quote(uuid, uuid, text, timestamptz) to authenticated;

revoke all on function public.resolve_quote_invite(text) from public;
grant execute on function public.resolve_quote_invite(text) to anon, authenticated;

comment on function public.send_quote(uuid, uuid, text, timestamptz) is
  'Creates an expiring hashed invite, moves a tenant-owned draft quote to SENT and appends its audit event.';
comment on function public.resolve_quote_invite(text) is
  'Resolves a valid invite hash to safe quote content and records the first view without exposing contact details.';
