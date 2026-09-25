begin;

create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '41000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'quote-owner-one@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Quote Owner One","trading_name":"Quote Business One","primary_trade":"Builder","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '42000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'quote-owner-two@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Quote Owner Two","trading_name":"Quote Business Two","primary_trade":"Plumber","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  );

insert into public.customers (id, business_id, full_name, email, created_by)
values
  (
    '43000000-0000-0000-0000-000000000003',
    (select business_id from public.business_memberships where user_id = '41000000-0000-0000-0000-000000000001'),
    'Customer One', 'quote-customer-one@example.test', '41000000-0000-0000-0000-000000000001'
  ),
  (
    '44000000-0000-0000-0000-000000000004',
    (select business_id from public.business_memberships where user_id = '42000000-0000-0000-0000-000000000002'),
    'Customer Two', 'quote-customer-two@example.test', '42000000-0000-0000-0000-000000000002'
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$select public.create_quote(
    (select business_id from public.business_memberships where user_id = '41000000-0000-0000-0000-000000000001'),
    '43000000-0000-0000-0000-000000000003',
    'Bathroom refurbishment',
    'Remove the existing suite and install the agreed replacement.',
    '[{"description":"Labour","quantity":"2.5","unit_amount_pence":20000},{"description":"Materials","quantity":"1","unit_amount_pence":15000}]'::jsonb
  )$$,
  'a tradesperson can create a versioned quote for their customer'
);

select is(
  (select total_pence from public.quote_versions limit 1),
  65000,
  'the database calculates the quote total from line items'
);

select is(
  (select count(*)::integer from public.audit_events where event_type = 'QUOTE_CREATED'),
  1,
  'quote creation appends one visible audit event'
);

select throws_ok(
  $$select public.create_quote(
    (select business_id from public.business_memberships where user_id = '41000000-0000-0000-0000-000000000001'),
    '44000000-0000-0000-0000-000000000004',
    'Forbidden quote',
    'This customer belongs to another business and must be rejected.',
    '[{"description":"Labour","quantity":"1","unit_amount_pence":10000}]'::jsonb
  )$$,
  'Customer does not belong to business',
  'a cross-business customer cannot be attached to a quote'
);

select throws_ok(
  $$insert into public.quotes (business_id, customer_id, created_by)
    values (
      (select business_id from public.business_memberships where user_id = '41000000-0000-0000-0000-000000000001'),
      '43000000-0000-0000-0000-000000000003',
      '41000000-0000-0000-0000-000000000001'
    )$$,
  '42501',
  null,
  'direct quote inserts cannot bypass versioning and audit creation'
);

select * from finish();
rollback;
