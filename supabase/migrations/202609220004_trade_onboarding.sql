create or replace function public.handle_new_trade_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  new_business_id uuid := gen_random_uuid();
  supplied_business_type text := metadata ->> 'business_type';
begin
  if coalesce(metadata ->> 'account_type', '') <> 'TRADESPERSON' then
    raise exception 'Unsupported account type';
  end if;

  if coalesce((metadata ->> 'terms_accepted')::boolean, false) is not true
     or coalesce((metadata ->> 'privacy_accepted')::boolean, false) is not true then
    raise exception 'Terms and privacy acceptance are required';
  end if;

  if supplied_business_type not in ('LIMITED_COMPANY', 'SOLE_TRADER', 'PARTNERSHIP', 'OTHER') then
    raise exception 'Invalid business type';
  end if;

  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    nullif(trim(metadata ->> 'full_name'), ''),
    nullif(trim(metadata ->> 'phone'), '')
  );

  insert into public.user_roles (user_id, role)
  values (new.id, 'TRADESPERSON');

  insert into public.business_profiles (id, trading_name, primary_trade, business_type)
  values (
    new_business_id,
    nullif(trim(metadata ->> 'trading_name'), ''),
    nullif(trim(metadata ->> 'primary_trade'), ''),
    supplied_business_type::public.business_type
  );

  insert into public.business_memberships (business_id, user_id, membership_role)
  values (new_business_id, new.id, 'OWNER');

  insert into public.consent_records (user_id, consent_type, policy_version)
  values
    (new.id, 'TERMS', coalesce(nullif(metadata ->> 'terms_version', ''), 'feasibility-v1')),
    (new.id, 'PRIVACY', coalesce(nullif(metadata ->> 'privacy_version', ''), 'feasibility-v1'));

  insert into public.audit_events (
    business_id, event_type, actor_type, actor_id, entity_type, entity_id, metadata
  ) values
    (new_business_id, 'ACCOUNT_CREATED', 'USER', new.id, 'USER', new.id, '{}'::jsonb),
    (
      new_business_id,
      'TRADE_ONBOARDING_COMPLETED',
      'USER',
      new.id,
      'BUSINESS',
      new_business_id,
      jsonb_build_object('primary_trade', metadata ->> 'primary_trade')
    );

  return new;
end;
$$;

revoke all on function public.handle_new_trade_user() from public;

create trigger on_auth_user_created_trade_onboarding
after insert on auth.users
for each row execute function public.handle_new_trade_user();

create policy businesses_member_insert on public.business_profiles for insert to authenticated
with check (false);
create policy memberships_member_insert on public.business_memberships for insert to authenticated
with check (false);
create policy profiles_self_insert on public.profiles for insert to authenticated
with check (false);
create policy roles_self_insert on public.user_roles for insert to authenticated
with check (false);
create policy consents_self_insert on public.consent_records for insert to authenticated
with check (false);

comment on function public.handle_new_trade_user() is
  'Creates the feasibility trade profile, business, membership, consents and audit events in the auth transaction.';
