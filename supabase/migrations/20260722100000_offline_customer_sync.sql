-- =============================================================
-- SureTakip - Sprint 1 offline-first customer push
-- Server-owned idempotency, payload hashing, conflict auditing and versioning.
-- =============================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------- Customer tombstones and optimistic concurrency version ----------
alter table public.customers
  add column server_version integer not null default 1,
  add column is_deleted boolean not null default false,
  add column deleted_at timestamptz;

-- updated_at remains the sole responsibility of the existing
-- trg_customers_updated_at trigger. This trigger only owns server_version.
create function public.bump_customer_server_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.server_version := old.server_version + 1;
  return new;
end;
$$;

create trigger trg_bump_customer_server_version
  before update on public.customers
  for each row execute function public.bump_customer_server_version();

revoke execute on function public.bump_customer_server_version()
  from public, anon, authenticated;

-- ---------- Server-only idempotency result ledger ----------
create table public.sync_processed_operations (
  idempotency_key       text primary key,
  operation_id          uuid not null unique,
  business_id           uuid not null references public.businesses(id),
  original_actor_user_id uuid not null,
  submitted_by_user_id   uuid not null,
  operation_type        text not null,
  payload_hash          text not null,
  result_json           jsonb not null,
  processed_at          timestamptz not null default pg_catalog.now()
);

create index idx_sync_processed_operations_business_processed
  on public.sync_processed_operations (business_id, processed_at);

revoke all on table public.sync_processed_operations
  from public, anon, authenticated;

-- ---------- Server-only append-only security event ledger ----------
create table public.security_events (
  id          bigint generated always as identity primary key,
  event_type  text not null,
  business_id uuid,
  user_id     uuid,
  detail      jsonb,
  created_at  timestamptz default pg_catalog.now()
);

revoke all on table public.security_events
  from public, anon, authenticated;

-- ---------- Offline customer creation RPC ----------
create function public.create_customer(
  p_operation_id uuid,
  p_idempotency_key text,
  p_business_id uuid,
  p_customer jsonb,
  p_payload_version integer
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id             uuid := auth.uid();
  v_existing            public.sync_processed_operations%rowtype;
  v_result              jsonb;
  v_normalized_payload  jsonb;
  v_server_payload_hash text;
  v_customer_id         uuid;
  v_inserted_customer_id uuid;
  v_name                text;
  v_phone               text;
  v_email               text;
  v_notes               text;
  v_server_version      integer;
  v_created_at          timestamptz;
  v_updated_at          timestamptz;
begin
  if v_user_id is null then
    return pg_catalog.jsonb_build_object('result', 'auth_required');
  end if;

  if p_payload_version is distinct from 1 then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'UNSUPPORTED_PAYLOAD_VERSION'
    );
  end if;

  if p_operation_id is null
     or p_business_id is null
     or p_idempotency_key is null
     or pg_catalog.char_length(p_idempotency_key) > 200 then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_IDEMPOTENCY_KEY'
    );
  end if;

  begin
    if p_customer is null
       or pg_catalog.jsonb_typeof(p_customer) <> 'object'
       or nullif(p_customer->>'id', '') is null then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_CUSTOMER_ID'
      );
    end if;
    v_customer_id := (p_customer->>'id')::uuid;
  exception
    when invalid_text_representation then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_CUSTOMER_ID'
      );
  end;

  if pg_catalog.jsonb_typeof(p_customer->'name') is distinct from 'string'
     or (p_customer ? 'phone'
         and pg_catalog.jsonb_typeof(p_customer->'phone') not in ('string', 'null'))
     or (p_customer ? 'email'
         and pg_catalog.jsonb_typeof(p_customer->'email') not in ('string', 'null'))
     or (p_customer ? 'notes'
         and pg_catalog.jsonb_typeof(p_customer->'notes') not in ('string', 'null')) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_CUSTOMER_PAYLOAD'
    );
  end if;

  v_name := pg_catalog.btrim(p_customer->>'name');
  v_phone := nullif(pg_catalog.btrim(p_customer->>'phone'), '');
  v_email := nullif(pg_catalog.btrim(p_customer->>'email'), '');
  v_notes := nullif(pg_catalog.btrim(p_customer->>'notes'), '');

  if v_name is null
     or pg_catalog.char_length(v_name) not between 1 and 120
     or pg_catalog.char_length(coalesce(v_phone, '')) > 30
     or pg_catalog.char_length(coalesce(v_email, '')) > 320
     or pg_catalog.char_length(coalesce(v_notes, '')) > 2000 then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_CUSTOMER_PAYLOAD'
    );
  end if;

  if not public.is_business_member(p_business_id) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'CUSTOMER_CREATE_FORBIDDEN'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'customer_id', v_customer_id,
      'name', v_name,
      'phone', v_phone,
      'email', v_email,
      'notes', v_notes
    )
  );

  v_server_payload_hash := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(v_normalized_payload::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );

  -- One transaction at a time may claim or replay a given key.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_idempotency_key, 0)
  );

  select *
    into v_existing
  from public.sync_processed_operations
  where idempotency_key = p_idempotency_key;

  if found then
    if v_existing.payload_hash <> v_server_payload_hash then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'IDEMPOTENCY_PAYLOAD_MISMATCH'
      );
    end if;

    return v_existing.result_json
           || pg_catalog.jsonb_build_object('result', 'already_processed');
  end if;

  if exists (
    select 1
    from public.sync_processed_operations
    where operation_id = p_operation_id
  ) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'OPERATION_ID_REUSED'
    );
  end if;

  insert into public.customers (
    id,
    business_id,
    name,
    phone,
    email,
    notes
  )
  values (
    v_customer_id,
    p_business_id,
    v_name,
    v_phone,
    v_email,
    v_notes
  )
  on conflict (id) do nothing
  returning id, server_version, created_at, updated_at
    into v_inserted_customer_id, v_server_version, v_created_at, v_updated_at;

  if v_inserted_customer_id is null then
    insert into public.security_events (
      event_type,
      business_id,
      user_id,
      detail
    )
    values (
      'customer_id_conflict',
      p_business_id,
      v_user_id,
      pg_catalog.jsonb_build_object('operation_id', p_operation_id)
    );

    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'CUSTOMER_ID_CONFLICT'
    );
  end if;

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'customer_id', v_inserted_customer_id,
    'server_version', v_server_version,
    'created_at_server', v_created_at,
    'updated_at_server', v_updated_at
  );

  insert into public.sync_processed_operations (
    idempotency_key,
    operation_id,
    business_id,
    original_actor_user_id,
    submitted_by_user_id,
    operation_type,
    payload_hash,
    result_json
  )
  values (
    p_idempotency_key,
    p_operation_id,
    p_business_id,
    v_user_id,
    v_user_id,
    'create_customer',
    v_server_payload_hash,
    v_result
  );

  return v_result;
exception
  when unique_violation then
    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'UNIQUE_CONSTRAINT_CONFLICT'
    );
end;
$$;

revoke execute on function public.create_customer(uuid, text, uuid, jsonb, integer)
  from public, anon;
grant execute on function public.create_customer(uuid, text, uuid, jsonb, integer)
  to authenticated;
