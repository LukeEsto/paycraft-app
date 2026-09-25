create or replace function public.create_customer(
  target_business_id uuid,
  customer_full_name text,
  customer_email text,
  customer_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  new_customer_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.business_memberships membership
    where membership.business_id = target_business_id
      and membership.user_id = current_user_id
  ) then
    raise exception 'Business membership required';
  end if;

  insert into public.customers (business_id, full_name, email, phone, created_by)
  values (
    target_business_id,
    nullif(trim(customer_full_name), ''),
    lower(nullif(trim(customer_email), '')),
    nullif(trim(customer_phone), ''),
    current_user_id
  )
  returning id into new_customer_id;

  insert into public.audit_events (
    business_id, event_type, actor_type, actor_id, entity_type, entity_id, metadata
  ) values (
    target_business_id,
    'CUSTOMER_CREATED',
    'USER',
    current_user_id,
    'CUSTOMER',
    new_customer_id,
    '{}'::jsonb
  );

  return new_customer_id;
end;
$$;

drop policy customers_business_all on public.customers;
create policy customers_business_select on public.customers for select to authenticated
using (public.is_business_member(business_id) or public.is_admin());

revoke all on function public.create_customer(uuid, text, text, text) from public;
grant execute on function public.create_customer(uuid, text, text, text) to authenticated;

comment on function public.create_customer(uuid, text, text, text) is
  'Atomically creates a customer and audit event for a business owned by the authenticated user.';
