begin;

create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '81000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'audit-admin@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Audit Admin","trading_name":"Audit Business One","primary_trade":"Builder","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '82000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'audit-owner@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Audit Owner","trading_name":"Audit Business Two","primary_trade":"Plumber","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  );

insert into public.customers (id, business_id, full_name, email, created_by)
values (
  '83000000-0000-0000-0000-000000000003',
  (select business_id from public.business_memberships where user_id = '82000000-0000-0000-0000-000000000002'),
  'Audit Customer',
  'audit-customer@example.test',
  '82000000-0000-0000-0000-000000000002'
);

insert into public.audit_events (
  business_id, event_type, actor_type, actor_id, entity_type, entity_id, metadata
) values (
  (select business_id from public.business_memberships where user_id = '81000000-0000-0000-0000-000000000001'),
  'QUOTE_SENT',
  'USER',
  '81000000-0000-0000-0000-000000000001',
  'QUOTE',
  '84000000-0000-0000-0000-000000000004',
  jsonb_build_object(
    'total_pence', 12500,
    'invite_id', '85000000-0000-0000-0000-000000000005',
    'token_hash', repeat('a', 64),
    'code_hash', repeat('b', 64),
    'verification_grant_hash', repeat('c', 64),
    'email', 'private-customer@example.test',
    'phone', '07123456789',
    'nested', jsonb_build_object('password', 'secret')
  )
);

select ok(
  public.grant_feasibility_admin(
    '81000000-0000-0000-0000-000000000001',
    'F-09 database test bootstrap'
  ),
  'a database owner can explicitly grant the feasibility admin role'
);

select ok(
  exists (
    select 1 from public.user_roles
    where user_id = '81000000-0000-0000-0000-000000000001' and role = 'ADMIN'
  ),
  'the explicit bootstrap assigns the admin role'
);

select is(
  (select count(*)::integer from public.audit_events where event_type = 'ADMIN_ROLE_GRANTED'),
  1,
  'admin authorisation is audited exactly once'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);

select is(
  (select count(distinct business_id)::integer from public.admin_audit_feed where business_id is not null),
  2,
  'an authorised admin can read material events across businesses'
);

select ok(
  exists (
    select 1 from public.admin_audit_feed
    where event_type = 'QUOTE_SENT'
      and business_name = 'Audit Business One'
      and actor_type = 'USER'
      and entity_type = 'QUOTE'
      and occurred_at is not null
  ),
  'the admin feed includes useful event, business, actor, entity and time context'
);

select is(
  (select metadata from public.admin_audit_feed where entity_id = '84000000-0000-0000-0000-000000000004'),
  jsonb_build_object(
    'total_pence', 12500,
    'invite_id', '85000000-0000-0000-0000-000000000005'
  ),
  'only explicitly safe event metadata is surfaced'
);

select ok(
  not exists (
    select 1
    from public.admin_audit_feed event,
      lateral jsonb_object_keys(event.metadata) metadata_key
    where metadata_key ~ '(token|code|hash|secret|password|email|phone)'
  ),
  'capability secrets, hashes and customer contact fields are absent from the feed'
);

select ok(
  exists (select 1 from public.admin_audit_feed where event_type = 'ADMIN_ROLE_GRANTED' and business_id is null),
  'the admin can see the platform-level authorisation audit event'
);

select ok(
  not has_table_privilege('authenticated', 'public.admin_audit_feed', 'UPDATE'),
  'the admin feed grants no update privilege to application users'
);

select throws_ok(
  $$update public.admin_audit_feed set event_type = 'QUOTE_CREATED' where event_type = 'QUOTE_SENT'$$,
  '42501',
  null,
  'the admin route data source cannot mutate audited entities'
);

select set_config('request.jwt.claim.sub', '82000000-0000-0000-0000-000000000002', true);

select is(
  (select count(*)::integer from public.admin_audit_feed),
  0,
  'an ordinary tradesperson receives no rows from the admin feed'
);

select ok(
  not exists (
    select 1 from public.audit_events
    where business_id = (
      select business_id from public.business_memberships
      where user_id = '81000000-0000-0000-0000-000000000001'
    )
  ),
  'normal tenant audit access cannot read another business events'
);

select ok(
  (select bool_and(
    business_id = (
      select business_id from public.business_memberships
      where user_id = '82000000-0000-0000-0000-000000000002'
    )
  ) from public.audit_events),
  'normal tenant audit access remains restricted to its own business'
);

select throws_ok(
  $$select public.grant_feasibility_admin('82000000-0000-0000-0000-000000000002', 'self promotion')$$,
  '42501',
  null,
  'application users cannot invoke the admin bootstrap function'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  $$select count(*) from public.admin_audit_feed$$,
  '42501',
  null,
  'anonymous and customer-capability access cannot read the admin feed'
);

select * from finish();
rollback;
