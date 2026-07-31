-- =============================================================
-- SureTakip - Sprint 1 offline-first customer update / activation
-- Aynı idempotency + payload hash + optimistic concurrency deseni
-- (create_customer ile birebir aynı) update ve aktif/pasif için.
-- =============================================================

-- ---------- Offline müşteri güncelleme RPC'si (tam alan) ----------
create function public.update_customer(
  p_operation_id uuid,
  p_idempotency_key text,
  p_business_id uuid,
  p_customer jsonb,
  p_expected_version integer,
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
  v_updated_customer_id uuid;
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
     or pg_catalog.char_length(p_idempotency_key) > 200
     or p_expected_version is null then
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
      'error_code', 'CUSTOMER_UPDATE_FORBIDDEN'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'customer_id', v_customer_id,
      'expected_version', p_expected_version,
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

  update public.customers
     set name = v_name,
         phone = v_phone,
         email = v_email,
         notes = v_notes
   where id = v_customer_id
     and business_id = p_business_id
     and server_version = p_expected_version
     and is_deleted = false
  returning id, server_version, created_at, updated_at
    into v_updated_customer_id, v_server_version, v_created_at, v_updated_at;

  if v_updated_customer_id is null then
    if not exists (
      select 1 from public.customers
      where id = v_customer_id and business_id = p_business_id and is_deleted = false
    ) then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'CUSTOMER_NOT_FOUND'
      );
    end if;

    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'STALE_VERSION'
    );
  end if;

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'customer_id', v_updated_customer_id,
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
    'update_customer',
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

revoke execute on function public.update_customer(uuid, text, uuid, jsonb, integer, integer)
  from public, anon;
grant execute on function public.update_customer(uuid, text, uuid, jsonb, integer, integer)
  to authenticated;

-- ---------- Offline müşteri aktif/pasif RPC'si (kısmi alan) ----------
create function public.set_customer_active(
  p_operation_id uuid,
  p_idempotency_key text,
  p_business_id uuid,
  p_customer_id uuid,
  p_is_active boolean,
  p_expected_version integer,
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
  v_updated_customer_id uuid;
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
     or p_customer_id is null
     or p_is_active is null
     or p_idempotency_key is null
     or pg_catalog.char_length(p_idempotency_key) > 200
     or p_expected_version is null then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_IDEMPOTENCY_KEY'
    );
  end if;

  if not public.is_business_member(p_business_id) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'CUSTOMER_UPDATE_FORBIDDEN'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'customer_id', p_customer_id,
      'expected_version', p_expected_version,
      'is_active', p_is_active
    )
  );

  v_server_payload_hash := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(v_normalized_payload::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );

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

  update public.customers
     set is_active = p_is_active,
         archived_at = case when p_is_active then null else pg_catalog.now() end
   where id = p_customer_id
     and business_id = p_business_id
     and server_version = p_expected_version
     and is_deleted = false
  returning id, server_version, created_at, updated_at
    into v_updated_customer_id, v_server_version, v_created_at, v_updated_at;

  if v_updated_customer_id is null then
    if not exists (
      select 1 from public.customers
      where id = p_customer_id and business_id = p_business_id and is_deleted = false
    ) then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'CUSTOMER_NOT_FOUND'
      );
    end if;

    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'STALE_VERSION'
    );
  end if;

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'customer_id', v_updated_customer_id,
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
    'set_customer_active',
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

revoke execute on function public.set_customer_active(uuid, text, uuid, uuid, boolean, integer, integer)
  from public, anon;
grant execute on function public.set_customer_active(uuid, text, uuid, uuid, boolean, integer, integer)
  to authenticated;
