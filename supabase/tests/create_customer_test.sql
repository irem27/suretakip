-- =============================================================
-- SureTakip - Offline create_customer RPC test paketi
-- Calistirma: docker exec -i supabase_db_suretakip psql -U postgres -d postgres -q < supabase/tests/create_customer_test.sql
-- Tek transaction'da kosar, sonunda ROLLBACK ile DB'yi temiz birakir.
-- =============================================================
\set ON_ERROR_STOP on
begin;

insert into auth.users (instance_id, id, aud, role, email)
values
  ('00000000-0000-0000-0000-000000000000','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','authenticated','authenticated','sync-owner@test.local'),
  ('00000000-0000-0000-0000-000000000000','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2','authenticated','authenticated','sync-outsider@test.local');

-- PUBLIC grant'lerini gercek bir login/uyelik grant'i olmayan rol uzerinden
-- has_*_privilege ile olcmek icin transaction-local probe rolu.
create role sync_public_probe nologin;

-- ========== U1 (owner, B1) ==========
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1","role":"authenticated"}', true);

select public.complete_onboarding(
  'Offline Sync Testi', 'TRY', 'Europe/Istanbul',
  'Test Hizmeti', 100, 1, 0
) as sync_business \gset
select set_config('test.sync_business', :'sync_business', true);

-- ---------- 01: temel offline musteri olusturma ----------
do $$
declare
  v_result jsonb;
  v_count integer;
  v_version integer;
begin
  v_result := public.create_customer(
    '20000000-0000-4000-8000-000000000001',
    'sync-test:create-customer:0001',
    current_setting('test.sync_business')::uuid,
    jsonb_build_object(
      'id', '10000000-0000-4000-8000-000000000001',
      'name', '  Ayse Yilmaz  ',
      'phone', '  +90 555 000 00 01  ',
      'email', '  ayse@example.test  ',
      'notes', '  Ilk offline kayit  '
    ),
    1
  );

  select count(*), max(server_version)
    into v_count, v_version
  from public.customers
  where id = '10000000-0000-4000-8000-000000000001';

  if v_result->>'result' = 'applied'
     and v_result->>'customer_id' = '10000000-0000-4000-8000-000000000001'
     and (v_result->>'server_version')::integer = 1
     and v_result->>'created_at_server' is not null
     and v_result->>'updated_at_server' is not null
     and v_count = 1
     and v_version = 1 then
    raise notice 'PASS 01: offline musteri applied, tek satir ve server_version=1';
  else
    raise exception 'FAIL 01: sonuc=%, satir=%, version=%', v_result, v_count, v_version;
  end if;
end $$;

-- ---------- 02: uc gonderim tek domain satiri uretir ----------
do $$
declare
  v_first jsonb;
  v_second jsonb;
  v_third jsonb;
  v_count integer;
begin
  v_first := public.create_customer(
    '20000000-0000-4000-8000-000000000002',
    'sync-test:create-customer:0002',
    current_setting('test.sync_business')::uuid,
    jsonb_build_object(
      'id', '10000000-0000-4000-8000-000000000002',
      'name', 'Mehmet Kaya',
      'phone', null,
      'email', null,
      'notes', null
    ),
    1
  );
  v_second := public.create_customer(
    '20000000-0000-4000-8000-000000000002',
    'sync-test:create-customer:0002',
    current_setting('test.sync_business')::uuid,
    jsonb_build_object(
      'id', '10000000-0000-4000-8000-000000000002',
      'name', 'Mehmet Kaya',
      'phone', null,
      'email', null,
      'notes', null
    ),
    1
  );
  v_third := public.create_customer(
    '20000000-0000-4000-8000-000000000002',
    'sync-test:create-customer:0002',
    current_setting('test.sync_business')::uuid,
    jsonb_build_object(
      'id', '10000000-0000-4000-8000-000000000002',
      'name', 'Mehmet Kaya',
      'phone', null,
      'email', null,
      'notes', null
    ),
    1
  );

  select count(*) into v_count
  from public.customers
  where id = '10000000-0000-4000-8000-000000000002';

  if v_first->>'result' = 'applied'
     and v_second->>'result' = 'already_processed'
     and v_third->>'result' = 'already_processed'
     and v_count = 1 then
    raise notice 'PASS 02: ayni operasyon uc kez gonderildi, tek musteri olustu';
  else
    raise exception 'FAIL 02: ilk=%, ikinci=%, ucuncu=%, satir=%',
      v_first, v_second, v_third, v_count;
  end if;
end $$;

-- ---------- 03: ayni key + farkli normalize payload reddedilir ----------
do $$
declare
  v_first jsonb;
  v_mismatch jsonb;
  v_first_count integer;
  v_second_count integer;
begin
  v_first := public.create_customer(
    '20000000-0000-4000-8000-000000000003',
    'sync-test:create-customer:0003',
    current_setting('test.sync_business')::uuid,
    jsonb_build_object(
      'id', '10000000-0000-4000-8000-000000000003',
      'name', 'Payload Bir'
    ),
    1
  );
  v_mismatch := public.create_customer(
    '20000000-0000-4000-8000-000000000003',
    'sync-test:create-customer:0003',
    current_setting('test.sync_business')::uuid,
    jsonb_build_object(
      'id', '10000000-0000-4000-8000-000000000004',
      'name', 'Payload Iki'
    ),
    1
  );

  select count(*) into v_first_count
  from public.customers
  where id = '10000000-0000-4000-8000-000000000003';
  select count(*) into v_second_count
  from public.customers
  where id = '10000000-0000-4000-8000-000000000004';

  if v_first->>'result' = 'applied'
     and v_mismatch->>'result' = 'rejected'
     and v_mismatch->>'error_code' = 'IDEMPOTENCY_PAYLOAD_MISMATCH'
     and v_first_count = 1
     and v_second_count = 0 then
    raise notice 'PASS 03: ayni key farkli payload reddedildi, ikinci musteri olusmadi';
  else
    raise exception 'FAIL 03: ilk=%, mismatch=%, ilk satir=%, ikinci satir=%',
      v_first, v_mismatch, v_first_count, v_second_count;
  end if;
end $$;

-- ---------- 04: uye olmayan cagiran tenant'a yazamaz ----------
select set_config('request.jwt.claims','{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2","role":"authenticated"}', true);

select set_config(
  'test.customer_forbidden_result',
  public.create_customer(
    '20000000-0000-4000-8000-000000000004',
    'sync-test:create-customer:0004',
    current_setting('test.sync_business')::uuid,
    jsonb_build_object(
      'id', '10000000-0000-4000-8000-000000000005',
      'name', 'Yetkisiz Musteri'
    ),
    1
  )::text,
  true
);

reset role;

do $$
declare
  v_result jsonb := current_setting('test.customer_forbidden_result')::jsonb;
  v_count integer;
begin

  select count(*) into v_count
  from public.customers
  where id = '10000000-0000-4000-8000-000000000005';

  if v_result->>'result' = 'rejected'
     and v_result->>'error_code' = 'CUSTOMER_CREATE_FORBIDDEN'
     and v_count = 0 then
    raise notice 'PASS 04: uye olmayan cagiran reddedildi ve musteri olusmadi';
  else
    raise exception 'FAIL 04: sonuc=%, fiziksel satir=%', v_result, v_count;
  end if;
end $$;

-- ========== U1 (owner, B1) baglamina don ==========
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1","role":"authenticated"}', true);

-- ---------- 05: var olan global customer id opak conflict + audit ----------
select set_config(
  'test.customer_conflict_result',
  public.create_customer(
    '20000000-0000-4000-8000-000000000005',
    'sync-test:create-customer:0005',
    current_setting('test.sync_business')::uuid,
    jsonb_build_object(
      'id', '10000000-0000-4000-8000-000000000001',
      'name', 'ID Cakismasi'
    ),
    1
  )::text,
  true
);

reset role;

do $$
declare
  v_result jsonb := current_setting('test.customer_conflict_result')::jsonb;
  v_events integer;
begin
  select count(*) into v_events
  from public.security_events
  where event_type = 'customer_id_conflict'
    and business_id = current_setting('test.sync_business')::uuid
    and user_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
    and detail->>'operation_id' = '20000000-0000-4000-8000-000000000005';

  if v_result->>'result' = 'conflict'
     and v_result->>'error_code' = 'CUSTOMER_ID_CONFLICT'
     and v_events = 1 then
    raise notice 'PASS 05: var olan customer id opak conflict dondurdu ve security event yazdi';
  else
    raise exception 'FAIL 05: sonuc=%, event adedi=%', v_result, v_events;
  end if;
end $$;

-- ---------- 06: dogrudan UPDATE server_version'i tetikler ----------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1","role":"authenticated"}', true);

update public.customers
   set notes = 'Dashboard guncellemesi'
 where id = '10000000-0000-4000-8000-000000000001';

do $$
declare v_version integer;
begin
  select server_version into v_version
  from public.customers
  where id = '10000000-0000-4000-8000-000000000001';

  if v_version = 2 then
    raise notice 'PASS 06: dogrudan UPDATE server_version degerini 1 -> 2 artirdi';
  else
    raise exception 'FAIL 06: UPDATE sonrasi server_version=% (2 olmaliydi)', v_version;
  end if;
end $$;

-- ---------- 07: RPC execute grant matrisi ----------
reset role;

do $$ begin
  if has_function_privilege(
       'authenticated',
       'public.create_customer(uuid,text,uuid,jsonb,integer)',
       'EXECUTE'
     )
     and not has_function_privilege(
       'anon',
       'public.create_customer(uuid,text,uuid,jsonb,integer)',
       'EXECUTE'
     )
     and not has_function_privilege(
       'sync_public_probe',
       'public.create_customer(uuid,text,uuid,jsonb,integer)',
       'EXECUTE'
     ) then
    raise notice 'PASS 07: create_customer yalniz authenticated role tarafindan execute edilebilir';
  else
    raise exception 'FAIL 07: create_customer execute grant matrisi yanlis';
  end if;
end $$;

-- ---------- 08: ic tablolar authenticated/anon/PUBLIC rollerine kapali ----------
do $$
declare
  v_role text;
  v_table text;
  v_privilege text;
begin
  foreach v_role in array array['authenticated', 'anon', 'sync_public_probe'] loop
    foreach v_table in array array[
      'public.sync_processed_operations',
      'public.security_events'
    ] loop
      foreach v_privilege in array array[
        'SELECT', 'INSERT', 'UPDATE', 'DELETE',
        'TRUNCATE', 'REFERENCES', 'TRIGGER'
      ] loop
        if has_table_privilege(v_role, v_table, v_privilege) then
          raise exception 'FAIL 08: role % tablo % uzerinde % yetkisine sahip',
            v_role, v_table, v_privilege;
        end if;
      end loop;
    end loop;
  end loop;

  raise notice 'PASS 08: idempotency ve security event tablolari istemci rollerine tamamen kapali';
end $$;

rollback;
\echo === 8/8 TEST TAMAMLANDI (rollback ile temiz birakildi) ===
