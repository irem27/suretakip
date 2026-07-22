-- =============================================================
-- SureTakip - Offline session start/event RPC test paketi
-- Calistirma: docker exec -i supabase_db_suretakip psql -U postgres -d postgres -q < supabase/tests/offline_session_test.sql
-- Tek transaction'da kosar, sonunda ROLLBACK ile DB'yi temiz birakir.
-- =============================================================
\set ON_ERROR_STOP on
begin;

insert into auth.users (instance_id, id, aud, role, email)
values
  ('00000000-0000-0000-0000-000000000000','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','authenticated','authenticated','session-owner@test.local'),
  ('00000000-0000-0000-0000-000000000000','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2','authenticated','authenticated','session-outsider@test.local');

-- PUBLIC grant'lerini gercek bir login/uyelik grant'i olmayan rol uzerinden
-- has_*_privilege ile olcmek icin transaction-local probe rolu.
create role session_public_probe nologin;

-- ========== U1 (owner, B1) ==========
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1","role":"authenticated"}', true);

select public.complete_onboarding(
  'Offline Session Testi', 'TRY', 'Europe/Istanbul',
  'Test Hizmeti', 125, 5, 10
) as session_business \gset
select set_config('test.session_business', :'session_business', true);

select id as session_service
from public.services
where business_id = :'session_business'::uuid
limit 1 \gset
select set_config('test.session_service', :'session_service', true);

-- ---------- 01: offline start istemci kimlikleri ve zamaniyla uygulanir ----------
do $$
declare
  v_result jsonb;
  v_session_count integer;
  v_entry_count integer;
  v_snapshot_ok boolean;
begin
  v_result := public.sync_start_session(
    '22000000-0000-4000-8000-000000000001',
    'sync-test:start-session:0001',
    current_setting('test.session_business')::uuid,
    pg_catalog.jsonb_build_object(
      'session_id', '11000000-0000-4000-8000-000000000001',
      'service_id', current_setting('test.session_service')::uuid,
      'customer_id', null,
      'started_at', '2026-07-22T08:00:00.123456Z',
      'first_entry_id', '33000000-0000-4000-8000-000000000001',
      'notes', 'Offline baslatildi',
      'started_offline', true
    ),
    1
  );

  select count(*),
         pg_catalog.bool_and(
           status = 'active'
           and started_at = '2026-07-22T08:00:00.123456Z'::timestamptz
           and service_name_snapshot = 'Test Hizmeti'
           and price_per_minute_minor_snapshot = 125
           and rounding_interval_minutes_snapshot = 5
           and minimum_charge_minutes_snapshot = 10
           and currency_code_snapshot = 'TRY'
         )
    into v_session_count, v_snapshot_ok
  from public.sessions
  where id = '11000000-0000-4000-8000-000000000001';

  select count(*) into v_entry_count
  from public.session_time_entries
  where id = '33000000-0000-4000-8000-000000000001'
    and business_id = current_setting('test.session_business')::uuid
    and session_id = '11000000-0000-4000-8000-000000000001'
    and entry_type = 'active'
    and started_at = '2026-07-22T08:00:00.123456Z'::timestamptz
    and ended_at is null;

  if v_result->>'result' = 'applied'
     and v_result->>'session_id' = '11000000-0000-4000-8000-000000000001'
     and (v_result->>'started_at')::timestamptz = '2026-07-22T08:00:00.123456Z'::timestamptz
     and v_result->>'status' = 'active'
     and v_result->>'created_at_server' is not null
     and v_session_count = 1
     and v_snapshot_ok
     and v_entry_count = 1 then
    raise notice 'PASS 01: offline start istemci id/zamaniyla uygulandi, snapshot serverdan alindi';
  else
    raise exception 'FAIL 01: sonuc=%, seans=%, entry=%, snapshot=%',
      v_result, v_session_count, v_entry_count, v_snapshot_ok;
  end if;
end $$;

-- ---------- 02: ayni start operasyonu uc kez tek seans uretir ----------
do $$
declare
  v_first jsonb;
  v_second jsonb;
  v_third jsonb;
  v_session_count integer;
  v_entry_count integer;
begin
  v_first := public.sync_start_session(
    '22000000-0000-4000-8000-000000000002',
    'sync-test:start-session:0002',
    current_setting('test.session_business')::uuid,
    pg_catalog.jsonb_build_object(
      'session_id', '11000000-0000-4000-8000-000000000002',
      'service_id', current_setting('test.session_service')::uuid,
      'started_at', '2026-07-22T09:00:00Z',
      'first_entry_id', '33000000-0000-4000-8000-000000000002',
      'notes', null,
      'started_offline', true
    ),
    1
  );
  v_second := public.sync_start_session(
    '22000000-0000-4000-8000-000000000002',
    'sync-test:start-session:0002',
    current_setting('test.session_business')::uuid,
    pg_catalog.jsonb_build_object(
      'session_id', '11000000-0000-4000-8000-000000000002',
      'service_id', current_setting('test.session_service')::uuid,
      'started_at', '2026-07-22T09:00:00Z',
      'first_entry_id', '33000000-0000-4000-8000-000000000002',
      'notes', null,
      'started_offline', true
    ),
    1
  );
  v_third := public.sync_start_session(
    '22000000-0000-4000-8000-000000000002',
    'sync-test:start-session:0002',
    current_setting('test.session_business')::uuid,
    pg_catalog.jsonb_build_object(
      'session_id', '11000000-0000-4000-8000-000000000002',
      'service_id', current_setting('test.session_service')::uuid,
      'started_at', '2026-07-22T09:00:00Z',
      'first_entry_id', '33000000-0000-4000-8000-000000000002',
      'notes', null,
      'started_offline', true
    ),
    1
  );

  select count(*) into v_session_count
  from public.sessions
  where id = '11000000-0000-4000-8000-000000000002';

  select count(*) into v_entry_count
  from public.session_time_entries
  where session_id = '11000000-0000-4000-8000-000000000002';

  if v_first->>'result' = 'applied'
     and v_second->>'result' = 'already_processed'
     and v_third->>'result' = 'already_processed'
     and v_session_count = 1
     and v_entry_count = 1 then
    raise notice 'PASS 02: ayni start uc kez gonderildi, tek seans ve tek entry olustu';
  else
    raise exception 'FAIL 02: ilk=%, ikinci=%, ucuncu=%, seans=%, entry=%',
      v_first, v_second, v_third, v_session_count, v_entry_count;
  end if;
end $$;

-- ---------- 03: pause acik active entry'yi kapatir, paused entry acar ----------
do $$
declare
  v_result jsonb;
  v_status public.session_status;
  v_closed_count integer;
  v_paused_count integer;
begin
  v_result := public.sync_session_event(
    '22000000-0000-4000-8000-000000000003',
    'sync-test:session-event:0003',
    current_setting('test.session_business')::uuid,
    pg_catalog.jsonb_build_object(
      'session_id', '11000000-0000-4000-8000-000000000001',
      'event_type', 'pause',
      'event_id', '33000000-0000-4000-8000-000000000003',
      'occurred_at', '2026-07-22T08:30:00.654321Z'
    ),
    1
  );

  select status into v_status
  from public.sessions
  where id = '11000000-0000-4000-8000-000000000001';

  select count(*) into v_closed_count
  from public.session_time_entries
  where id = '33000000-0000-4000-8000-000000000001'
    and ended_at = '2026-07-22T08:30:00.654321Z'::timestamptz;

  select count(*) into v_paused_count
  from public.session_time_entries
  where id = '33000000-0000-4000-8000-000000000003'
    and session_id = '11000000-0000-4000-8000-000000000001'
    and entry_type = 'paused'
    and started_at = '2026-07-22T08:30:00.654321Z'::timestamptz
    and ended_at is null;

  if v_result->>'result' = 'applied'
     and v_result->>'event_type' = 'pause'
     and v_result->>'status' = 'paused'
     and v_status = 'paused'
     and v_closed_count = 1
     and v_paused_count = 1 then
    raise notice 'PASS 03: pause istemci zamaniyla active entry kapatti ve paused entry acti';
  else
    raise exception 'FAIL 03: sonuc=%, status=%, kapanan=%, paused=%',
      v_result, v_status, v_closed_count, v_paused_count;
  end if;
end $$;

-- ---------- 04: ayni pause replay ikinci paused entry uretmez ----------
do $$
declare
  v_result jsonb;
  v_paused_count integer;
  v_total_count integer;
begin
  v_result := public.sync_session_event(
    '22000000-0000-4000-8000-000000000003',
    'sync-test:session-event:0003',
    current_setting('test.session_business')::uuid,
    pg_catalog.jsonb_build_object(
      'session_id', '11000000-0000-4000-8000-000000000001',
      'event_type', 'pause',
      'event_id', '33000000-0000-4000-8000-000000000003',
      'occurred_at', '2026-07-22T08:30:00.654321Z'
    ),
    1
  );

  select count(*) into v_paused_count
  from public.session_time_entries
  where session_id = '11000000-0000-4000-8000-000000000001'
    and entry_type = 'paused';

  select count(*) into v_total_count
  from public.session_time_entries
  where session_id = '11000000-0000-4000-8000-000000000001';

  if v_result->>'result' = 'already_processed'
     and v_result->>'event_type' = 'pause'
     and v_result->>'status' = 'paused'
     and v_paused_count = 1
     and v_total_count = 2 then
    raise notice 'PASS 04: ayni pause replay edildi, ikinci paused entry olusmadi';
  else
    raise exception 'FAIL 04: sonuc=%, paused=%, toplam=%',
      v_result, v_paused_count, v_total_count;
  end if;
end $$;

-- ---------- 05: resume paused entry'yi kapatir, active entry acar ----------
do $$
declare
  v_result jsonb;
  v_status public.session_status;
  v_closed_count integer;
  v_active_count integer;
begin
  v_result := public.sync_session_event(
    '22000000-0000-4000-8000-000000000004',
    'sync-test:session-event:0004',
    current_setting('test.session_business')::uuid,
    pg_catalog.jsonb_build_object(
      'session_id', '11000000-0000-4000-8000-000000000001',
      'event_type', 'resume',
      'event_id', '33000000-0000-4000-8000-000000000004',
      'occurred_at', '2026-07-22T08:45:00.987654Z'
    ),
    1
  );

  select status into v_status
  from public.sessions
  where id = '11000000-0000-4000-8000-000000000001';

  select count(*) into v_closed_count
  from public.session_time_entries
  where id = '33000000-0000-4000-8000-000000000003'
    and ended_at = '2026-07-22T08:45:00.987654Z'::timestamptz;

  select count(*) into v_active_count
  from public.session_time_entries
  where id = '33000000-0000-4000-8000-000000000004'
    and entry_type = 'active'
    and started_at = '2026-07-22T08:45:00.987654Z'::timestamptz
    and ended_at is null;

  if v_result->>'result' = 'applied'
     and v_result->>'event_type' = 'resume'
     and v_result->>'status' = 'active'
     and v_status = 'active'
     and v_closed_count = 1
     and v_active_count = 1 then
    raise notice 'PASS 05: resume istemci zamaniyla paused entry kapatti ve active entry acti';
  else
    raise exception 'FAIL 05: sonuc=%, status=%, kapanan=%, active=%',
      v_result, v_status, v_closed_count, v_active_count;
  end if;
end $$;

-- ---------- 06: active seansta farkli resume op state conflict olur ----------
do $$
declare
  v_result jsonb;
  v_status public.session_status;
  v_total_count integer;
  v_open_active_count integer;
  v_invalid_entry_count integer;
begin
  v_result := public.sync_session_event(
    '22000000-0000-4000-8000-000000000005',
    'sync-test:session-event:0005',
    current_setting('test.session_business')::uuid,
    pg_catalog.jsonb_build_object(
      'session_id', '11000000-0000-4000-8000-000000000001',
      'event_type', 'resume',
      'event_id', '33000000-0000-4000-8000-000000000005',
      'occurred_at', '2026-07-22T09:00:00Z'
    ),
    1
  );

  select status into v_status
  from public.sessions
  where id = '11000000-0000-4000-8000-000000000001';

  select count(*),
         count(*) filter (where entry_type = 'active' and ended_at is null),
         count(*) filter (where id = '33000000-0000-4000-8000-000000000005')
    into v_total_count, v_open_active_count, v_invalid_entry_count
  from public.session_time_entries
  where session_id = '11000000-0000-4000-8000-000000000001';

  if v_result->>'result' = 'conflict'
     and v_result->>'error_code' = 'INVALID_SESSION_STATE'
     and v_status = 'active'
     and v_total_count = 3
     and v_open_active_count = 1
     and v_invalid_entry_count = 0 then
    raise notice 'PASS 06: active seansta resume conflict oldu, ledger degismedi';
  else
    raise exception 'FAIL 06: sonuc=%, status=%, toplam=%, acik_active=%, gecersiz=%',
      v_result, v_status, v_total_count, v_open_active_count, v_invalid_entry_count;
  end if;
end $$;

-- ---------- 07: uye olmayan cagiran offline seans baslatamaz ----------
select set_config('request.jwt.claims','{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2","role":"authenticated"}', true);

select set_config(
  'test.session_forbidden_result',
  public.sync_start_session(
    '22000000-0000-4000-8000-000000000006',
    'sync-test:start-session:0006',
    current_setting('test.session_business')::uuid,
    pg_catalog.jsonb_build_object(
      'session_id', '11000000-0000-4000-8000-000000000003',
      'service_id', current_setting('test.session_service')::uuid,
      'started_at', '2026-07-22T10:00:00Z',
      'first_entry_id', '33000000-0000-4000-8000-000000000006',
      'notes', null,
      'started_offline', true
    ),
    1
  )::text,
  true
);

reset role;

do $$
declare
  v_result jsonb := current_setting('test.session_forbidden_result')::jsonb;
  v_count integer;
begin
  select count(*) into v_count
  from public.sessions
  where id = '11000000-0000-4000-8000-000000000003';

  if v_result->>'result' = 'rejected'
     and v_result->>'error_code' = 'SESSION_START_FORBIDDEN'
     and v_count = 0 then
    raise notice 'PASS 07: uye olmayan cagiran reddedildi ve seans olusmadi';
  else
    raise exception 'FAIL 07: sonuc=%, fiziksel satir=%', v_result, v_count;
  end if;
end $$;

-- ---------- 08: offline seans RPC execute grant matrisi ----------
do $$ begin
  if has_function_privilege(
       'authenticated',
       'public.sync_start_session(uuid,text,uuid,jsonb,integer)',
       'EXECUTE'
     )
     and has_function_privilege(
       'authenticated',
       'public.sync_session_event(uuid,text,uuid,jsonb,integer)',
       'EXECUTE'
     )
     and not has_function_privilege(
       'anon',
       'public.sync_start_session(uuid,text,uuid,jsonb,integer)',
       'EXECUTE'
     )
     and not has_function_privilege(
       'anon',
       'public.sync_session_event(uuid,text,uuid,jsonb,integer)',
       'EXECUTE'
     )
     and not has_function_privilege(
       'session_public_probe',
       'public.sync_start_session(uuid,text,uuid,jsonb,integer)',
       'EXECUTE'
     )
     and not has_function_privilege(
       'session_public_probe',
       'public.sync_session_event(uuid,text,uuid,jsonb,integer)',
       'EXECUTE'
     ) then
    raise notice 'PASS 08: offline seans RPC''leri yalniz authenticated role tarafindan execute edilebilir';
  else
    raise exception 'FAIL 08: offline seans RPC execute grant matrisi yanlis';
  end if;
end $$;

rollback;
\echo === 8/8 TEST TAMAMLANDI (rollback ile temiz birakildi) ===
