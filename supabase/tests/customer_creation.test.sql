begin;

create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'owner-one@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Owner One","trading_name":"Business One","primary_trade":"Builder","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '20000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'owner-two@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Owner Two","trading_name":"Business Two","primary_trade":"Plumber","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  );

insert into public.business_profiles (id, trading_name, primary_trade, business_type)
values ('30000000-0000-0000-0000-000000000003', 'Other Business', 'Decorator', 'SOLE_TRADER');

insert into public.business_memberships (business_id, user_id)
values ('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$select public.create_customer(
    (select business_id from public.business_memberships where user_id = '10000000-0000-0000-0000-000000000001'),
    'Customer One', 'CUSTOMER@EXAMPLE.TEST', null
  )$$,
  'a tradesperson can create a customer for their own business'
);

select is(
  (select count(*)::integer from public.customers),
  1,
  'RLS exposes the customer to its owning business'
);

select is(
  (select count(*)::integer from public.audit_events where event_type = 'CUSTOMER_CREATED'),
  1,
  'customer creation writes one visible audit event'
);

select throws_ok(
  $$select public.create_customer(
    '30000000-0000-0000-0000-000000000003',
    'Forbidden Customer', 'forbidden@example.test', null
  )$$,
  'Business membership required',
  'a tradesperson cannot create a customer for another business'
);

select throws_ok(
  $$insert into public.customers (business_id, full_name, email, created_by)
    values (
      (select business_id from public.business_memberships where user_id = '10000000-0000-0000-0000-000000000001'),
      'Bypass Customer', 'bypass@example.test', '10000000-0000-0000-0000-000000000001'
    )$$,
  '42501',
  null,
  'direct inserts cannot bypass the transactional audit function'
);

select * from finish();
rollback;
