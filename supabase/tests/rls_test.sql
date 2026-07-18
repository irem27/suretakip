-- =============================================================
-- SüreTakip - RLS + RPC + iş kuralı test paketi
-- Calistirma: docker exec -i supabase_db_suretakip psql -U postgres -d postgres -q < supabase/tests/rls_test.sql
-- Tek transaction'da kosar, sonunda ROLLBACK ile DB'yi temiz birakir.
-- =============================================================
\set ON_ERROR_STOP on
begin;

insert into auth.users (instance_id, id, aud, role, email)
values
  ('00000000-0000-0000-0000-000000000000','11111111-1111-1111-1111-111111111111','authenticated','authenticated','owner@test.local'),
  ('00000000-0000-0000-0000-000000000000','22222222-2222-2222-2222-222222222222','authenticated','authenticated','rakip@test.local'),
  ('00000000-0000-0000-0000-000000000000','33333333-3333-3333-3333-333333333333','authenticated','authenticated','staff@test.local');

-- ========== U1 (owner, B1) ==========
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select public.create_business_with_owner('Test Berber') as b1 \gset
select set_config('test.b1', :'b1', true);

insert into public.services (business_id, name, price_per_minute_minor, rounding_interval_minutes, minimum_charge_minutes, currency_code)
values (:'b1', 'Koltuk', 250, 15, 10, 'TRY') returning id as s1 \gset
select set_config('test.s1', :'s1', true);

insert into public.products (business_id, name, sku, unit_price_minor, currency_code, track_stock)
values (:'b1', 'Kola', 'KOLA-1', 3000, 'TRY', true) returning id as p1 \gset
select set_config('test.p1', :'p1', true);

-- Stok, dogrudan kolona yazilarak degil ledger'la girilir; cache'i trigger doldurur.
insert into public.inventory_movements (business_id, product_id, movement_type, quantity_delta, note)
values (:'b1', :'p1', 'initial', 10, 'acilis sayimi');

do $$ begin
  if (select stock_quantity from public.products where id = current_setting('test.p1')::uuid) = 10 then
    raise notice 'PASS 01: initial movement stok cache''ini 10 yapti (trigger calisiyor)';
  else
    raise exception 'FAIL 01: stok cache guncellenmedi';
  end if;
end $$;

insert into public.customers (business_id, name) values (:'b1', 'Ali');

insert into public.business_members (business_id, user_id, role)
values (:'b1', '33333333-3333-3333-3333-333333333333', 'staff');

-- ========== U2 (yabanci isletme sahibi) ==========
select set_config('request.jwt.claims','{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select public.create_business_with_owner('Rakip Kuafor') as b2 \gset

do $$ begin
  if (select count(*) from public.businesses) = 1
     and (select count(*) from public.customers) = 0
     and (select count(*) from public.products) = 0 then
    raise notice 'PASS 02: tenant izolasyonu - u2 baska isletmenin verisini goremiyor';
  else
    raise exception 'FAIL 02: tenant izolasyonu delindi!';
  end if;
end $$;

do $$ begin
  perform public.start_session(current_setting('test.b1')::uuid, current_setting('test.s1')::uuid);
  raise exception 'FAIL 03: yabanci kullanici B1 adina seans acabildi!';
exception when raise_exception then
  if sqlerrm = 'not_a_member' then
    raise notice 'PASS 03: yabanci business_id ile seans acilamadi (not_a_member)';
  else raise; end if;
end $$;

-- ========== U3 (staff, B1) ==========
select set_config('request.jwt.claims','{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

do $$ begin
  insert into public.services (business_id, name, price_per_minute_minor, rounding_interval_minutes, currency_code)
  values (current_setting('test.b1')::uuid, 'Kacak', 100, 1, 'TRY');
  raise exception 'FAIL 04: staff hizmet ekleyebildi!';
exception when insufficient_privilege then
  raise notice 'PASS 04: staff katalog yonetemiyor (owner/admin isi)';
end $$;

insert into public.customers (business_id, name)
values (current_setting('test.b1')::uuid, 'Veli');
\echo PASS 05: staff musteri ekleyebildi

-- Misafir seans (customer_id NULL)
select public.start_session(current_setting('test.b1')::uuid, current_setting('test.s1')::uuid) as sess1 \gset
select set_config('test.sess1', :'sess1', true);
\echo PASS 06: misafir musteriyle seans acildi

select public.pause_session(current_setting('test.sess1')::uuid);

do $$ begin
  perform public.pause_session(current_setting('test.sess1')::uuid);
  raise exception 'FAIL 07: ayni seans iki kez pause edilebildi!';
exception when raise_exception then
  if sqlerrm = 'session_not_active' then
    raise notice 'PASS 07: cifte pause engellendi';
  else raise; end if;
end $$;

select public.resume_session(current_setting('test.sess1')::uuid);

do $$ begin
  perform public.add_product_to_session(current_setting('test.sess1')::uuid, current_setting('test.p1')::uuid, 20);
  raise exception 'FAIL 08: stok 10 iken 20 satilabildi!';
exception when raise_exception then
  if sqlerrm = 'insufficient_stock' then
    raise notice 'PASS 08: yetersiz stok satisi engellendi';
  else raise; end if;
end $$;

do $$ begin
  perform public.add_product_to_session(current_setting('test.sess1')::uuid, current_setting('test.p1')::uuid, -1);
  raise exception 'FAIL 09: negatif adet kabul edildi!';
exception when raise_exception then
  if sqlerrm = 'invalid_quantity' then
    raise notice 'PASS 09: negatif/sifir adet reddedildi';
  else raise; end if;
end $$;

select public.add_product_to_session(current_setting('test.sess1')::uuid, current_setting('test.p1')::uuid, 2) as item1 \gset
select set_config('test.item1', :'item1', true);

do $$ begin
  if (select stock_quantity from public.products where id = current_setting('test.p1')::uuid) = 8 then
    raise notice 'PASS 10: satis stogu 10 -> 8 dusurdu (ledger + cache tutarli)';
  else
    raise exception 'FAIL 10: stok dusumu yanlis';
  end if;
end $$;

-- Seans dogrudan UPDATE ile tamamlanamaz/toplami degistirilemez (kolon grant'i yok)
do $$ begin
  update public.sessions set grand_total_minor = 0
  where id = current_setting('test.sess1')::uuid;
  raise exception 'FAIL 11: staff toplami dogrudan degistirebildi!';
exception when insufficient_privilege then
  raise notice 'PASS 11: sessions finansal kolonlari dogrudan UPDATE''e kapali';
end $$;

-- Sureyi kontrollu kur: kapanmis araliklari 25 dk geriye cek (superuser isi)
reset role;
update public.session_time_entries
   set started_at = started_at - interval '25 minutes',
       ended_at   = ended_at   - interval '25 minutes'
 where session_id = current_setting('test.sess1')::uuid
   and entry_type = 'paused';
update public.session_time_entries
   set started_at = started_at - interval '25 minutes'
 where session_id = current_setting('test.sess1')::uuid
   and entry_type = 'active'
   and ended_at is not null;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

-- ~25 dk aktif sure, interval 15 -> 30 dk; 30*250=7500; urun 2*3000=6000; 500 indirim -> 13000
select public.complete_session(current_setting('test.sess1')::uuid, 500, 0);

do $$
declare v public.sessions%rowtype;
begin
  select * into v from public.sessions where id = current_setting('test.sess1')::uuid;
  if v.charged_minutes = 30
     and v.service_subtotal_minor = 7500
     and v.products_subtotal_minor = 6000
     and v.grand_total_minor = 13000
     and v.status = 'completed' then
    raise notice 'PASS 12: yuvarlama(15dk) + toplamlar dogru (30dk, 13000 minor)';
  else
    raise exception 'FAIL 12: hesap yanlis: dk=%, hizmet=%, urun=%, toplam=%',
      v.charged_minutes, v.service_subtotal_minor, v.products_subtotal_minor, v.grand_total_minor;
  end if;
end $$;

do $$ begin
  perform public.complete_session(current_setting('test.sess1')::uuid);
  raise exception 'FAIL 13: ayni seans iki kez tamamlanabildi!';
exception when raise_exception then
  if sqlerrm = 'session_not_open' then
    raise notice 'PASS 13: cifte tamamlama engellendi';
  else raise; end if;
end $$;

-- Snapshot bagimsizligi: fiyat/ad/para birimi degisir, gecmis degismez
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
update public.services  set price_per_minute_minor = 99999 where id = current_setting('test.s1')::uuid;
update public.products  set name = 'Fanta', unit_price_minor = 1 where id = current_setting('test.p1')::uuid;
update public.businesses set currency_code = 'USD' where id = current_setting('test.b1')::uuid;

do $$
declare v public.sessions%rowtype; i public.session_items%rowtype;
begin
  select * into v from public.sessions where id = current_setting('test.sess1')::uuid;
  select * into i from public.session_items where id = current_setting('test.item1')::uuid;
  if v.grand_total_minor = 13000
     and v.price_per_minute_minor_snapshot = 250
     and v.currency_code_snapshot = 'TRY'
     and i.product_name_snapshot = 'Kola'
     and i.unit_price_minor_snapshot = 3000 then
    raise notice 'PASS 14: fiyat/ad/para birimi degisti, gecmis seans SNAPSHOT sayesinde ayni';
  else
    raise exception 'FAIL 14: snapshot bagimsizligi bozuldu!';
  end if;
end $$;

-- Iptal yetkisi: staff tamamlanmis seansi iptal edemez, owner edebilir
select set_config('request.jwt.claims','{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
do $$ begin
  perform public.cancel_session(current_setting('test.sess1')::uuid);
  raise exception 'FAIL 15: staff tamamlanmis seansi iptal edebildi!';
exception when raise_exception then
  if sqlerrm = 'not_authorized' then
    raise notice 'PASS 15: tamamlanmis seans iptali staff''a kapali';
  else raise; end if;
end $$;

select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select public.cancel_session(current_setting('test.sess1')::uuid);

do $$ begin
  if (select stock_quantity from public.products where id = current_setting('test.p1')::uuid) = 10
     and (select count(*) from public.inventory_movements
          where session_item_id = current_setting('test.item1')::uuid
            and movement_type = 'sale_reversal') = 1 then
    raise notice 'PASS 16: iptalde stok iade edildi (8 -> 10), iade ledger''da tek kayit';
  else
    raise exception 'FAIL 16: stok iadesi yanlis';
  end if;
end $$;

do $$ begin
  perform public.cancel_session(current_setting('test.sess1')::uuid);
  raise exception 'FAIL 17: ayni seans iki kez iptal edilebildi!';
exception when raise_exception then
  if sqlerrm = 'session_already_cancelled' then
    raise notice 'PASS 17: cifte iptal (ve cifte stok iadesi) engellendi';
  else raise; end if;
end $$;

-- Arsivlenmis urun yeni seansa eklenemez
update public.products set is_active = false, archived_at = now()
where id = current_setting('test.p1')::uuid;

select public.start_session(current_setting('test.b1')::uuid, current_setting('test.s1')::uuid) as sess2 \gset
select set_config('test.sess2', :'sess2', true);

do $$ begin
  perform public.add_product_to_session(current_setting('test.sess2')::uuid, current_setting('test.p1')::uuid, 1);
  raise exception 'FAIL 18: arsivlenmis urun satilabildi!';
exception when raise_exception then
  if sqlerrm = 'product_not_available' then
    raise notice 'PASS 18: arsivlenmis urun yeni seansa eklenemedi';
  else raise; end if;
end $$;

-- Constraint testleri (superuser dahi bozamaz)
reset role;
do $$ begin
  insert into public.session_time_entries (business_id, session_id, entry_type, started_at, ended_at)
  values (current_setting('test.b1')::uuid, current_setting('test.sess2')::uuid,
          'active', now(), now() - interval '1 hour');
  raise exception 'FAIL 19: ended_at < started_at kabul edildi!';
exception when check_violation then
  raise notice 'PASS 19: ended_at < started_at check ile engellendi';
end $$;

do $$ begin
  insert into public.products (business_id, name, unit_price_minor, currency_code)
  values (current_setting('test.b1')::uuid, 'Bozuk', -5, 'TRY');
  raise exception 'FAIL 20: negatif fiyat kabul edildi!';
exception when check_violation then
  raise notice 'PASS 20: negatif fiyat check ile engellendi';
end $$;

-- ========== complete_onboarding: atomik onboarding ==========
select set_config('request.jwt.claims','{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

-- Atomiklik: hizmet fiyati negatif -> hicbir sey yazilmamali (isletme de yok)
do $$
declare v_before int; v_after int;
begin
  select count(*) into v_before from public.businesses;
  begin
    perform public.complete_onboarding(
      'Yarim Isletme', 'TRY', 'Europe/Istanbul',
      'Kotu Hizmet', -100, 15, 0, false, null, null
    );
    raise exception 'FAIL 21: negatif fiyatli onboarding gecti!';
  exception when check_violation then
    null; -- beklenen
  end;
  select count(*) into v_after from public.businesses;
  if v_before = v_after then
    raise notice 'PASS 21: onboarding atomik - hizmet basarisizsa isletme de olusmadi';
  else
    raise exception 'FAIL 21: yarim isletme kaldi (atomiklik bozuk)';
  end if;
end $$;

-- Happy path: isletme + hizmet + urun tek cagirida
select public.complete_onboarding(
  'Tam Isletme', 'TRY', 'Europe/Istanbul',
  'Masaj', 500, 10, 5, true, 'Cay', 1500
) as ob_biz \gset
select set_config('test.ob_biz', :'ob_biz', true);

do $$
declare v_biz uuid := current_setting('test.ob_biz')::uuid;
begin
  if (select count(*) from public.business_members where business_id = v_biz and role='owner') = 1
     and (select count(*) from public.services where business_id = v_biz) = 1
     and (select count(*) from public.products where business_id = v_biz) = 1 then
    raise notice 'PASS 22: onboarding isletme+owner+hizmet+urun tek transaction''da olusturdu';
  else
    raise exception 'FAIL 22: onboarding eksik kayit birakti';
  end if;
end $$;

-- ========== create_product_with_stock: ilk stok ledger uyumlu ==========
-- Owner (U1, B1) baglaminda calis.
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select public.create_product_with_stock(
  current_setting('test.b1')::uuid, 'Gofret', 'GOF-1', 2500, 'TRY', true, 24
) as prod \gset
select set_config('test.prod', :'prod', true);

do $$
declare v_prod uuid := current_setting('test.prod')::uuid;
begin
  if (select stock_quantity from public.products where id = v_prod) = 24
     and (select count(*) from public.inventory_movements
          where product_id = v_prod and movement_type = 'initial') = 1
     and (select quantity_delta from public.inventory_movements
          where product_id = v_prod and movement_type = 'initial') = 24 then
    raise notice 'PASS 23: ilk stok cache=24 ve ledger''da initial(+24) - tutarli';
  else
    raise exception 'FAIL 23: ilk stok cache/ledger ayristi';
  end if;
end $$;

-- Stok takibi kapaliysa ledger kaydi olusmamali, cache 0 kalmali
select public.create_product_with_stock(
  current_setting('test.b1')::uuid, 'Anahtarlik', null, 5000, 'TRY', false, 10
) as prod2 \gset
select set_config('test.prod2', :'prod2', true);

do $$
declare v_prod uuid := current_setting('test.prod2')::uuid;
begin
  if (select count(*) from public.inventory_movements where product_id = v_prod) = 0
     and (select stock_quantity from public.products where id = v_prod) = 0 then
    raise notice 'PASS 24: stok takibi kapali urunde ledger kaydi yok, cache 0';
  else
    raise exception 'FAIL 24: track_stock=false urunde beklenmedik stok/ledger';
  end if;
end $$;

-- ========== Rapor RPC'leri: server-side aggregate ==========
-- Bilinen tutarlarla 2 tamamlanmis seans fixture'i (superuser insert).
reset role;
select set_config('test.owner_member',
  (select id::text from public.business_members
   where business_id = current_setting('test.b1')::uuid and role = 'owner' limit 1), true);
select set_config('test.ali',
  (select id::text from public.customers
   where business_id = current_setting('test.b1')::uuid and name = 'Ali' limit 1), true);

insert into public.sessions (
  business_id, customer_id, service_id, opened_by_member_id, closed_by_member_id,
  status, started_at, ended_at, charged_minutes,
  service_name_snapshot, price_per_minute_minor_snapshot,
  rounding_interval_minutes_snapshot, minimum_charge_minutes_snapshot,
  currency_code_snapshot, service_subtotal_minor, products_subtotal_minor, grand_total_minor
) values (
  current_setting('test.b1')::uuid, current_setting('test.ali')::uuid,
  current_setting('test.s1')::uuid, current_setting('test.owner_member')::uuid,
  current_setting('test.owner_member')::uuid, 'completed',
  now() - interval '20 min', now() - interval '10 min', 30,
  'Koltuk', 250, 15, 10, 'TRY', 7500, 3000, 10500
) returning id as rsess1 \gset
select set_config('test.rsess1', :'rsess1', true);

insert into public.sessions (
  business_id, customer_id, service_id, opened_by_member_id, closed_by_member_id,
  status, started_at, ended_at, charged_minutes,
  service_name_snapshot, price_per_minute_minor_snapshot,
  rounding_interval_minutes_snapshot, minimum_charge_minutes_snapshot,
  currency_code_snapshot, service_subtotal_minor, products_subtotal_minor, grand_total_minor
) values (
  current_setting('test.b1')::uuid, null,
  current_setting('test.s1')::uuid, current_setting('test.owner_member')::uuid,
  current_setting('test.owner_member')::uuid, 'completed',
  now() - interval '8 min', now() - interval '5 min', 20,
  'Koltuk', 250, 15, 10, 'TRY', 5000, 0, 5000
);

insert into public.session_items (
  business_id, session_id, product_id, product_name_snapshot,
  unit_price_minor_snapshot, currency_code_snapshot, quantity, line_total_minor
) values (
  current_setting('test.b1')::uuid, current_setting('test.rsess1')::uuid,
  current_setting('test.p1')::uuid, 'Kola', 3000, 'TRY', 1, 3000
);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

do $$
declare r record;
begin
  select * into r from public.report_revenue_summary(current_setting('test.b1')::uuid)
   where period = 'day';
  if r.completed_count = 2 and r.grand_total_minor = 15500
     and r.service_total_minor = 12500 and r.products_total_minor = 3000 then
    raise notice 'PASS 25: gunluk gelir ozeti dogru (2 seans, 15500 minor; iptal/aktif haric)';
  else
    raise exception 'FAIL 25: gelir ozeti yanlis: count=%, grand=%, svc=%, prod=%',
      r.completed_count, r.grand_total_minor, r.service_total_minor, r.products_total_minor;
  end if;
end $$;

do $$
declare r record;
begin
  select * into r from public.report_top_services(current_setting('test.b1')::uuid, 'day', 5) limit 1;
  if r.service_name = 'Koltuk' and r.completed_count = 2 and r.service_revenue_minor = 12500 then
    raise notice 'PASS 26: en cok gelir getiren hizmet dogru (Koltuk x2, 12500)';
  else
    raise exception 'FAIL 26: top_services yanlis';
  end if;
end $$;

do $$
declare r record;
begin
  select * into r from public.report_top_products(current_setting('test.b1')::uuid, 'day', 5) limit 1;
  if r.product_name = 'Kola' and r.sold_quantity = 1 and r.product_revenue_minor = 3000 then
    raise notice 'PASS 27: en cok satilan urun dogru (Kola x1, 3000)';
  else
    raise exception 'FAIL 27: top_products yanlis';
  end if;
end $$;

do $$
declare r record; v_cnt int;
begin
  select count(*) into v_cnt from public.report_top_customers(current_setting('test.b1')::uuid, 'day', 5);
  select * into r from public.report_top_customers(current_setting('test.b1')::uuid, 'day', 5) limit 1;
  -- Misafir seans haric: yalnizca Ali gorunur, harcama 10500.
  if v_cnt = 1 and r.customer_name = 'Ali' and r.spending_minor = 10500 then
    raise notice 'PASS 28: en cok harcayan musteri dogru (Ali 10500, misafir haric)';
  else
    raise exception 'FAIL 28: top_customers yanlis: adet=%, ad=%, harcama=%',
      v_cnt, r.customer_name, r.spending_minor;
  end if;
end $$;

rollback;
\echo === 28/28 TEST TAMAMLANDI (rollback ile temiz birakildi) ===
