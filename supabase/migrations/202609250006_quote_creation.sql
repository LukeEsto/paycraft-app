create or replace function public.create_quote(
  target_business_id uuid,
  target_customer_id uuid,
  quote_job_title text,
  quote_scope text,
  quote_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  new_quote_id uuid := gen_random_uuid();
  new_version_id uuid := gen_random_uuid();
  item_record record;
  item_description text;
  item_quantity numeric(12, 3);
  item_unit_amount_pence integer;
  item_line_total_pence integer;
  quote_total_pence bigint := 0;
  item_count integer;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.business_memberships membership
    where membership.business_id = target_business_id
      and membership.user_id = current_user_id
  ) then
    raise exception 'Business membership required';
  end if;

  if not exists (
    select 1 from public.customers customer
    where customer.id = target_customer_id
      and customer.business_id = target_business_id
  ) then
    raise exception 'Customer does not belong to business';
  end if;

  if nullif(trim(quote_job_title), '') is null
     or char_length(trim(quote_job_title)) > 160 then
    raise exception 'Invalid job title';
  end if;

  if nullif(trim(quote_scope), '') is null
     or char_length(trim(quote_scope)) > 10000 then
    raise exception 'Invalid quote scope';
  end if;

  if jsonb_typeof(quote_items) <> 'array' then
    raise exception 'Quote items must be an array';
  end if;

  item_count := jsonb_array_length(quote_items);
  if item_count < 1 or item_count > 25 then
    raise exception 'Quote must contain between 1 and 25 items';
  end if;

  for item_record in
    select value, ordinality
    from jsonb_array_elements(quote_items) with ordinality
  loop
    begin
      item_description := trim(item_record.value ->> 'description');
      item_quantity := (item_record.value ->> 'quantity')::numeric;
      item_unit_amount_pence := (item_record.value ->> 'unit_amount_pence')::integer;
    exception when others then
      raise exception 'Invalid quote item';
    end;

    if nullif(item_description, '') is null or char_length(item_description) > 1000
       or item_quantity <= 0 or item_quantity > 10000
       or item_quantity <> round(item_quantity, 3)
       or item_unit_amount_pence < 0 or item_unit_amount_pence > 100000000 then
      raise exception 'Invalid quote item';
    end if;

    item_line_total_pence := round(item_quantity * item_unit_amount_pence);
    quote_total_pence := quote_total_pence + item_line_total_pence;

    if item_line_total_pence > 2147483647 or quote_total_pence > 2147483647 then
      raise exception 'Quote total is too large';
    end if;

  end loop;

  if quote_total_pence <= 0 then
    raise exception 'Quote total must be greater than zero';
  end if;

  insert into public.quotes (id, business_id, customer_id, created_by)
  values (new_quote_id, target_business_id, target_customer_id, current_user_id);

  insert into public.quote_versions (
    id, quote_id, version_number, job_title, scope, total_pence, created_by
  ) values (
    new_version_id, new_quote_id, 1, trim(quote_job_title), trim(quote_scope), quote_total_pence::integer, current_user_id
  );

  for item_record in
    select value, ordinality
    from jsonb_array_elements(quote_items) with ordinality
  loop
    item_description := trim(item_record.value ->> 'description');
    item_quantity := (item_record.value ->> 'quantity')::numeric;
    item_unit_amount_pence := (item_record.value ->> 'unit_amount_pence')::integer;
    item_line_total_pence := round(item_quantity * item_unit_amount_pence);

    insert into public.quote_items (
      quote_version_id, sequence, description, quantity, unit_amount_pence, line_total_pence
    ) values (
      new_version_id, item_record.ordinality, item_description, item_quantity,
      item_unit_amount_pence, item_line_total_pence
    );
  end loop;

  insert into public.audit_events (
    business_id, event_type, actor_type, actor_id, entity_type, entity_id, metadata
  ) values (
    target_business_id,
    'QUOTE_CREATED',
    'USER',
    current_user_id,
    'QUOTE',
    new_quote_id,
    jsonb_build_object('version', 1, 'item_count', item_count, 'total_pence', quote_total_pence)
  );

  return new_quote_id;
end;
$$;

drop policy quotes_business_insert on public.quotes;
drop policy quotes_business_update on public.quotes;
drop policy quote_versions_business_insert on public.quote_versions;
drop policy quote_items_business_insert on public.quote_items;

revoke all on function public.create_quote(uuid, uuid, text, text, jsonb) from public;
grant execute on function public.create_quote(uuid, uuid, text, text, jsonb) to authenticated;

comment on function public.create_quote(uuid, uuid, text, text, jsonb) is
  'Atomically creates a tenant-scoped draft quote, version, calculated items and audit event.';
