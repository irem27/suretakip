-- =============================================================
-- SureTakip - Offline-first ürün (products) ve hizmet (services) katalog
-- yazma yolu. create_customer/update_customer/set_customer_active ile
-- BİREBİR AYNI idempotency + payload hash + optimistic concurrency deseni.
--
-- Ürün özel durumu: stock_quantity yalnız inventory_movements ledger
-- trigger'ı (apply_inventory_movement) tarafından yazılabilir
-- (20260718090000_product_write_hardening.sql, trg_guard_product_stock_write).
-- create_product bu yüzden ürünü DAİMA stock_quantity = 0 ile açar; ilk stok
-- varsa create_product_with_stock ile aynı şekilde 'initial' ledger kaydı
-- olarak eklenir. update_product stock_quantity/currency_code/business_id
-- alanlarına hiç dokunmaz (mevcut column-level GRANT kısıtıyla tutarlı).
-- =============================================================

-- ---------- Tombstone ve optimistic concurrency version ----------
alter table public.products
  add column server_version integer not null default 1,
  add column is_deleted boolean not null default false,
  add column deleted_at timestamptz;

alter table public.services
  add column server_version integer not null default 1,
  add column is_deleted boolean not null default false,
  add column deleted_at timestamptz;

create function public.bump_product_server_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.server_version := old.server_version + 1;
  return new;
end;
$$;

create trigger trg_bump_product_server_version
  before update on public.products
  for each row execute function public.bump_product_server_version();

revoke execute on function public.bump_product_server_version()
  from public, anon, authenticated;

create function public.bump_service_server_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.server_version := old.server_version + 1;
  return new;
end;
$$;

create trigger trg_bump_service_server_version
  before update on public.services
  for each row execute function public.bump_service_server_version();

revoke execute on function public.bump_service_server_version()
  from public, anon, authenticated;

-- =============================================================
-- ---------- Offline ürün oluşturma RPC'si ----------
-- =============================================================
create function public.create_product(
  p_operation_id uuid,
  p_idempotency_key text,
  p_business_id uuid,
  p_product jsonb,
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
  v_product_id          uuid;
  v_inserted_product_id uuid;
  v_member_id           uuid;
  v_name                text;
  v_sku                 text;
  v_unit_price_minor    bigint;
  v_currency_code       text;
  v_track_stock         boolean;
  v_initial_stock       bigint;
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
    if p_product is null
       or pg_catalog.jsonb_typeof(p_product) <> 'object'
       or nullif(p_product->>'id', '') is null then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_PRODUCT_ID'
      );
    end if;
    v_product_id := (p_product->>'id')::uuid;
  exception
    when invalid_text_representation then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_PRODUCT_ID'
      );
  end;

  if pg_catalog.jsonb_typeof(p_product->'name') is distinct from 'string'
     or (p_product ? 'sku'
         and pg_catalog.jsonb_typeof(p_product->'sku') not in ('string', 'null'))
     or pg_catalog.jsonb_typeof(p_product->'unit_price_minor') is distinct from 'number'
     or pg_catalog.jsonb_typeof(p_product->'currency_code') is distinct from 'string'
     or pg_catalog.jsonb_typeof(p_product->'track_stock') is distinct from 'boolean' then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_PRODUCT_PAYLOAD'
    );
  end if;

  v_name := pg_catalog.btrim(p_product->>'name');
  v_sku := nullif(pg_catalog.btrim(p_product->>'sku'), '');
  v_unit_price_minor := (p_product->>'unit_price_minor')::bigint;
  v_currency_code := pg_catalog.upper(pg_catalog.btrim(p_product->>'currency_code'));
  v_track_stock := (p_product->>'track_stock')::boolean;
  v_initial_stock := coalesce((p_product->>'initial_stock')::bigint, 0);

  if v_name is null
     or pg_catalog.char_length(v_name) not between 1 and 120
     or pg_catalog.char_length(coalesce(v_sku, '')) > 80
     or v_unit_price_minor < 0
     or v_currency_code !~ '^[A-Z]{3}$'
     or v_initial_stock < 0 then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_PRODUCT_PAYLOAD'
    );
  end if;

  if not public.has_business_role(
       p_business_id, array['owner','admin']::public.member_role[]
     ) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'PRODUCT_CREATE_FORBIDDEN'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'product_id', v_product_id,
      'name', v_name,
      'sku', v_sku,
      'unit_price_minor', v_unit_price_minor,
      'currency_code', v_currency_code,
      'track_stock', v_track_stock,
      'initial_stock', v_initial_stock
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

  insert into public.products (
    id,
    business_id,
    name,
    sku,
    unit_price_minor,
    currency_code,
    track_stock
  )
  values (
    v_product_id,
    p_business_id,
    v_name,
    v_sku,
    v_unit_price_minor,
    v_currency_code,
    v_track_stock
  )
  on conflict (id) do nothing
  returning id into v_inserted_product_id;

  if v_inserted_product_id is null then
    insert into public.security_events (
      event_type,
      business_id,
      user_id,
      detail
    )
    values (
      'product_id_conflict',
      p_business_id,
      v_user_id,
      pg_catalog.jsonb_build_object('operation_id', p_operation_id)
    );

    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'PRODUCT_ID_CONFLICT'
    );
  end if;

  -- İlk stok yalnızca stok takipli ve pozitifse ledger'a yazılır
  -- (create_product_with_stock ile aynı davranış).
  if v_track_stock and v_initial_stock > 0 then
    v_member_id := public.active_member_id(p_business_id);
    insert into public.inventory_movements (
      business_id, product_id, movement_type, quantity_delta,
      note, created_by_member_id
    )
    values (
      p_business_id, v_inserted_product_id, 'initial', v_initial_stock,
      'İlk stok', v_member_id
    );
  end if;

  select server_version, created_at, updated_at
    into v_server_version, v_created_at, v_updated_at
  from public.products
  where id = v_inserted_product_id;

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'product_id', v_inserted_product_id,
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
    'create_product',
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

revoke execute on function public.create_product(uuid, text, uuid, jsonb, integer)
  from public, anon;
grant execute on function public.create_product(uuid, text, uuid, jsonb, integer)
  to authenticated;

-- =============================================================
-- ---------- Offline ürün güncelleme RPC'si (kısıtlı alan) ----------
-- Yalnızca name, sku, unit_price_minor, track_stock değişir; stock_quantity/
-- currency_code/business_id GÖNDERİLMEZ (Katman 1 GRANT ile tutarlı).
-- =============================================================
create function public.update_product(
  p_operation_id uuid,
  p_idempotency_key text,
  p_business_id uuid,
  p_product jsonb,
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
  v_user_id            uuid := auth.uid();
  v_existing           public.sync_processed_operations%rowtype;
  v_result             jsonb;
  v_normalized_payload jsonb;
  v_server_payload_hash text;
  v_product_id         uuid;
  v_updated_product_id uuid;
  v_name               text;
  v_sku                text;
  v_unit_price_minor   bigint;
  v_track_stock        boolean;
  v_server_version     integer;
  v_created_at         timestamptz;
  v_updated_at         timestamptz;
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
    if p_product is null
       or pg_catalog.jsonb_typeof(p_product) <> 'object'
       or nullif(p_product->>'id', '') is null then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_PRODUCT_ID'
      );
    end if;
    v_product_id := (p_product->>'id')::uuid;
  exception
    when invalid_text_representation then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_PRODUCT_ID'
      );
  end;

  if pg_catalog.jsonb_typeof(p_product->'name') is distinct from 'string'
     or (p_product ? 'sku'
         and pg_catalog.jsonb_typeof(p_product->'sku') not in ('string', 'null'))
     or pg_catalog.jsonb_typeof(p_product->'unit_price_minor') is distinct from 'number'
     or pg_catalog.jsonb_typeof(p_product->'track_stock') is distinct from 'boolean' then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_PRODUCT_PAYLOAD'
    );
  end if;

  v_name := pg_catalog.btrim(p_product->>'name');
  v_sku := nullif(pg_catalog.btrim(p_product->>'sku'), '');
  v_unit_price_minor := (p_product->>'unit_price_minor')::bigint;
  v_track_stock := (p_product->>'track_stock')::boolean;

  if v_name is null
     or pg_catalog.char_length(v_name) not between 1 and 120
     or pg_catalog.char_length(coalesce(v_sku, '')) > 80
     or v_unit_price_minor < 0 then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_PRODUCT_PAYLOAD'
    );
  end if;

  if not public.has_business_role(
       p_business_id, array['owner','admin']::public.member_role[]
     ) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'PRODUCT_UPDATE_FORBIDDEN'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'product_id', v_product_id,
      'expected_version', p_expected_version,
      'name', v_name,
      'sku', v_sku,
      'unit_price_minor', v_unit_price_minor,
      'track_stock', v_track_stock
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

  update public.products
     set name = v_name,
         sku = v_sku,
         unit_price_minor = v_unit_price_minor,
         track_stock = v_track_stock
   where id = v_product_id
     and business_id = p_business_id
     and server_version = p_expected_version
     and is_deleted = false
  returning id, server_version, created_at, updated_at
    into v_updated_product_id, v_server_version, v_created_at, v_updated_at;

  if v_updated_product_id is null then
    if not exists (
      select 1 from public.products
      where id = v_product_id and business_id = p_business_id and is_deleted = false
    ) then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'PRODUCT_NOT_FOUND'
      );
    end if;

    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'STALE_VERSION'
    );
  end if;

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'product_id', v_updated_product_id,
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
    'update_product',
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

revoke execute on function public.update_product(uuid, text, uuid, jsonb, integer, integer)
  from public, anon;
grant execute on function public.update_product(uuid, text, uuid, jsonb, integer, integer)
  to authenticated;

-- =============================================================
-- ---------- Offline ürün aktif/pasif RPC'si (kısmi alan) ----------
-- =============================================================
create function public.set_product_active(
  p_operation_id uuid,
  p_idempotency_key text,
  p_business_id uuid,
  p_product_id uuid,
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
  v_user_id            uuid := auth.uid();
  v_existing           public.sync_processed_operations%rowtype;
  v_result             jsonb;
  v_normalized_payload jsonb;
  v_server_payload_hash text;
  v_updated_product_id uuid;
  v_server_version     integer;
  v_created_at         timestamptz;
  v_updated_at         timestamptz;
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
     or p_product_id is null
     or p_is_active is null
     or p_idempotency_key is null
     or pg_catalog.char_length(p_idempotency_key) > 200
     or p_expected_version is null then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_IDEMPOTENCY_KEY'
    );
  end if;

  if not public.has_business_role(
       p_business_id, array['owner','admin']::public.member_role[]
     ) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'PRODUCT_UPDATE_FORBIDDEN'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'product_id', p_product_id,
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

  update public.products
     set is_active = p_is_active,
         archived_at = case when p_is_active then null else pg_catalog.now() end
   where id = p_product_id
     and business_id = p_business_id
     and server_version = p_expected_version
     and is_deleted = false
  returning id, server_version, created_at, updated_at
    into v_updated_product_id, v_server_version, v_created_at, v_updated_at;

  if v_updated_product_id is null then
    if not exists (
      select 1 from public.products
      where id = p_product_id and business_id = p_business_id and is_deleted = false
    ) then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'PRODUCT_NOT_FOUND'
      );
    end if;

    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'STALE_VERSION'
    );
  end if;

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'product_id', v_updated_product_id,
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
    'set_product_active',
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

revoke execute on function public.set_product_active(uuid, text, uuid, uuid, boolean, integer, integer)
  from public, anon;
grant execute on function public.set_product_active(uuid, text, uuid, uuid, boolean, integer, integer)
  to authenticated;

-- =============================================================
-- ---------- Offline hizmet oluşturma RPC'si ----------
-- create_customer ile birebir aynı desen; services kolonlarına uyarlanmıştır.
-- =============================================================
create function public.create_service(
  p_operation_id uuid,
  p_idempotency_key text,
  p_business_id uuid,
  p_service jsonb,
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
  v_service_id          uuid;
  v_inserted_service_id uuid;
  v_name                text;
  v_price_per_minute_minor bigint;
  v_rounding_interval   integer;
  v_minimum_charge      integer;
  v_currency_code       text;
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
    if p_service is null
       or pg_catalog.jsonb_typeof(p_service) <> 'object'
       or nullif(p_service->>'id', '') is null then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_SERVICE_ID'
      );
    end if;
    v_service_id := (p_service->>'id')::uuid;
  exception
    when invalid_text_representation then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_SERVICE_ID'
      );
  end;

  if pg_catalog.jsonb_typeof(p_service->'name') is distinct from 'string'
     or pg_catalog.jsonb_typeof(p_service->'price_per_minute_minor') is distinct from 'number'
     or pg_catalog.jsonb_typeof(p_service->'rounding_interval_minutes') is distinct from 'number'
     or pg_catalog.jsonb_typeof(p_service->'minimum_charge_minutes') is distinct from 'number'
     or pg_catalog.jsonb_typeof(p_service->'currency_code') is distinct from 'string' then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_SERVICE_PAYLOAD'
    );
  end if;

  v_name := pg_catalog.btrim(p_service->>'name');
  v_price_per_minute_minor := (p_service->>'price_per_minute_minor')::bigint;
  v_rounding_interval := (p_service->>'rounding_interval_minutes')::integer;
  v_minimum_charge := (p_service->>'minimum_charge_minutes')::integer;
  v_currency_code := pg_catalog.upper(pg_catalog.btrim(p_service->>'currency_code'));

  if v_name is null
     or pg_catalog.char_length(v_name) not between 1 and 120
     or v_price_per_minute_minor < 0
     or v_rounding_interval <= 0
     or v_minimum_charge < 0
     or v_currency_code !~ '^[A-Z]{3}$' then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_SERVICE_PAYLOAD'
    );
  end if;

  if not public.has_business_role(
       p_business_id, array['owner','admin']::public.member_role[]
     ) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'SERVICE_CREATE_FORBIDDEN'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'service_id', v_service_id,
      'name', v_name,
      'price_per_minute_minor', v_price_per_minute_minor,
      'rounding_interval_minutes', v_rounding_interval,
      'minimum_charge_minutes', v_minimum_charge,
      'currency_code', v_currency_code
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

  insert into public.services (
    id,
    business_id,
    name,
    price_per_minute_minor,
    rounding_interval_minutes,
    minimum_charge_minutes,
    currency_code
  )
  values (
    v_service_id,
    p_business_id,
    v_name,
    v_price_per_minute_minor,
    v_rounding_interval,
    v_minimum_charge,
    v_currency_code
  )
  on conflict (id) do nothing
  returning id, server_version, created_at, updated_at
    into v_inserted_service_id, v_server_version, v_created_at, v_updated_at;

  if v_inserted_service_id is null then
    insert into public.security_events (
      event_type,
      business_id,
      user_id,
      detail
    )
    values (
      'service_id_conflict',
      p_business_id,
      v_user_id,
      pg_catalog.jsonb_build_object('operation_id', p_operation_id)
    );

    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'SERVICE_ID_CONFLICT'
    );
  end if;

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'service_id', v_inserted_service_id,
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
    'create_service',
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

revoke execute on function public.create_service(uuid, text, uuid, jsonb, integer)
  from public, anon;
grant execute on function public.create_service(uuid, text, uuid, jsonb, integer)
  to authenticated;

-- =============================================================
-- ---------- Offline hizmet güncelleme RPC'si (kısıtlı alan) ----------
-- Yalnızca name, price_per_minute_minor, rounding_interval_minutes,
-- minimum_charge_minutes değişir; is_active/archived_at/currency_code/
-- business_id GÖNDERİLMEZ (services_repository_impl.updateService ile
-- tutarlı — bkz. o dosyadaki yorum).
-- =============================================================
create function public.update_service(
  p_operation_id uuid,
  p_idempotency_key text,
  p_business_id uuid,
  p_service jsonb,
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
  v_service_id          uuid;
  v_updated_service_id  uuid;
  v_name                text;
  v_price_per_minute_minor bigint;
  v_rounding_interval   integer;
  v_minimum_charge      integer;
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
    if p_service is null
       or pg_catalog.jsonb_typeof(p_service) <> 'object'
       or nullif(p_service->>'id', '') is null then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_SERVICE_ID'
      );
    end if;
    v_service_id := (p_service->>'id')::uuid;
  exception
    when invalid_text_representation then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_SERVICE_ID'
      );
  end;

  if pg_catalog.jsonb_typeof(p_service->'name') is distinct from 'string'
     or pg_catalog.jsonb_typeof(p_service->'price_per_minute_minor') is distinct from 'number'
     or pg_catalog.jsonb_typeof(p_service->'rounding_interval_minutes') is distinct from 'number'
     or pg_catalog.jsonb_typeof(p_service->'minimum_charge_minutes') is distinct from 'number' then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_SERVICE_PAYLOAD'
    );
  end if;

  v_name := pg_catalog.btrim(p_service->>'name');
  v_price_per_minute_minor := (p_service->>'price_per_minute_minor')::bigint;
  v_rounding_interval := (p_service->>'rounding_interval_minutes')::integer;
  v_minimum_charge := (p_service->>'minimum_charge_minutes')::integer;

  if v_name is null
     or pg_catalog.char_length(v_name) not between 1 and 120
     or v_price_per_minute_minor < 0
     or v_rounding_interval <= 0
     or v_minimum_charge < 0 then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_SERVICE_PAYLOAD'
    );
  end if;

  if not public.has_business_role(
       p_business_id, array['owner','admin']::public.member_role[]
     ) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'SERVICE_UPDATE_FORBIDDEN'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'service_id', v_service_id,
      'expected_version', p_expected_version,
      'name', v_name,
      'price_per_minute_minor', v_price_per_minute_minor,
      'rounding_interval_minutes', v_rounding_interval,
      'minimum_charge_minutes', v_minimum_charge
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

  update public.services
     set name = v_name,
         price_per_minute_minor = v_price_per_minute_minor,
         rounding_interval_minutes = v_rounding_interval,
         minimum_charge_minutes = v_minimum_charge
   where id = v_service_id
     and business_id = p_business_id
     and server_version = p_expected_version
     and is_deleted = false
  returning id, server_version, created_at, updated_at
    into v_updated_service_id, v_server_version, v_created_at, v_updated_at;

  if v_updated_service_id is null then
    if not exists (
      select 1 from public.services
      where id = v_service_id and business_id = p_business_id and is_deleted = false
    ) then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'SERVICE_NOT_FOUND'
      );
    end if;

    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'STALE_VERSION'
    );
  end if;

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'service_id', v_updated_service_id,
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
    'update_service',
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

revoke execute on function public.update_service(uuid, text, uuid, jsonb, integer, integer)
  from public, anon;
grant execute on function public.update_service(uuid, text, uuid, jsonb, integer, integer)
  to authenticated;

-- =============================================================
-- ---------- Offline hizmet aktif/pasif RPC'si (kısmi alan) ----------
-- =============================================================
create function public.set_service_active(
  p_operation_id uuid,
  p_idempotency_key text,
  p_business_id uuid,
  p_service_id uuid,
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
  v_user_id            uuid := auth.uid();
  v_existing           public.sync_processed_operations%rowtype;
  v_result             jsonb;
  v_normalized_payload jsonb;
  v_server_payload_hash text;
  v_updated_service_id uuid;
  v_server_version     integer;
  v_created_at         timestamptz;
  v_updated_at         timestamptz;
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
     or p_service_id is null
     or p_is_active is null
     or p_idempotency_key is null
     or pg_catalog.char_length(p_idempotency_key) > 200
     or p_expected_version is null then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_IDEMPOTENCY_KEY'
    );
  end if;

  if not public.has_business_role(
       p_business_id, array['owner','admin']::public.member_role[]
     ) then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'SERVICE_UPDATE_FORBIDDEN'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'service_id', p_service_id,
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

  update public.services
     set is_active = p_is_active,
         archived_at = case when p_is_active then null else pg_catalog.now() end
   where id = p_service_id
     and business_id = p_business_id
     and server_version = p_expected_version
     and is_deleted = false
  returning id, server_version, created_at, updated_at
    into v_updated_service_id, v_server_version, v_created_at, v_updated_at;

  if v_updated_service_id is null then
    if not exists (
      select 1 from public.services
      where id = p_service_id and business_id = p_business_id and is_deleted = false
    ) then
      return pg_catalog.jsonb_build_object(
        'result', 'conflict',
        'error_code', 'SERVICE_NOT_FOUND'
      );
    end if;

    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'STALE_VERSION'
    );
  end if;

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'service_id', v_updated_service_id,
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
    'set_service_active',
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

revoke execute on function public.set_service_active(uuid, text, uuid, uuid, boolean, integer, integer)
  from public, anon;
grant execute on function public.set_service_active(uuid, text, uuid, uuid, boolean, integer, integer)
  to authenticated;
