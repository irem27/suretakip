-- Fix: sync_session_event içindeki `pg_catalog.greatest` HATALI —
-- greatest bir pg_catalog fonksiyonu değil, SQL keyword ifadesidir.
-- search_path='' altında `pg_catalog.greatest` çözülemiyor ve TÜM offline
-- seans TAMAMLAMA (complete) sunucuda patlıyordu. `greatest` olarak düzeltir.
-- Fonksiyon CREATE OR REPLACE ile yeniden tanımlanır (veri kaybı yok).

create or replace function public.sync_session_event(
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
  v_product              public.products%rowtype;
  v_result               jsonb;
  v_normalized_payload   jsonb;
  v_server_payload_hash  text;
  v_session_id           uuid;
  v_event_type           text;
  v_event_id             uuid;
  v_product_id           uuid;
  v_occurred_at          timestamptz;
  v_new_status           public.session_status;
  v_new_entry_type       public.time_entry_type;
  v_discount_minor       bigint := 0;
  v_tax_minor            bigint := 0;
  v_quantity             bigint;
  v_line_total           bigint;
  v_active_seconds       numeric;
  v_charged_minutes      integer;
  v_service_subtotal     bigint;
  v_products_subtotal    bigint;
  v_grand_total          bigint;
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
  if v_event_type not in (
    'pause',
    'resume',
    'add_product',
    'complete',
    'cancel'
  ) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'UNSUPPORTED_EVENT_TYPE'
    );
  end if;

  if v_event_type = 'complete' then
    begin
      v_discount_minor := coalesce((p_event->>'discount_minor')::bigint, 0);
      v_tax_minor := coalesce((p_event->>'tax_minor')::bigint, 0);
    exception
      when invalid_text_representation or numeric_value_out_of_range then
        return pg_catalog.jsonb_build_object(
          'result', 'rejected',
          'error_code', 'INVALID_AMOUNT'
        );
    end;
    if v_discount_minor < 0 or v_tax_minor < 0 then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_AMOUNT'
      );
    end if;
  elsif v_event_type = 'add_product' then
    begin
      v_product_id := (p_event->>'product_id')::uuid;
      v_quantity := (p_event->>'quantity')::bigint;
      v_discount_minor := coalesce((p_event->>'discount_minor')::bigint, 0);
      v_tax_minor := coalesce((p_event->>'tax_minor')::bigint, 0);
    exception
      when invalid_text_representation or numeric_value_out_of_range then
        return pg_catalog.jsonb_build_object(
          'result', 'rejected',
          'error_code', 'INVALID_PRODUCT_EVENT'
        );
    end;
    if v_product_id is null
       or v_quantity is null
       or v_quantity <= 0
       or v_discount_minor < 0
       or v_tax_minor < 0 then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_PRODUCT_EVENT'
      );
    end if;
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'session_id', v_session_id,
      'event_type', v_event_type,
      'event_id', v_event_id,
      'occurred_at', v_occurred_at,
      'product_id', case when v_event_type = 'add_product' then v_product_id end,
      'quantity', case when v_event_type = 'add_product' then v_quantity end,
      'discount_minor', case
        when v_event_type in ('add_product', 'complete') then v_discount_minor
      end,
      'tax_minor', case
        when v_event_type in ('add_product', 'complete') then v_tax_minor
      end
    )
  );

  v_server_payload_hash := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(v_normalized_payload::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );

  -- Replay must be resolved before checking time or current session state.
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

  if v_occurred_at < pg_catalog.clock_timestamp() - interval '7 days'
     or v_occurred_at > pg_catalog.clock_timestamp() + interval '5 minutes' then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'CLIENT_TIME_OUT_OF_RANGE'
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

  if exists (
    select 1
    from public.session_time_entries
    where business_id = p_business_id
      and session_id = v_session_id
      and ended_at is null
      and started_at > v_occurred_at
  ) then
    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'EVENT_TIME_BEFORE_OPEN_INTERVAL'
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
  elsif v_event_type = 'resume' then
    if v_session.status <> 'paused' then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'INVALID_SESSION_STATE'
      );
    end if;
    v_new_status := 'active';
    v_new_entry_type := 'active';
  elsif v_event_type = 'add_product' then
    if v_session.status not in ('active', 'paused') then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'INVALID_SESSION_STATE'
      );
    end if;
    v_new_status := v_session.status;
  elsif v_event_type = 'complete' then
    if v_session.status not in ('active', 'paused') then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'INVALID_SESSION_STATE'
      );
    end if;
    v_new_status := 'completed';
  else
    if v_session.status not in ('active', 'paused') then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'INVALID_SESSION_STATE'
      );
    end if;
    v_new_status := 'cancelled';
  end if;

  if v_event_type <> 'add_product' then
    update public.session_time_entries
       set ended_at = v_occurred_at
     where business_id = p_business_id
       and session_id = v_session_id
       and ended_at is null;
  end if;

  if v_event_type in ('pause', 'resume') then
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
  elsif v_event_type = 'add_product' then
    select *
      into v_product
    from public.products
    where id = v_product_id
      and business_id = p_business_id
    for update;

    if not found
       or not v_product.is_active
       or v_product.archived_at is not null then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'PRODUCT_NOT_AVAILABLE'
      );
    end if;
    if v_product.currency_code <> v_session.currency_code_snapshot then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'CURRENCY_MISMATCH'
      );
    end if;
    if v_product.track_stock and v_product.stock_quantity < v_quantity then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'INSUFFICIENT_STOCK'
      );
    end if;

    v_line_total :=
      v_product.unit_price_minor * v_quantity
      - v_discount_minor
      + v_tax_minor;
    if v_line_total < 0 then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_DISCOUNT'
      );
    end if;

    insert into public.session_items (
      id,
      business_id,
      session_id,
      product_id,
      product_name_snapshot,
      sku_snapshot,
      unit_price_minor_snapshot,
      currency_code_snapshot,
      quantity,
      discount_minor,
      tax_minor,
      line_total_minor
    )
    values (
      v_event_id,
      p_business_id,
      v_session_id,
      v_product_id,
      v_product.name,
      v_product.sku,
      v_product.unit_price_minor,
      v_product.currency_code,
      v_quantity,
      v_discount_minor,
      v_tax_minor,
      v_line_total
    );

    if v_product.track_stock then
      insert into public.inventory_movements (
        business_id,
        product_id,
        session_item_id,
        movement_type,
        quantity_delta,
        created_by_member_id
      )
      values (
        p_business_id,
        v_product_id,
        v_event_id,
        'sale',
        -v_quantity,
        v_member_id
      );
    end if;
  elsif v_event_type = 'complete' then
    select coalesce(
             pg_catalog.sum(
               extract(epoch from (ended_at - started_at))
             ),
             0
           )
      into v_active_seconds
    from public.session_time_entries
    where session_id = v_session_id
      and entry_type = 'active';

    v_charged_minutes := greatest(
      (
        pg_catalog.ceil(
          (v_active_seconds / 60.0)
          / v_session.rounding_interval_minutes_snapshot
        ) * v_session.rounding_interval_minutes_snapshot
      )::integer,
      v_session.minimum_charge_minutes_snapshot
    );
    v_service_subtotal :=
      v_charged_minutes::bigint * v_session.price_per_minute_minor_snapshot;

    select coalesce(pg_catalog.sum(line_total_minor), 0)
      into v_products_subtotal
    from public.session_items
    where session_id = v_session_id;

    v_grand_total :=
      v_service_subtotal + v_products_subtotal
      - v_discount_minor + v_tax_minor;
    if v_grand_total < 0 then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_DISCOUNT'
      );
    end if;

    update public.sessions
       set status = 'completed',
           ended_at = v_occurred_at,
           closed_by_member_id = v_member_id,
           charged_minutes = v_charged_minutes,
           service_subtotal_minor = v_service_subtotal,
           products_subtotal_minor = v_products_subtotal,
           discount_minor = v_discount_minor,
           tax_minor = v_tax_minor,
           grand_total_minor = v_grand_total
     where id = v_session_id
       and business_id = p_business_id;
  else
    insert into public.inventory_movements (
      business_id,
      product_id,
      session_item_id,
      movement_type,
      quantity_delta,
      created_by_member_id
    )
    select
      si.business_id,
      si.product_id,
      si.id,
      'sale_reversal',
      si.quantity,
      v_member_id
    from public.session_items si
    join public.products p on p.id = si.product_id
    where si.session_id = v_session_id
      and p.track_stock
      and exists (
        select 1
        from public.inventory_movements im
        where im.session_item_id = si.id
          and im.movement_type = 'sale'
      )
    on conflict (session_item_id, movement_type)
      where session_item_id is not null
    do nothing;

    update public.sessions
       set status = 'cancelled',
           ended_at = v_occurred_at,
           closed_by_member_id = v_member_id
     where id = v_session_id
       and business_id = p_business_id;
  end if;

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
