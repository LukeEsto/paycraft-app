begin;

create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '51000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'delivery-owner-one@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Delivery Owner One","trading_name":"Delivery Business One","primary_trade":"Builder","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '52000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'delivery-owner-two@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Delivery Owner Two","trading_name":"Delivery Business Two","primary_trade":"Plumber","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  );

insert into public.customers (id, business_id, full_name, email, created_by)
values
  (
    '53000000-0000-0000-0000-000000000003',
    (select business_id from public.business_memberships where user_id = '51000000-0000-0000-0000-000000000001'),
    'Delivery Customer One', 'delivery-customer-one@example.test', '51000000-0000-0000-0000-000000000001'
  ),
  (
    '54000000-0000-0000-0000-000000000004',
    (select business_id from public.business_memberships where user_id = '52000000-0000-0000-0000-000000000002'),
    'Delivery Customer Two', 'delivery-customer-two@example.test', '52000000-0000-0000-0000-000000000002'
  );

insert into public.quotes (id, business_id, customer_id, created_by)
values (
  '55000000-0000-0000-0000-000000000005',
  (select business_id from public.business_memberships where user_id = '52000000-0000-0000-0000-000000000002'),
  '54000000-0000-0000-0000-000000000004',
  '52000000-0000-0000-0000-000000000002'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '51000000-0000-0000-0000-000000000001', true);

select lives_ok(
  $$select public.create_quote(
    (select business_id from public.business_memberships where user_id = '51000000-0000-0000-0000-000000000001'),
    '53000000-0000-0000-0000-000000000003',
    'Secure delivery quote',
    'Complete the agreed work described in this secure delivery test.',
    '[{"description":"Labour","quantity":"2","unit_amount_pence":25000}]'::jsonb
  )$$,
  'the fixture quote can be created through the transactional API'
);

select lives_ok(
  $$select public.send_quote(
    (select business_id from public.business_memberships where user_id = '51000000-0000-0000-0000-000000000001'),
    (select id from public.quotes where customer_id = '53000000-0000-0000-0000-000000000003'),
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    now() + interval '7 days'
  )$$,
  'a tradesperson can send their own draft quote'
);

select is(
  (select status::text from public.quotes where customer_id = '53000000-0000-0000-0000-000000000003'),
  'SENT',
  'sending transitions the quote to SENT'
);

select is(
  (select token_hash from public.customer_invites limit 1),
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'only the supplied hash is persisted'
);

select is(
  (select count(*)::integer from public.audit_events where event_type = 'QUOTE_SENT'),
  1,
  'sending appends one visible QUOTE_SENT event'
);

select throws_ok(
  $$select public.send_quote(
    (select business_id from public.business_memberships where user_id = '51000000-0000-0000-0000-000000000001'),
    '55000000-0000-0000-0000-000000000005',
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    now() + interval '7 days'
  )$$,
  'Draft quote not found',
  'a tradesperson cannot send another business quote'
);

set local role anon;
select is(
  public.resolve_quote_invite('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa') ->> 'job_title',
  'Secure delivery quote',
  'a valid hash resolves only the safe quote payload'
);

select is(
  public.resolve_quote_invite('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa') ->> 'total_pence',
  '50000',
  'repeat resolution remains available before acceptance'
);

reset role;
select is(
  (select status::text from public.quotes where customer_id = '53000000-0000-0000-0000-000000000003'),
  'VIEWED',
  'the first valid resolution transitions the quote to VIEWED'
);

select is(
  (select count(*)::integer from public.audit_events where event_type = 'QUOTE_VIEWED'),
  1,
  'repeat views append only one QUOTE_VIEWED event'
);

select * from finish();
rollback;
