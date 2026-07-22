-- =============================================================
-- SureTakip - Sprint 2 server-side delta sync and customer snapshot
-- Monotonic change feed, customer feed trigger and tenant-scoped pull RPCs.
-- =============================================================

-- ---------- Server-only monotonic change feed ----------
create table if not exists public.sync_changes (
  change_seq     bigint generated always as identity primary key,
  business_id    uuid not null,
  entity_type    text not null,
  entity_id      uuid not null,
  operation      text not null check (operation in ('upsert', 'delete')),
  server_version integer not null,
  payload        jsonb,
  changed_at     timestamptz not null default pg_catalog.now()
);

create index if not exists idx_sync_changes_business_change_seq
  on public.sync_changes (business_id, change_seq);

revoke all on table public.sync_changes
  from public, anon, authenticated;
revoke all on sequence public.sync_changes_change_seq_seq
  from public, anon, authenticated;

-- ---------- Every customer insert/update enters the change feed ----------
-- SECURITY DEFINER is required because authenticated members may update the
-- domain table directly while sync_changes intentionally has no client grants.
create or replace function public.record_customer_sync_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.sync_changes (
    business_id,
    entity_type,
    entity_id,
    operation,
    server_version,
    payload
  )
  values (
    new.business_id,
    'customer',
    new.id,
    case when new.is_deleted then 'delete' else 'upsert' end,
    new.server_version,
    pg_catalog.jsonb_build_object(
      'id', new.id,
      'business_id', new.business_id,
      'name', new.name,
      'phone', new.phone,
      'email', new.email,
      'notes', new.notes,
      'is_active', new.is_active,
      'server_version', new.server_version,
      'created_at', new.created_at,
      'updated_at', new.updated_at,
      'is_deleted', new.is_deleted,
      'deleted_at', new.deleted_at
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_customers_to_sync_changes on public.customers;
create trigger trg_customers_to_sync_changes
  after insert or update on public.customers
  for each row execute function public.record_customer_sync_change();

-- PostgreSQL completes every BEFORE ROW trigger before firing AFTER ROW
-- triggers. Therefore this feed sees both the bumped server_version and the
-- final updated_at regardless of alphabetical trigger naming.
revoke execute on function public.record_customer_sync_change()
  from public, anon, authenticated;

-- ---------- Incremental change pull ----------
create or replace function public.get_changes(
  p_business_id uuid,
  p_cursor bigint,
  p_limit integer default 500
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id        uuid := auth.uid();
  v_cursor         bigint := greatest(coalesce(p_cursor, 0), 0);
  -- Üst sınır: istemci aşırı büyük limit göndererek DoS oluşturamaz.
  v_limit          integer := least(greatest(coalesce(p_limit, 500), 1), 1000);
  v_min_change_seq bigint;
  v_changes        jsonb;
  v_change_count   integer;
  v_next_cursor    bigint;
begin
  if v_user_id is null then
    return pg_catalog.jsonb_build_object('result', 'auth_required');
  end if;

  if not public.is_business_member(p_business_id) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'FORBIDDEN'
    );
  end if;

  select min(change_seq)
    into v_min_change_seq
  from public.sync_changes
  where business_id = p_business_id;

  if v_cursor > 0
     and v_min_change_seq is not null
     and v_cursor < (v_min_change_seq - 1) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'CURSOR_TOO_OLD'
    );
  end if;

  with selected_changes as (
    select
      change_seq,
      entity_type,
      entity_id,
      operation,
      server_version,
      payload
    from public.sync_changes
    where business_id = p_business_id
      and change_seq > v_cursor
    order by change_seq
    limit v_limit
  )
  select
    coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'change_seq', change_seq,
          'entity_type', entity_type,
          'entity_id', entity_id,
          'operation', operation,
          'server_version', server_version,
          'payload', payload
        )
        order by change_seq
      ),
      '[]'::jsonb
    ),
    count(*),
    coalesce(max(change_seq), v_cursor)
  into v_changes, v_change_count, v_next_cursor
  from selected_changes;

  return pg_catalog.jsonb_build_object(
    'result', 'ok',
    'changes', v_changes,
    'next_cursor', v_next_cursor,
    'has_more', v_change_count = v_limit,
    'server_time', pg_catalog.now()
  );
end;
$$;

revoke execute on function public.get_changes(uuid, bigint, integer)
  from public, anon;
grant execute on function public.get_changes(uuid, bigint, integer)
  to authenticated;

-- ---------- Bootstrap/full-resync customer snapshot ----------
create or replace function public.get_customers_snapshot(
  p_business_id uuid,
  p_after_id uuid default null,
  p_limit integer default 500
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id       uuid := auth.uid();
  -- Üst sınır: istemci aşırı büyük limit göndererek DoS oluşturamaz.
  v_limit         integer := least(greatest(coalesce(p_limit, 500), 1), 1000);
  v_server_cursor bigint;
  v_customers     jsonb;
  v_customer_count integer;
  v_next_after_id uuid;
begin
  if v_user_id is null then
    return pg_catalog.jsonb_build_object('result', 'auth_required');
  end if;

  if not public.is_business_member(p_business_id) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'FORBIDDEN'
    );
  end if;

  -- Capture before reading the page so changes concurrent with the snapshot
  -- can subsequently be recovered through get_changes.
  select coalesce(max(change_seq), 0)
    into v_server_cursor
  from public.sync_changes
  where business_id = p_business_id;

  with selected_customers as (
    select
      id,
      business_id,
      name,
      phone,
      email,
      notes,
      is_active,
      server_version,
      created_at,
      updated_at
    from public.customers
    where business_id = p_business_id
      and is_deleted = false
      and (p_after_id is null or id > p_after_id)
    order by id
    limit v_limit
  )
  select
    coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', id,
          'business_id', business_id,
          'name', name,
          'phone', phone,
          'email', email,
          'notes', notes,
          'is_active', is_active,
          'server_version', server_version,
          'created_at', created_at,
          'updated_at', updated_at
        )
        order by id
      ),
      '[]'::jsonb
    ),
    count(*),
    (pg_catalog.array_agg(id order by id desc))[1]
  into v_customers, v_customer_count, v_next_after_id
  from selected_customers;

  return pg_catalog.jsonb_build_object(
    'result', 'ok',
    'customers', v_customers,
    'next_after_id', v_next_after_id,
    'has_more', v_customer_count = v_limit,
    'server_cursor', v_server_cursor
  );
end;
$$;

revoke execute on function public.get_customers_snapshot(uuid, uuid, integer)
  from public, anon;
grant execute on function public.get_customers_snapshot(uuid, uuid, integer)
  to authenticated;
