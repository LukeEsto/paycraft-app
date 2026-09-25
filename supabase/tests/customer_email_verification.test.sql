begin;

create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '61000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'verification-owner-one@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Verification Owner One","trading_name":"Verification Business One","primary_trade":"Builder","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '62000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'verification-owner-two@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Verification Owner Two","trading_name":"Verification Business Two","primary_trade":"Plumber","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  );

insert into public.customers (id, business_id, full_name, email, created_by)
values
  (
    '63000000-0000-0000-0000-000000000003',
    (select business_id from public.business_memberships where user_id = '61000000-0000-0000-0000-000000000001'),
    'Verification Customer One', 'verification-customer-one@example.test', '61000000-0000-0000-0000-000000000001'
  ),
  (
    '64000000-0000-0000-0000-000000000004',
    (select business_id from public.business_memberships where user_id = '62000000-0000-0000-0000-000000000002'),
    'Verification Customer Two', 'verification-customer-two@example.test', '62000000-0000-0000-0000-000000000002'
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '61000000-0000-0000-0000-000000000001', true);

select public.create_quote(
  (select business_id from public.business_memberships where user_id = '61000000-0000-0000-0000-000000000001'),
  '63000000-0000-0000-0000-000000000003',
  'Valid verification quote',
  'A quote used to prove one successful customer email verification.',
  '[{"description":"Labour","quantity":"1","unit_amount_pence":10000}]'::jsonb
);
select public.create_quote(
  (select business_id from public.business_memberships where user_id = '61000000-0000-0000-0000-000000000001'),
  '63000000-0000-0000-0000-000000000003',
  'Exhausted verification quote',
  'A quote used to prove the customer verification attempt limit.',
  '[{"description":"Labour","quantity":"1","unit_amount_pence":11000}]'::jsonb
);
select public.create_quote(
  (select business_id from public.business_memberships where user_id = '61000000-0000-0000-0000-000000000001'),
  '63000000-0000-0000-0000-000000000003',
  'Expired verification quote',
  'A quote used to prove an expired verification code is rejected.',
  '[{"description":"Labour","quantity":"1","unit_amount_pence":12000}]'::jsonb
);

select public.send_quote(
  (select business_id from public.business_memberships where user_id = '61000000-0000-0000-0000-000000000001'),
  (select q.id from public.quotes q join public.quote_versions v on v.quote_id = q.id where v.job_title = 'Valid verification quote'),
  repeat('a', 64), now() + interval '7 days'
);
select public.send_quote(
  (select business_id from public.business_memberships where user_id = '61000000-0000-0000-0000-000000000001'),
  (select q.id from public.quotes q join public.quote_versions v on v.quote_id = q.id where v.job_title = 'Exhausted verification quote'),
  repeat('b', 64), now() + interval '7 days'
);
select public.send_quote(
  (select business_id from public.business_memberships where user_id = '61000000-0000-0000-0000-000000000001'),
  (select q.id from public.quotes q join public.quote_versions v on v.quote_id = q.id where v.job_title = 'Expired verification quote'),
  repeat('c', 64), now() + interval '7 days'
);

select set_config('request.jwt.claim.sub', '62000000-0000-0000-0000-000000000002', true);
select public.create_quote(
  (select business_id from public.business_memberships where user_id = '62000000-0000-0000-0000-000000000002'),
  '64000000-0000-0000-0000-000000000004',
  'Other tenant verification quote',
  'A second business quote used to prove cross-tenant isolation.',
  '[{"description":"Labour","quantity":"1","unit_amount_pence":13000}]'::jsonb
);
select public.send_quote(
  (select business_id from public.business_memberships where user_id = '62000000-0000-0000-0000-000000000002'),
  (select q.id from public.quotes q join public.quote_versions v on v.quote_id = q.id where v.job_title = 'Other tenant verification quote'),
  repeat('d', 64), now() + interval '7 days'
);

set local role anon;
select is(
  public.start_quote_verification(repeat('a', 64), repeat('1', 64), now() + interval '10 minutes'),
  'verification-customer-one@example.test',
  'a valid invite starts a challenge for its intended email'
);
select public.start_quote_verification(repeat('b', 64), repeat('2', 64), now() + interval '10 minutes');
select public.start_quote_verification(repeat('c', 64), repeat('3', 64), now() + interval '10 minutes');
select public.start_quote_verification(repeat('d', 64), repeat('4', 64), now() + interval '10 minutes');

reset role;
update public.customer_verifications v
set expires_at = now() - interval '1 minute'
from public.customer_invites i
where i.id = v.invite_id and i.token_hash = repeat('c', 64);

set local role anon;
select is(
  public.verify_quote_email(repeat('a', 64), repeat('9', 64), repeat('f', 64), now() + interval '30 minutes'),
  false,
  'an incorrect code is rejected with a generic false result'
);
reset role;
select is(
  (select attempt_count from public.customer_verifications v join public.customer_invites i on i.id = v.invite_id where i.token_hash = repeat('a', 64)),
  1,
  'an incorrect code increments the attempt count transactionally'
);
set local role anon;
select is(
  public.verify_quote_email(repeat('a', 64), repeat('1', 64), repeat('e', 64), now() + interval '30 minutes'),
  true,
  'the correct unexpired code verifies once'
);
select is(
  public.verify_quote_email(repeat('a', 64), repeat('1', 64), repeat('8', 64), now() + interval '30 minutes'),
  false,
  'a verified code cannot be replayed to mint another grant'
);
select is(
  public.verify_quote_email(repeat('c', 64), repeat('3', 64), repeat('7', 64), now() + interval '30 minutes'),
  false,
  'an expired code is rejected'
);
select is(
  public.verify_quote_email(repeat('d', 64), repeat('1', 64), repeat('6', 64), now() + interval '30 minutes'),
  false,
  'a code from one quote cannot verify another tenant quote'
);

select public.verify_quote_email(repeat('b', 64), repeat('9', 64), repeat('5', 64), now() + interval '30 minutes');
select public.verify_quote_email(repeat('b', 64), repeat('9', 64), repeat('5', 64), now() + interval '30 minutes');
select public.verify_quote_email(repeat('b', 64), repeat('9', 64), repeat('5', 64), now() + interval '30 minutes');
select public.verify_quote_email(repeat('b', 64), repeat('9', 64), repeat('5', 64), now() + interval '30 minutes');
select public.verify_quote_email(repeat('b', 64), repeat('9', 64), repeat('5', 64), now() + interval '30 minutes');

select is(
  public.verify_quote_email(repeat('b', 64), repeat('2', 64), repeat('5', 64), now() + interval '30 minutes'),
  false,
  'the correct code is rejected after attempt exhaustion'
);
select throws_ok(
  $$select public.has_valid_quote_verification(repeat('a', 64), repeat('e', 64))$$,
  '42501',
  null,
  'anonymous clients cannot invoke the internal authority predicate'
);

reset role;
select is(
  (select attempt_count from public.customer_verifications v join public.customer_invites i on i.id = v.invite_id where i.token_hash = repeat('b', 64)),
  5,
  'attempt exhaustion is stored server-side and cannot be reset by the client'
);
select is(
  (select count(*)::integer from public.audit_events where event_type = 'CUSTOMER_EMAIL_VERIFIED'),
  1,
  'one successful verification appends one audit event'
);
select is(
  (select count(*)::integer from public.audit_events where event_type = 'CUSTOMER_EMAIL_VERIFICATION_FAILED'),
  7,
  'each evaluated incorrect code is audited without storing the code'
);
select is(
  (select count(*)::integer from public.audit_events where event_type = 'CUSTOMER_EMAIL_VERIFICATION_STARTED'),
  4,
  'each invite challenge start is audited'
);
select is(
  public.has_valid_quote_verification(repeat('a', 64), repeat('e', 64)),
  true,
  'the database recognises the server-issued quote-bound grant'
);
select is(
  public.has_valid_quote_verification(repeat('a', 64), repeat('0', 64)),
  false,
  'forged client state does not create verification authority'
);

select * from finish();
rollback;
