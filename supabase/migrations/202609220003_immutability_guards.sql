create or replace function public.guard_accepted_quote_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.quotes q
    where q.accepted_version_id = old.id and q.status = 'ACCEPTED'
  ) then
    raise exception 'Accepted quote versions are immutable';
  end if;
  return new;
end;
$$;

create trigger quote_versions_accepted_immutable
before update or delete on public.quote_versions
for each row execute function public.guard_accepted_quote_version();

create or replace function public.prevent_audit_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Audit events are append-only';
end;
$$;

create trigger audit_events_append_only
before update or delete on public.audit_events
for each row execute function public.prevent_audit_mutation();
