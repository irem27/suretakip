-- =============================================================
-- SureTakip - Sprint 2 sync delta + customer snapshot test paketi
-- Calistirma: docker exec -i supabase_db_suretakip psql -U postgres -d postgres -q < supabase/tests/sync_delta_test.sql
-- Tek transaction'da kosar, sonunda ROLLBACK ile DB'yi temiz birakir.
-- =============================================================
\set ON_ERROR_STOP on
begin;

insert into auth.users (instance_id, id, aud, role, email)
values
  ('00000000-0000-0000-0000-000000000000','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaad1','authenticated','authenticated','delta-owner@test.local'),
  ('00000000-0000-0000-0000-000000000000','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbd2','authenticated','authenticated','delta-outsider@test.local');

-- PUBLIC grant'lerini gercek bir login/uyelik grant'i olmayan rol uzerinden
-- has_*_privilege ile olcmek icin transaction-local probe rolu.
create role sync_delta_public_probe nologin;

-- ========== U1 (owner, B1) ==========
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaad1","role":"authenticated"}', true);

select public.complete_onboarding(
  'Delta Sync Testi', 'TRY', 'Europe/Istanbul',
  'Test Hizmeti', 100, 1, 0
) as delta_business \gset
select set_config('test.delta_business', :'delta_business', true);

-- ---------- 01: create_customer feed'e version=1 upsert yazar ----------
select set_config(
  'test.delta_create_first',
  public.create_customer(
    '20000000-0000-4000-8000-00000000d001',
    'delta-test:create-customer:0001',
    current_setting('test.delta_business')::uuid,
    pg_catalog.jsonb_build_object(
      'id', '10000000-0000-4000-8000-00000000d001',
      'name', 'Ayse Delta',
      'phone', '+90 555 000 00 01',
      'email', 'ayse.delta@example.test',
      'notes', 'Ilk delta kaydi'
    ),
    1
  )::text,
  true
);

reset role;

do $$
declare
  v_result jsonb := current_setting('test.delta_create_first')::jsonb;
  v_change public.sync_changes%rowtype;
begin
  select *
    into v_change
  from public.sync_changes
  where business_id = current_setting('test.delta_business')::uuid
    and entity_type = 'customer'
    and entity_id = '10000000-0000-4000-8000-00000000d001'
  order by change_seq desc
  limit 1;

  if v_result->>'result' = 'applied'
     and v_change.operation = 'upsert'
     and v_change.server_version = 1
     and v_change.payload->>'name' = 'Ayse Delta'
     and v_change.payload->>'business_id' = current_setting('test.delta_business')
     and (v_change.payload->>'is_deleted')::boolean is false then
    raise notice 'PASS 01: create_customer feed''e upsert, version=1 ve dogru payload yazdi';
  else
    raise exception 'FAIL 01: RPC=%, change=%', v_result, row_to_json(v_change);
  end if;
end $$;

-- ---------- 02: dogrudan UPDATE feed'de artmis version=2'yi gorur ----------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaad1","role":"authenticated"}', true);

update public.customers
   set notes = 'Dashboard guncellemesi'
 where id = '10000000-0000-4000-8000-00000000d001';

reset role;

do $$
declare
  v_customer_version integer;
  v_change public.sync_changes%rowtype;
  v_change_count integer;
begin
  select server_version
    into v_customer_version
  from public.customers
  where id = '10000000-0000-4000-8000-00000000d001';

  select *
    into v_change
  from public.sync_changes
  where business_id = current_setting('test.delta_business')::uuid
    and entity_id = '10000000-0000-4000-8000-00000000d001'
  order by change_seq desc
  limit 1;

  select count(*)
    into v_change_count
  from public.sync_changes
  where business_id = current_setting('test.delta_business')::uuid
    and entity_id = '10000000-0000-4000-8000-00000000d001';

  if v_customer_version = 2
     and v_change_count = 2
     and v_change.operation = 'upsert'
     and v_change.server_version = 2
     and (v_change.payload->>'server_version')::integer = 2
     and v_change.payload->>'notes' = 'Dashboard guncellemesi' then
    raise notice 'PASS 02: AFTER feed trigger''i BEFORE version trigger''inin version=2 sonucunu gordu';
  else
    raise exception 'FAIL 02: customer version=%, change count=%, change=%',
      v_customer_version, v_change_count, row_to_json(v_change);
  end if;
end $$;

-- ---------- 03: get_changes cursor ilerletir, tekrarinda bos doner ----------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaad1","role":"authenticated"}', true);

select set_config(
  'test.delta_first_page',
  public.get_changes(current_setting('test.delta_business')::uuid, 0, 500)::text,
  true
);
select set_config(
  'test.delta_next_cursor',
  current_setting('test.delta_first_page')::jsonb->>'next_cursor',
  true
);
select set_config(
  'test.delta_empty_page',
  public.get_changes(
    current_setting('test.delta_business')::uuid,
    current_setting('test.delta_next_cursor')::bigint,
    500
  )::text,
  true
);

reset role;

do $$
declare
  v_first jsonb := current_setting('test.delta_first_page')::jsonb;
  v_empty jsonb := current_setting('test.delta_empty_page')::jsonb;
begin
  if v_first->>'result' = 'ok'
     and pg_catalog.jsonb_array_length(v_first->'changes') = 2
     and exists (
       select 1
       from pg_catalog.jsonb_array_elements(v_first->'changes') as change
       where change->>'entity_id' = '10000000-0000-4000-8000-00000000d001'
         and (change->>'server_version')::integer = 2
     )
     and (v_first->>'next_cursor')::bigint > 0
     and (v_first->>'has_more')::boolean is false
     and v_first->>'server_time' is not null
     and v_empty->>'result' = 'ok'
     and pg_catalog.jsonb_array_length(v_empty->'changes') = 0
     and (v_empty->>'next_cursor')::bigint = (v_first->>'next_cursor')::bigint
     and (v_empty->>'has_more')::boolean is false then
    raise notice 'PASS 03: get_changes cursor''u ilerletti ve ikinci cagri bos dondu';
  else
    raise exception 'FAIL 03: ilk=%, ikinci=%', v_first, v_empty;
  end if;
end $$;

-- ---------- 04: ikinci musteri snapshot sayfalamasini hazirlar ----------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaad1","role":"authenticated"}', true);

select set_config(
  'test.delta_create_second',
  public.create_customer(
    '20000000-0000-4000-8000-00000000d002',
    'delta-test:create-customer:0002',
    current_setting('test.delta_business')::uuid,
    pg_catalog.jsonb_build_object(
      'id', '10000000-0000-4000-8000-00000000d002',
      'name', 'Bora Delta'
    ),
    1
  )::text,
  true
);
select set_config(
  'test.snapshot_first_page',
  public.get_customers_snapshot(
    current_setting('test.delta_business')::uuid,
    null,
    1
  )::text,
  true
);
select set_config(
  'test.snapshot_second_page',
  public.get_customers_snapshot(
    current_setting('test.delta_business')::uuid,
    (current_setting('test.snapshot_first_page')::jsonb->>'next_after_id')::uuid,
    1
  )::text,
  true
);

reset role;

do $$
declare
  v_create jsonb := current_setting('test.delta_create_second')::jsonb;
  v_first jsonb := current_setting('test.snapshot_first_page')::jsonb;
  v_second jsonb := current_setting('test.snapshot_second_page')::jsonb;
begin
  if v_create->>'result' = 'applied'
     and v_first->>'result' = 'ok'
     and pg_catalog.jsonb_array_length(v_first->'customers') = 1
     and (v_first->>'has_more')::boolean is true
     and v_first->>'next_after_id' = '10000000-0000-4000-8000-00000000d001'
     and (v_first->>'server_cursor')::bigint >= 1
     and v_second->>'result' = 'ok'
     and pg_catalog.jsonb_array_length(v_second->'customers') = 1
     and v_second->'customers'->0->>'id' = '10000000-0000-4000-8000-00000000d002'
     and v_second->>'next_after_id' = '10000000-0000-4000-8000-00000000d002' then
    raise notice 'PASS 04: customer snapshot iki kaydi OFFSET kullanmadan iki sayfada dondurdu';
  else
    raise exception 'FAIL 04: create=%, ilk=%, ikinci=%', v_create, v_first, v_second;
  end if;
end $$;

-- ---------- 05: uye olmayan cagiran iki RPC'de de FORBIDDEN alir ----------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbd2","role":"authenticated"}', true);

select set_config(
  'test.delta_forbidden_changes',
  public.get_changes(current_setting('test.delta_business')::uuid, 0, 500)::text,
  true
);
select set_config(
  'test.delta_forbidden_snapshot',
  public.get_customers_snapshot(
    current_setting('test.delta_business')::uuid,
    null,
    500
  )::text,
  true
);

reset role;

do $$
declare
  v_changes jsonb := current_setting('test.delta_forbidden_changes')::jsonb;
  v_snapshot jsonb := current_setting('test.delta_forbidden_snapshot')::jsonb;
begin
  if v_changes->>'result' = 'rejected'
     and v_changes->>'error_code' = 'FORBIDDEN'
     and v_snapshot->>'result' = 'rejected'
     and v_snapshot->>'error_code' = 'FORBIDDEN' then
    raise notice 'PASS 05: uye olmayan cagiran iki RPC''de de FORBIDDEN aldi';
  else
    raise exception 'FAIL 05: changes=%, snapshot=%', v_changes, v_snapshot;
  end if;
end $$;

-- ---------- 06: retention boslugu CURSOR_TOO_OLD dondurur ----------
select set_config(
  'test.delta_old_cursor',
  (
    select min(change_seq)::text
    from public.sync_changes
    where business_id = current_setting('test.delta_business')::uuid
  ),
  true
);

delete from public.sync_changes
where change_seq in (
  select change_seq
  from public.sync_changes
  where business_id = current_setting('test.delta_business')::uuid
  order by change_seq
  limit 2
);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaad1","role":"authenticated"}', true);
select set_config(
  'test.delta_cursor_too_old',
  public.get_changes(
    current_setting('test.delta_business')::uuid,
    current_setting('test.delta_old_cursor')::bigint,
    500
  )::text,
  true
);

reset role;

do $$
declare
  v_result jsonb := current_setting('test.delta_cursor_too_old')::jsonb;
begin
  if v_result->>'result' = 'rejected'
     and v_result->>'error_code' = 'CURSOR_TOO_OLD' then
    raise notice 'PASS 06: temizlenmis horizon gerisindeki cursor CURSOR_TOO_OLD aldi';
  else
    raise exception 'FAIL 06: sonuc=%', v_result;
  end if;
end $$;

-- ---------- 07: RPC execute grant matrisi ----------
do $$ begin
  if has_function_privilege(
       'authenticated',
       'public.get_changes(uuid,bigint,integer)',
       'EXECUTE'
     )
     and has_function_privilege(
       'authenticated',
       'public.get_customers_snapshot(uuid,uuid,integer)',
       'EXECUTE'
     )
     and not has_function_privilege(
       'anon',
       'public.get_changes(uuid,bigint,integer)',
       'EXECUTE'
     )
     and not has_function_privilege(
       'anon',
       'public.get_customers_snapshot(uuid,uuid,integer)',
       'EXECUTE'
     )
     and not has_function_privilege(
       'sync_delta_public_probe',
       'public.get_changes(uuid,bigint,integer)',
       'EXECUTE'
     )
     and not has_function_privilege(
       'sync_delta_public_probe',
       'public.get_customers_snapshot(uuid,uuid,integer)',
       'EXECUTE'
     ) then
    raise notice 'PASS 07: delta RPC''leri yalniz authenticated role tarafindan execute edilebilir';
  else
    raise exception 'FAIL 07: delta RPC execute grant matrisi yanlis';
  end if;
end $$;

-- ---------- 08: sync_changes istemci rollerince okunamaz ----------
do $$
declare
  v_role text;
begin
  foreach v_role in array array[
    'authenticated',
    'anon',
    'sync_delta_public_probe'
  ] loop
    if has_table_privilege(v_role, 'public.sync_changes', 'SELECT') then
      raise exception 'FAIL 08: role % sync_changes tablosunu okuyabiliyor', v_role;
    end if;
  end loop;

  raise notice 'PASS 08: sync_changes authenticated, anon ve PUBLIC rollerine okunamaz';
end $$;

rollback;
\echo === 8/8 TEST TAMAMLANDI (rollback ile temiz birakildi) ===
