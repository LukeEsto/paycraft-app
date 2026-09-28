-- F-09: explicitly authorised, read-only cross-business audit visibility.

create or replace function public.grant_feasibility_admin(
  target_user_id uuid,
  grant_reason text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  inserted_count integer;
begin
  -- This is an operator/bootstrap function, not an application RPC. A request
  -- carrying any Supabase JWT is deliberately rejected even if it is an admin.
  if auth.uid() is not null then
    raise exception 'Database-owner operation required';
  end if;

  if nullif(trim(grant_reason), '') is null or char_length(grant_reason) > 240 then
    raise exception 'A concise grant reason is required';
  end if;

  if not exists (
    select 1
    from public.profiles profile
    join public.user_roles role_record on role_record.user_id = profile.id
    where profile.id = target_user_id and role_record.role = 'TRADESPERSON'
  ) then
    raise exception 'Admin target must be an onboarded user';
  end if;

  insert into public.user_roles (user_id, role)
  values (target_user_id, 'ADMIN')
  on conflict (user_id, role) do nothing;

  get diagnostics inserted_count = row_count;

  if inserted_count = 1 then
    insert into public.audit_events (
      business_id, event_type, actor_type, actor_id, entity_type, entity_id, metadata
    ) values (
      null,
      'ADMIN_ROLE_GRANTED',
      'SYSTEM',
      null,
      'USER',
      target_user_id,
      jsonb_build_object('reason', trim(grant_reason))
    );
  end if;

  return inserted_count = 1;
end;
$$;

revoke all on function public.grant_feasibility_admin(uuid, text) from public;
revoke all on function public.grant_feasibility_admin(uuid, text) from anon;
revoke all on function public.grant_feasibility_admin(uuid, text) from authenticated;
revoke all on function public.grant_feasibility_admin(uuid, text) from service_role;

comment on function public.grant_feasibility_admin(uuid, text) is
  'Database-owner-only feasibility bootstrap. Never exposed through the application API.';

create or replace function public.safe_audit_metadata(source jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    jsonb_object_agg(entry.key, entry.value),
    '{}'::jsonb
  )
  from jsonb_each(coalesce(source, '{}'::jsonb)) as entry
  where entry.key = any (array[
    'primary_trade',
    'version',
    'item_count',
    'total_pence',
    'invite_id',
    'quote_version_id',
    'verification_id',
    'expires_at',
    'attempt_count',
    'grant_expires_at',
    'accepted_version_id',
    'accepted_version_number',
    'accepted_amount_pence',
    'currency',
    'accepted_at'
  ]);
$$;

revoke all on function public.safe_audit_metadata(jsonb) from public;
revoke all on function public.safe_audit_metadata(jsonb) from anon;
grant execute on function public.safe_audit_metadata(jsonb) to authenticated;

create or replace view public.admin_audit_feed
with (security_invoker = true, security_barrier = true)
as
select
  event.id,
  event.event_type,
  event.occurred_at,
  event.business_id,
  business.trading_name as business_name,
  event.actor_type,
  event.actor_id,
  event.entity_type,
  event.entity_id,
  public.safe_audit_metadata(event.metadata) as metadata
from public.audit_events event
left join public.business_profiles business on business.id = event.business_id
where public.is_admin()
  and event.event_type = any (array[
    'ACCOUNT_CREATED',
    'TRADE_ONBOARDING_COMPLETED',
    'CUSTOMER_CREATED',
    'QUOTE_CREATED',
    'QUOTE_SENT',
    'QUOTE_VIEWED',
    'CUSTOMER_EMAIL_VERIFICATION_STARTED',
    'CUSTOMER_EMAIL_VERIFICATION_FAILED',
    'CUSTOMER_EMAIL_VERIFIED',
    'QUOTE_ACCEPTED',
    'ADMIN_ROLE_GRANTED'
  ]);

revoke all on public.admin_audit_feed from public;
revoke all on public.admin_audit_feed from anon;
grant select on public.admin_audit_feed to authenticated;

comment on view public.admin_audit_feed is
  'Read-only, admin-gated projection of material audit events with allowlisted metadata.';

create index audit_events_chronological_idx
  on public.audit_events(occurred_at desc, id desc);
