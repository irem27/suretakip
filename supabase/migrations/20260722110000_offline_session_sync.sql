-- =============================================================
-- SureTakip - Faz C / C2 offline-first session push
-- Client-timestamped start/pause/resume events with server-owned
-- snapshots, idempotency, payload hashing and conflict auditing.
-- =============================================================

-- ---------- Offline session start RPC ----------
create function public.sync_start_session(
  p_operation_id uuid,
  p_idempotency_key text,
  p_business_id uuid,
  p_session jsonb,
  p_payload_version integer
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id              uuid := auth.uid();
  v_member_id            uuid;
  v_existing             public.sync_processed_operations%rowtype;
  v_service              public.services%rowtype;
  v_result               jsonb;
  v_normalized_payload   jsonb;
  v_server_payload_hash  text;
  v_session_id           uuid;
  v_inserted_session_id  uuid;
  v_service_id           uuid;
  v_customer_id          uuid;
  v_first_entry_id       uuid;
  v_started_at           timestamptz;
  v_notes                text;
  v_started_offline      boolean;
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
    if p_session is null
       or pg_catalog.jsonb_typeof(p_session) <> 'object'
       or pg_catalog.jsonb_typeof(p_session->'session_id') is distinct from 'string'
       or pg_catalog.jsonb_typeof(p_session->'service_id') is distinct from 'string'
       or pg_catalog.jsonb_typeof(p_session->'first_entry_id') is distinct from 'string'
       or pg_catalog.jsonb_typeof(p_session->'started_at') is distinct from 'string'
       or (p_session ? 'customer_id'
           and pg_catalog.jsonb_typeof(p_session->'customer_id') not in ('string', 'null'))
       or (p_session ? 'notes'
           and pg_catalog.jsonb_typeof(p_session->'notes') not in ('string', 'null'))
       or pg_catalog.jsonb_typeof(p_session->'started_offline') is distinct from 'boolean' then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_SESSION_PAYLOAD'
      );
    end if;

    v_session_id := (p_session->>'session_id')::uuid;
    v_service_id := (p_session->>'service_id')::uuid;
    v_customer_id := nullif(p_session->>'customer_id', '')::uuid;
    v_first_entry_id := (p_session->>'first_entry_id')::uuid;
    v_started_at := (p_session->>'started_at')::timestamptz;
    v_notes := p_session->>'notes';
    v_started_offline := (p_session->>'started_offline')::boolean;
  exception
    when invalid_text_representation
      or invalid_datetime_format
      or datetime_field_overflow then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_SESSION_PAYLOAD'
      );
  end;

  v_member_id := public.active_member_id(p_business_id);
  if v_member_id is null then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'SESSION_START_FORBIDDEN'
    );
  end if;

  select *
    into v_service
  from public.services
  where id = v_service_id
    and business_id = p_business_id
    and is_active
    and archived_at is null;

  if not found then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'SERVICE_NOT_AVAILABLE'
    );
  end if;

  if v_customer_id is not null and not exists (
    select 1
    from public.customers
    where id = v_customer_id
      and business_id = p_business_id
      and is_active
  ) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'CUSTOMER_NOT_FOUND'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'session_id', v_session_id,
      'service_id', v_service_id,
      'customer_id', v_customer_id,
      'started_at', v_started_at,
      'first_entry_id', v_first_entry_id,
      'notes', v_notes,
      'started_offline', v_started_offline
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

  insert into public.sessions (
    id,
    business_id,
    customer_id,
    service_id,
    opened_by_member_id,
    status,
    started_at,
    notes,
    service_name_snapshot,
    price_per_minute_minor_snapshot,
    rounding_interval_minutes_snapshot,
    minimum_charge_minutes_snapshot,
    currency_code_snapshot
  )
  values (
    v_session_id,
    p_business_id,
    v_customer_id,
    v_service_id,
    v_member_id,
    'active',
    v_started_at,
    v_notes,
    v_service.name,
    v_service.price_per_minute_minor,
    v_service.rounding_interval_minutes,
    v_service.minimum_charge_minutes,
    v_service.currency_code
  )
  on conflict (id) do nothing
  returning id into v_inserted_session_id;

  if v_inserted_session_id is null then
    insert into public.security_events (
      event_type,
      business_id,
      user_id,
      detail
    )
    values (
      'session_id_conflict',
      p_business_id,
      v_user_id,
      pg_catalog.jsonb_build_object('operation_id', p_operation_id)
    );

    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'SESSION_ID_CONFLICT'
    );
  end if;

  insert into public.session_time_entries (
    id,
    business_id,
    session_id,
    entry_type,
    started_at
  )
  values (
    v_first_entry_id,
    p_business_id,
    v_inserted_session_id,
    'active',
    v_started_at
  );

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'session_id', v_inserted_session_id,
    'created_at_server', pg_catalog.now(),
    'started_at', v_started_at,
    'status', 'active'
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
    'sync_start_session',
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

revoke execute on function public.sync_start_session(uuid, text, uuid, jsonb, integer)
  from public, anon;
grant execute on function public.sync_start_session(uuid, text, uuid, jsonb, integer)
  to authenticated;

-- ---------- Offline pause/resume event RPC ----------
create function public.sync_session_event(
  p_operation_id uuid,
  p_idempotency_key text,
  p_business_id uuid,
  p_event jsonb,
  p_payload_version integer
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id              uuid := auth.uid();
  v_member_id            uuid;
  v_existing             public.sync_processed_operations%rowtype;
  v_session              public.sessions%rowtype;
  v_result               jsonb;
  v_normalized_payload   jsonb;
  v_server_payload_hash  text;
  v_session_id           uuid;
  v_event_type           text;
  v_event_id             uuid;
  v_occurred_at          timestamptz;
  v_new_status           public.session_status;
  v_new_entry_type       public.time_entry_type;
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
    if p_event is null
       or pg_catalog.jsonb_typeof(p_event) <> 'object'
       or pg_catalog.jsonb_typeof(p_event->'session_id') is distinct from 'string'
       or pg_catalog.jsonb_typeof(p_event->'event_id') is distinct from 'string'
       or pg_catalog.jsonb_typeof(p_event->'occurred_at') is distinct from 'string' then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_SESSION_EVENT_PAYLOAD'
      );
    end if;

    v_session_id := (p_event->>'session_id')::uuid;
    v_event_id := (p_event->>'event_id')::uuid;
    v_occurred_at := (p_event->>'occurred_at')::timestamptz;
  exception
    when invalid_text_representation
      or invalid_datetime_format
      or datetime_field_overflow then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_SESSION_EVENT_PAYLOAD'
      );
  end;

  if pg_catalog.jsonb_typeof(p_event->'event_type') is distinct from 'string' then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'UNSUPPORTED_EVENT_TYPE'
    );
  end if;

  v_event_type := p_event->>'event_type';
  if v_event_type not in ('pause', 'resume') then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'UNSUPPORTED_EVENT_TYPE'
    );
  end if;

  if not exists (
    select 1
    from public.sessions
    where id = v_session_id
      and business_id = p_business_id
  ) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'SESSION_NOT_FOUND'
    );
  end if;

  v_member_id := public.active_member_id(p_business_id);
  if v_member_id is null then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'SESSION_EVENT_FORBIDDEN'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'session_id', v_session_id,
      'event_type', v_event_type,
      'event_id', v_event_id,
      'occurred_at', v_occurred_at
    )
  );

  v_server_payload_hash := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(v_normalized_payload::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );

  -- Replay must be resolved before checking the session's current state.
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

  -- Different idempotency keys targeting one session are serialized here.
  select *
    into v_session
  from public.sessions
  where id = v_session_id
    and business_id = p_business_id
  for update;

  if not found then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'SESSION_NOT_FOUND'
    );
  end if;

  if v_event_type = 'pause' then
    if v_session.status <> 'active' then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'INVALID_SESSION_STATE'
      );
    end if;
    v_new_status := 'paused';
    v_new_entry_type := 'paused';
  else
    if v_session.status <> 'paused' then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'INVALID_SESSION_STATE'
      );
    end if;
    v_new_status := 'active';
    v_new_entry_type := 'active';
  end if;

  update public.session_time_entries
     set ended_at = v_occurred_at
   where business_id = p_business_id
     and session_id = v_session_id
     and ended_at is null;

  insert into public.session_time_entries (
    id,
    business_id,
    session_id,
    entry_type,
    started_at
  )
  values (
    v_event_id,
    p_business_id,
    v_session_id,
    v_new_entry_type,
    v_occurred_at
  );

  update public.sessions
     set status = v_new_status
   where id = v_session_id
     and business_id = p_business_id;

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'session_id', v_session_id,
    'event_type', v_event_type,
    'status', v_new_status
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
    'sync_session_event',
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

revoke execute on function public.sync_session_event(uuid, text, uuid, jsonb, integer)
  from public, anon;
grant execute on function public.sync_session_event(uuid, text, uuid, jsonb, integer)
  to authenticated;
