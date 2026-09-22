create or replace function public.is_business_member(target_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.business_memberships bm
    where bm.business_id = target_business_id and bm.user_id = auth.uid()
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid() and ur.role = 'ADMIN'
  );
$$;

revoke all on function public.is_business_member(uuid) from public;
revoke all on function public.is_admin() from public;
grant execute on function public.is_business_member(uuid) to authenticated;
grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.business_profiles enable row level security;
alter table public.business_memberships enable row level security;
alter table public.consent_records enable row level security;
alter table public.customers enable row level security;
alter table public.quotes enable row level security;
alter table public.quote_versions enable row level security;
alter table public.quote_items enable row level security;
alter table public.customer_invites enable row level security;
alter table public.customer_verifications enable row level security;
alter table public.jobs enable row level security;
alter table public.payment_records enable row level security;
alter table public.audit_events enable row level security;

create policy profiles_self_select on public.profiles for select to authenticated
using (id = auth.uid() or public.is_admin());
create policy profiles_self_update on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());

create policy roles_self_select on public.user_roles for select to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy businesses_member_select on public.business_profiles for select to authenticated
using (public.is_business_member(id) or public.is_admin());
create policy memberships_member_select on public.business_memberships for select to authenticated
using (user_id = auth.uid() or public.is_admin());
create policy consents_self_select on public.consent_records for select to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy customers_business_all on public.customers for all to authenticated
using (public.is_business_member(business_id) or public.is_admin())
with check (public.is_business_member(business_id));

create policy quotes_business_select on public.quotes for select to authenticated
using (public.is_business_member(business_id) or public.is_admin());
create policy quotes_business_insert on public.quotes for insert to authenticated
with check (public.is_business_member(business_id));
create policy quotes_business_update on public.quotes for update to authenticated
using (public.is_business_member(business_id)) with check (public.is_business_member(business_id));

create policy quote_versions_business_select on public.quote_versions for select to authenticated
using (exists (
  select 1 from public.quotes q where q.id = quote_id
  and (public.is_business_member(q.business_id) or public.is_admin())
));
create policy quote_versions_business_insert on public.quote_versions for insert to authenticated
with check (exists (
  select 1 from public.quotes q where q.id = quote_id and public.is_business_member(q.business_id)
));

create policy quote_items_business_select on public.quote_items for select to authenticated
using (exists (
  select 1 from public.quote_versions qv join public.quotes q on q.id = qv.quote_id
  where qv.id = quote_version_id and (public.is_business_member(q.business_id) or public.is_admin())
));
create policy quote_items_business_insert on public.quote_items for insert to authenticated
with check (exists (
  select 1 from public.quote_versions qv join public.quotes q on q.id = qv.quote_id
  where qv.id = quote_version_id and public.is_business_member(q.business_id)
));

create policy invites_business_select on public.customer_invites for select to authenticated
using (exists (
  select 1 from public.quotes q where q.id = quote_id
  and (public.is_business_member(q.business_id) or public.is_admin())
));

create policy jobs_business_select on public.jobs for select to authenticated
using (public.is_business_member(business_id) or public.is_admin());
create policy payment_business_select on public.payment_records for select to authenticated
using (exists (
  select 1 from public.jobs j where j.id = job_id
  and (public.is_business_member(j.business_id) or public.is_admin())
));
create policy audit_business_select on public.audit_events for select to authenticated
using ((business_id is not null and public.is_business_member(business_id)) or public.is_admin());

-- Customer invite resolution, acceptance, onboarding and audit writes use narrowly scoped
-- server-side database functions in the feature sprint. No broad anonymous table policy is granted.
-- Elevated credentials remain server-only.
