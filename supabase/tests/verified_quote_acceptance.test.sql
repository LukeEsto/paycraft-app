begin;

create extension if not exists pgtap with schema extensions;
select plan(25);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '71000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'acceptance-owner-one@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Acceptance Owner One","trading_name":"Acceptance Business One","primary_trade":"Builder","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '72000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'acceptance-owner-two@example.test', crypt('TestPassword!2026', gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    '{"account_type":"TRADESPERSON","full_name":"Acceptance Owner Two","trading_name":"Acceptance Business Two","primary_trade":"Plumber","business_type":"SOLE_TRADER","terms_accepted":true,"privacy_accepted":true}',
    now(), now()
  );

insert into public.customers (id, business_id, full_name, email, created_by)
values
  (
    '73000000-0000-0000-0000-000000000003',
    (select business_id from public.business_memberships where user_id = '71000000-0000-0000-0000-000000000001'),
    'Acceptance Customer One', 'acceptance-customer-one@example.test', '71000000-0000-0000-0000-000000000001'
  ),
  (
    '74000000-0000-0000-0000-000000000004',
    (select business_id from public.business_memberships where user_id = '72000000-0000-0000-0000-000000000002'),
    'Acceptance Customer Two', 'acceptance-customer-two@example.test', '72000000-0000-0000-0000-000000000002'
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000001', true);

select public.create_quote(
  (select business_id from public.business_memberships where user_id = '71000000-0000-0000-0000-000000000001'),
  '73000000-0000-0000-0000-000000000003',
  'Valid acceptance quote', 'The exact valid scope presented to the customer.',
  '[{"description":"Labour","quantity":"1","unit_amount_pence":10000}]'::jsonb
);
select public.create_quote(
  (select business_id from public.business_memberships where user_id = '71000000-0000-0000-0000-000000000001'),
  '73000000-0000-0000-0000-000000000003',
  'Unverified acceptance quote', 'A quote without verification authority.',
  '[{"description":"Labour","quantity":"1","unit_amount_pence":11000}]'::jsonb
);
select public.create_quote(
  (select business_id from public.business_memberships where user_id = '71000000-0000-0000-0000-000000000001'),
  '73000000-0000-0000-0000-000000000003',
  'Expired grant acceptance quote', 'A quote with expired verification authority.',
  '[{"description":"Labour","quantity":"1","unit_amount_pence":12000}]'::jsonb
);
select public.create_quote(
  (select business_id from public.business_memberships where user_id = '71000000-0000-0000-0000-000000000001'),
  '73000000-0000-0000-0000-000000000003',
  'Stale version acceptance quote', 'The original scope before a version change.',
  '[{"description":"Labour","quantity":"1","unit_amount_pence":13000}]'::jsonb
);
select public.create_quote(
  (select business_id from public.business_memberships where user_id = '71000000-0000-0000-0000-000000000001'),
  '73000000-0000-0000-0000-000000000003',
  'Expired invite acceptance quote', 'A quote whose invite expires after verification.',
  '[{"description":"Labour","quantity":"1","unit_amount_pence":14000}]'::jsonb
);

select public.send_quote(
  (select business_id from public.business_memberships where user_id = '71000000-0000-0000-0000-000000000001'),
  (select quote.id from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Valid acceptance quote'),
  repeat('a', 64), now() + interval '7 days'
);
select public.send_quote(
  (select business_id from public.business_memberships where user_id = '71000000-0000-0000-0000-000000000001'),
  (select quote.id from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Unverified acceptance quote'),
  repeat('b', 64), now() + interval '7 days'
);
select public.send_quote(
  (select business_id from public.business_memberships where user_id = '71000000-0000-0000-0000-000000000001'),
  (select quote.id from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Expired grant acceptance quote'),
  repeat('c', 64), now() + interval '7 days'
);
select public.send_quote(
  (select business_id from public.business_memberships where user_id = '71000000-0000-0000-0000-000000000001'),
  (select quote.id from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Stale version acceptance quote'),
  repeat('d', 64), now() + interval '7 days'
);
select public.send_quote(
  (select business_id from public.business_memberships where user_id = '71000000-0000-0000-0000-000000000001'),
  (select quote.id from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Expired invite acceptance quote'),
  repeat('f', 64), now() + interval '7 days'
);

select set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000002', true);
select public.create_quote(
  (select business_id from public.business_memberships where user_id = '72000000-0000-0000-0000-000000000002'),
  '74000000-0000-0000-0000-000000000004',
  'Other tenant acceptance quote', 'A quote owned by a different business.',
  '[{"description":"Labour","quantity":"1","unit_amount_pence":15000}]'::jsonb
);
select public.send_quote(
  (select business_id from public.business_memberships where user_id = '72000000-0000-0000-0000-000000000002'),
  (select quote.id from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Other tenant acceptance quote'),
  repeat('e', 64), now() + interval '7 days'
);

set local role anon;
select public.start_quote_verification(repeat('a', 64), repeat('a', 64), now() + interval '10 minutes');
select public.verify_quote_email(repeat('a', 64), repeat('a', 64), repeat('1', 64), now() + interval '30 minutes');
select public.start_quote_verification(repeat('c', 64), repeat('c', 64), now() + interval '10 minutes');
select public.verify_quote_email(repeat('c', 64), repeat('c', 64), repeat('3', 64), now() + interval '30 minutes');
select public.start_quote_verification(repeat('d', 64), repeat('d', 64), now() + interval '10 minutes');
select public.verify_quote_email(repeat('d', 64), repeat('d', 64), repeat('4', 64), now() + interval '30 minutes');
select public.start_quote_verification(repeat('e', 64), repeat('e', 64), now() + interval '10 minutes');
select public.verify_quote_email(repeat('e', 64), repeat('e', 64), repeat('5', 64), now() + interval '30 minutes');
select public.start_quote_verification(repeat('f', 64), repeat('f', 64), now() + interval '10 minutes');
select public.verify_quote_email(repeat('f', 64), repeat('f', 64), repeat('6', 64), now() + interval '30 minutes');

reset role;
update public.customer_verifications verification
set grant_expires_at = now() - interval '1 minute'
from public.customer_invites invite
where invite.id = verification.invite_id and invite.token_hash = repeat('c', 64);

update public.customer_invites
set expires_at = now() - interval '1 minute'
where token_hash = repeat('f', 64);

insert into public.quote_versions (
  quote_id, version_number, job_title, scope, total_pence, currency, created_by
)
select
  quote.id, 2, version.job_title, 'A changed scope that invalidates the original invite.', 13500, 'GBP', quote.created_by
from public.quotes quote
join public.quote_versions version on version.quote_id = quote.id and version.version_number = 1
where version.job_title = 'Stale version acceptance quote';

update public.quotes quote
set current_version = 2
from public.quote_versions version
where version.quote_id = quote.id and version.job_title = 'Stale version acceptance quote';

select set_config(
  'test.valid_quote_id',
  (select quote.id::text from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Valid acceptance quote'),
  true
);
select set_config('test.valid_version_id', (select id::text from public.quote_versions where job_title = 'Valid acceptance quote'), true);
select set_config(
  'test.unverified_quote_id',
  (select quote.id::text from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Unverified acceptance quote'),
  true
);
select set_config('test.unverified_version_id', (select id::text from public.quote_versions where job_title = 'Unverified acceptance quote'), true);
select set_config(
  'test.expired_grant_quote_id',
  (select quote.id::text from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Expired grant acceptance quote'),
  true
);
select set_config('test.expired_grant_version_id', (select id::text from public.quote_versions where job_title = 'Expired grant acceptance quote'), true);
select set_config(
  'test.stale_quote_id',
  (select quote.id::text from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Stale version acceptance quote' and version.version_number = 1),
  true
);
select set_config('test.stale_version_id', (select id::text from public.quote_versions where job_title = 'Stale version acceptance quote' and version_number = 1), true);
select set_config(
  'test.expired_invite_quote_id',
  (select quote.id::text from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Expired invite acceptance quote'),
  true
);
select set_config('test.expired_invite_version_id', (select id::text from public.quote_versions where job_title = 'Expired invite acceptance quote'), true);
select set_config(
  'test.other_tenant_quote_id',
  (select quote.id::text from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Other tenant acceptance quote'),
  true
);
select set_config('test.other_tenant_version_id', (select id::text from public.quote_versions where job_title = 'Other tenant acceptance quote'), true);

set local role anon;

select is(
  public.accept_quote(
    repeat('b', 64), repeat('2', 64),
    current_setting('test.unverified_quote_id')::uuid,
    current_setting('test.unverified_version_id')::uuid, 1, 11000
  ),
  null::jsonb,
  'missing verification authority cannot accept a quote'
);

select is(
  public.accept_quote(
    repeat('a', 64), repeat('9', 64),
    current_setting('test.valid_quote_id')::uuid,
    current_setting('test.valid_version_id')::uuid, 1, 10000
  ),
  null::jsonb,
  'a forged verification grant cannot accept a quote'
);

select is(
  public.accept_quote(
    repeat('c', 64), repeat('3', 64),
    current_setting('test.expired_grant_quote_id')::uuid,
    current_setting('test.expired_grant_version_id')::uuid, 1, 12000
  ),
  null::jsonb,
  'an expired verification grant cannot accept a quote'
);

select is(
  public.accept_quote(
    repeat('f', 64), repeat('6', 64),
    current_setting('test.expired_invite_quote_id')::uuid,
    current_setting('test.expired_invite_version_id')::uuid, 1, 14000
  ),
  null::jsonb,
  'an expired invite cannot accept a quote'
);

select is(
  public.accept_quote(
    repeat('a', 64), repeat('1', 64),
    current_setting('test.unverified_quote_id')::uuid,
    current_setting('test.unverified_version_id')::uuid, 1, 11000
  ),
  null::jsonb,
  'authority for one quote cannot accept another quote in the same tenant'
);

select is(
  public.accept_quote(
    repeat('e', 64), repeat('1', 64),
    current_setting('test.other_tenant_quote_id')::uuid,
    current_setting('test.other_tenant_version_id')::uuid, 1, 15000
  ),
  null::jsonb,
  'a grant from another quote cannot affect another tenant'
);

select is(
  public.accept_quote(
    repeat('d', 64), repeat('4', 64),
    current_setting('test.stale_quote_id')::uuid,
    current_setting('test.stale_version_id')::uuid, 1, 13000
  ),
  null::jsonb,
  'an invite for a stale quote version cannot accept the changed quote'
);

select is(
  public.resolve_quote_invite(repeat('d', 64)),
  null::jsonb,
  'a stale version invite is no longer publicly resolvable'
);

select is(
  public.accept_quote(
    repeat('a', 64), repeat('1', 64),
    current_setting('test.valid_quote_id')::uuid,
    current_setting('test.valid_version_id')::uuid, 1, 9999
  ),
  null::jsonb,
  'a client-tampered displayed amount cannot change what is accepted'
);

select is(
  public.accept_quote(
    repeat('a', 64), repeat('1', 64),
    current_setting('test.valid_quote_id')::uuid,
    current_setting('test.valid_version_id')::uuid, 1, 10000
  ) ->> 'accepted',
  'true',
  'a valid invite and matching server-issued grant accept the exact displayed quote'
);

reset role;

select is(
  (select status::text from public.quotes quote join public.quote_versions version on version.id = quote.accepted_version_id where version.job_title = 'Valid acceptance quote'),
  'ACCEPTED',
  'acceptance atomically moves the quote to ACCEPTED'
);
select is(
  (select accepted_version_id from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Valid acceptance quote'),
  (select id from public.quote_versions where job_title = 'Valid acceptance quote'),
  'the accepted version snapshot references the exact invited version'
);
select is(
  (select accepted_amount_pence from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Valid acceptance quote'),
  10000,
  'the authoritative accepted amount is snapshotted'
);
select ok(
  (select accepted_at is not null from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Valid acceptance quote'),
  'the authoritative acceptance timestamp is stored'
);
select ok(
  (select invite.consumed_at is not null and verification.grant_consumed_at is not null
   from public.customer_invites invite
   join public.customer_verifications verification on verification.invite_id = invite.id
   where invite.token_hash = repeat('a', 64)),
  'the invite and verification grant are consumed together'
);

set local role anon;
select is(
  public.accept_quote(
    repeat('a', 64), repeat('1', 64),
    current_setting('test.valid_quote_id')::uuid,
    current_setting('test.valid_version_id')::uuid, 1, 10000
  ) ->> 'already_accepted',
  'true',
  'an exact repeat submission is idempotent and returns the existing acceptance'
);

reset role;
select is(
  (select count(*)::integer from public.audit_events where event_type = 'QUOTE_ACCEPTED'),
  1,
  'one and only one QUOTE_ACCEPTED audit event is appended'
);
select is(
  (select metadata ->> 'accepted_amount_pence' from public.audit_events where event_type = 'QUOTE_ACCEPTED'),
  '10000',
  'the audit event records the accepted amount snapshot'
);
select throws_ok(
  $$
    update public.quotes quote
    set
      status = 'ACCEPTED',
      accepted_version_id = version.id,
      accepted_at = now(),
      accepted_amount_pence = version.total_pence,
      accepted_currency = version.currency
    from public.quote_versions version
    where version.quote_id = quote.id and version.job_title = 'Unverified acceptance quote'
  $$,
  'P0001',
  'Quote acceptance must use the acceptance function',
  'acceptance state cannot be forged with a direct table update'
);
select throws_ok(
  $$update public.quote_versions set total_pence = 9999 where job_title = 'Valid acceptance quote'$$,
  'P0001',
  'Accepted quote versions are immutable',
  'the accepted source version cannot be mutated'
);
select throws_ok(
  $$
    update public.quote_items item
    set description = 'Tampered scope item'
    from public.quote_versions version
    where version.id = item.quote_version_id and version.job_title = 'Valid acceptance quote'
  $$,
  'P0001',
  'Delivered quote items are immutable',
  'the delivered line-item scope cannot be mutated'
);
select is(
  public.resolve_quote_invite(repeat('a', 64)),
  null::jsonb,
  'the consumed invite can no longer resolve an actionable quote'
);
select is(
  public.has_valid_quote_verification(repeat('a', 64), repeat('1', 64)),
  false,
  'the consumed grant cannot authorise another consequential action'
);
select is(
  (select status::text from public.quotes quote join public.quote_versions version on version.quote_id = quote.id where version.job_title = 'Other tenant acceptance quote'),
  'SENT',
  'cross-tenant attempts leave the other business quote unchanged'
);
select is(
  (select count(*)::integer from public.audit_events where event_type = 'QUOTE_ACCEPTED'),
  1,
  'failed and replayed submissions do not create extra acceptance audit events'
);

select * from finish();
rollback;
