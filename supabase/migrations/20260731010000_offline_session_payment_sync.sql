-- =============================================================
-- SüreTakip - Offline-first seans ödeme (tahsilat) senkronizasyonu
-- Sync Engine kitabı (sync_processed_operations) + advisory lock + payload
-- hash deseni: `sync_start_session`/`sync_session_event` ile BİREBİR aynı
-- (bkz. 20260722110000_offline_session_sync.sql).
--
-- ÇİFT-TAHSİLAT KORUMASI (iki bağımsız katman):
--   1) sync_processed_operations: operasyon (p_idempotency_key) tekrarını
--      "already_processed" olarak yutar; aynı sonucu tekrar döner.
--   2) public.payments: (business_id, idempotency_key) UNIQUE kısıtı. Kitap
--      bir şekilde atlansa bile (ör. iki cihaz aynı anda ilk kez gönderiyor)
--      DB seviyesinde ikinci satır oluşamaz; unique_violation yakalanıp aynı
--      kayıt döndürülür.
-- Bu ikinci katman ZATEN mevcuttu (20260719120000_payments.sql); burada
-- aynı p_idempotency_key hem kitap anahtarı hem de payments.idempotency_key
-- olarak kullanılır, böylece iki katman AYNI anahtarla korur.
-- =============================================================

create function public.sync_record_session_payment(
  p_operation_id     uuid,
  p_idempotency_key  text,
  p_business_id      uuid,
  p_payment          jsonb,
  p_payload_version  integer
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id             uuid := auth.uid();
  v_member_id           uuid;
  v_existing            public.sync_processed_operations%rowtype;
  v_session             public.sessions%rowtype;
  v_existing_payment    public.payments%rowtype;
  v_result              jsonb;
  v_normalized_payload  jsonb;
  v_server_payload_hash text;
  v_payment_id          uuid;
  v_session_id          uuid;
  v_payment_method      public.payment_method;
  v_amount_minor        bigint;
  v_external_reference  text;
  v_note                text;
  v_net                 bigint;
  v_remaining           bigint;
  v_inserted_payment_id uuid;
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
     or pg_catalog.char_length(p_idempotency_key) = 0
     or pg_catalog.char_length(p_idempotency_key) > 200 then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_IDEMPOTENCY_KEY'
    );
  end if;

  begin
    if p_payment is null
       or pg_catalog.jsonb_typeof(p_payment) <> 'object'
       or pg_catalog.jsonb_typeof(p_payment->'payment_id') is distinct from 'string'
       or pg_catalog.jsonb_typeof(p_payment->'session_id') is distinct from 'string'
       or pg_catalog.jsonb_typeof(p_payment->'payment_method') is distinct from 'string'
       or pg_catalog.jsonb_typeof(p_payment->'amount_minor') is distinct from 'number'
       or (p_payment ? 'external_reference'
           and pg_catalog.jsonb_typeof(p_payment->'external_reference') not in ('string', 'null'))
       or (p_payment ? 'note'
           and pg_catalog.jsonb_typeof(p_payment->'note') not in ('string', 'null')) then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_PAYMENT_PAYLOAD'
      );
    end if;

    v_payment_id := (p_payment->>'payment_id')::uuid;
    v_session_id := (p_payment->>'session_id')::uuid;
    v_payment_method := (p_payment->>'payment_method')::public.payment_method;
    v_amount_minor := (p_payment->>'amount_minor')::bigint;
    v_external_reference := p_payment->>'external_reference';
    v_note := p_payment->>'note';
  exception
    when invalid_text_representation
      or invalid_datetime_format
      or numeric_value_out_of_range then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'INVALID_PAYMENT_PAYLOAD'
      );
  end;

  if v_amount_minor is null or v_amount_minor <= 0 then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'INVALID_AMOUNT'
    );
  end if;

  v_normalized_payload := pg_catalog.jsonb_strip_nulls(
    pg_catalog.jsonb_build_object(
      'payload_version', p_payload_version,
      'business_id', p_business_id,
      'payment_id', v_payment_id,
      'session_id', v_session_id,
      'payment_method', v_payment_method,
      'amount_minor', v_amount_minor,
      'external_reference', v_external_reference,
      'note', v_note
    )
  );

  v_server_payload_hash := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(v_normalized_payload::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );

  -- Replay, zamana ve güncel domain durumuna bağlı doğrulamalardan önce
  -- çözülür (Bölüm 10/11 ile aynı sıra; sync_session_event ile birebir).
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

  -- İkinci savunma katmanı: aynı anahtar payments'ta zaten varsa (ör. bu
  -- ödeme daha önce ONLINE `record_session_payment` ile de kaydedilmiş
  -- olabilir) yeni satır AÇILMAZ; mevcut kayıt "already_processed" olarak
  -- döner. Böylece online/offline yollar aynı anahtarı paylaşırken bile
  -- çift kayıt oluşamaz.
  select *
    into v_existing_payment
  from public.payments
  where business_id = p_business_id
    and idempotency_key = p_idempotency_key;

  if found then
    if not exists (
      select 1 from public.payment_allocations
      where payment_id = v_existing_payment.id
        and session_id = v_session_id
    ) then
      return pg_catalog.jsonb_build_object(
        'result', 'rejected',
        'error_code', 'PAYMENT_IDEMPOTENCY_KEY_REUSED'
      );
    end if;
    v_result := pg_catalog.jsonb_build_object(
      'result', 'already_processed',
      'payment_id', v_existing_payment.id,
      'session_id', v_session_id
    );
    insert into public.sync_processed_operations (
      idempotency_key, operation_id, business_id,
      original_actor_user_id, submitted_by_user_id,
      operation_type, payload_hash, result_json
    ) values (
      p_idempotency_key, p_operation_id, p_business_id,
      v_user_id, v_user_id,
      'sync_record_session_payment', v_server_payload_hash, v_result
    )
    on conflict (idempotency_key) do nothing;
    return v_result;
  end if;

  v_member_id := public.active_member_id(p_business_id);
  if v_member_id is null then
    return pg_catalog.jsonb_build_object(
      'result', 'rejected',
      'error_code', 'PAYMENT_FORBIDDEN'
    );
  end if;

  -- for update: aynı seansa eşzamanlı ödemeler SIRAYA girer (bakiye kontrolü
  -- bu kilit altında yapılır; record_session_payment ile aynı desen).
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

  if v_session.status <> 'completed' then
    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'SESSION_NOT_PAYABLE'
    );
  end if;

  select net_paid_minor into v_net
  from public.calc_session_payment_totals(v_session_id);

  v_remaining := pg_catalog.greatest(
    0, coalesce(v_session.grand_total_minor, 0) - v_net
  );
  if v_amount_minor > v_remaining then
    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'PAYMENT_EXCEEDS_BALANCE'
    );
  end if;

  insert into public.payments (
    id, business_id, customer_id, payment_kind, payment_method, status,
    amount_minor, currency_code, idempotency_key,
    external_reference, note, received_by_member_id
  ) values (
    v_payment_id, p_business_id, v_session.customer_id, 'collection',
    v_payment_method, 'completed',
    v_amount_minor, v_session.currency_code_snapshot, p_idempotency_key,
    v_external_reference, v_note, v_member_id
  )
  on conflict (id) do nothing
  returning id into v_inserted_payment_id;

  if v_inserted_payment_id is null then
    -- Cihazın mintlediği payment_id başka bir işlemde kullanılmış: veri
    -- kaybı riski taşımadan reddet (session_id çakışmasıyla aynı desen).
    insert into public.security_events (
      event_type, business_id, user_id, detail
    ) values (
      'payment_id_conflict', p_business_id, v_user_id,
      pg_catalog.jsonb_build_object('operation_id', p_operation_id)
    );
    return pg_catalog.jsonb_build_object(
      'result', 'conflict',
      'error_code', 'PAYMENT_ID_CONFLICT'
    );
  end if;

  insert into public.payment_allocations (
    business_id, payment_id, session_id, amount_minor
  ) values (
    p_business_id, v_inserted_payment_id, v_session_id, v_amount_minor
  );

  insert into public.payment_events (
    business_id, payment_id, event_type, actor_member_id, details
  ) values (
    p_business_id, v_inserted_payment_id, 'payment_recorded', v_member_id,
    pg_catalog.jsonb_build_object(
      'session_id', v_session_id,
      'amount_minor', v_amount_minor,
      'payment_method', v_payment_method,
      'remaining_before_minor', v_remaining,
      'offline', true
    )
  );

  v_result := pg_catalog.jsonb_build_object(
    'result', 'applied',
    'payment_id', v_inserted_payment_id,
    'session_id', v_session_id,
    'created_at_server', pg_catalog.now()
  );

  insert into public.sync_processed_operations (
    idempotency_key, operation_id, business_id,
    original_actor_user_id, submitted_by_user_id,
    operation_type, payload_hash, result_json
  ) values (
    p_idempotency_key, p_operation_id, p_business_id,
    v_user_id, v_user_id,
    'sync_record_session_payment', v_server_payload_hash, v_result
  );

  return v_result;
exception
  -- Aynı key ile TAM eşzamanlı iki istek: unique constraint tetiklenir.
  when unique_violation then
    select *
      into v_existing_payment
    from public.payments
    where business_id = p_business_id
      and idempotency_key = p_idempotency_key;
    if not found then
      raise;
    end if;
    return pg_catalog.jsonb_build_object(
      'result', 'already_processed',
      'payment_id', v_existing_payment.id,
      'session_id', v_session_id
    );
end;
$$;

revoke execute on function
  public.sync_record_session_payment(uuid, text, uuid, jsonb, integer)
from public, anon;

grant execute on function
  public.sync_record_session_payment(uuid, text, uuid, jsonb, integer)
to authenticated;
