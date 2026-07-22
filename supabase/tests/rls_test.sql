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
  ('00000000-0000-0000-0000-000000000000','33333333-3333-3333-3333-333333333333','authenticated','authenticated','staff@test.local'),
  -- U4/U5 yalnizca guvenlik testlerinde (29+) kullanilir; 01-28 etkilenmez.
  ('00000000-0000-0000-0000-000000000000','44444444-4444-4444-4444-444444444444','authenticated','authenticated','admin@test.local'),
  ('00000000-0000-0000-0000-000000000000','55555555-5555-5555-5555-555555555555','authenticated','authenticated','owner2@test.local');

-- ========== U1 (owner, B1) ==========
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

-- Onboarding'in TEK kapisi complete_onboarding'dir. Eski
-- create_business_with_owner RPC'si 20260718090100 ile kaldirildi (hizmetsiz
-- isletme uretebiliyordu); zorunlu ilk hizmet artik ayni transaction'da gelir.
select public.complete_onboarding(
  'Test Berber', 'TRY', 'Europe/Istanbul',
  'Koltuk', 250, 15, 10
) as b1 \gset
select set_config('test.b1', :'b1', true);

-- Zorunlu ilk hizmet onboarding icinde olustu; id'sini yakala.
select id as s1 from public.services where business_id = :'b1' \gset
select set_config('test.s1', :'s1', true);

-- Urun artik dogrudan INSERT ile acilamaz (20260718090000): tek yol
-- create_product_with_stock RPC'sidir. Ilk stogu 0 birakiyoruz ki asagidaki
-- manuel ledger hareketi trigger'i tek basina dogrulasin.
select public.create_product_with_stock(
  :'b1', 'Kola', 'KOLA-1', 3000, 'TRY', true, 0
) as p1 \gset
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

-- Uyelik artik dogrudan INSERT ile eklenemez (20260718090200): tek yol
-- add_business_member RPC'sidir (server-side yetki kontrolu + son owner
-- invariantini paylasan ortak kural seti).
select public.add_business_member(
  :'b1', '33333333-3333-3333-3333-333333333333', 'staff'
);

-- ========== U2 (yabanci isletme sahibi) ==========
select set_config('request.jwt.claims','{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select public.complete_onboarding(
  'Rakip Kuafor', 'TRY', 'Europe/Istanbul',
  'Sac Kesim', 300, 10, 5
) as b2 \gset
select set_config('test.b2', :'b2', true);

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

-- Deterministik rapor "as of": iş yeri gününün (Europe/Istanbul) ortası (öğlen).
-- Fixture'lar ve rapor RPC çağrıları bu sabite bağlanır; böylece CI gece yarısı
-- İstanbul saatine denk gelse bile seanslar aynı gün kovasında kalır (flaky yok).
select set_config('test.report_asof',
  ((date_trunc('day', now() at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul')
     + interval '12 hours')::text, true);

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
  current_setting('test.report_asof')::timestamptz - interval '20 min',
  current_setting('test.report_asof')::timestamptz - interval '10 min', 30,
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
  current_setting('test.report_asof')::timestamptz - interval '8 min',
  current_setting('test.report_asof')::timestamptz - interval '5 min', 20,
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
  select * into r from public.report_revenue_summary(
           current_setting('test.b1')::uuid,
           current_setting('test.report_asof')::timestamptz)
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
  select * into r from public.report_top_services(current_setting('test.b1')::uuid, 'day', 5,
           current_setting('test.report_asof')::timestamptz) limit 1;
  if r.service_name = 'Koltuk' and r.completed_count = 2 and r.service_revenue_minor = 12500 then
    raise notice 'PASS 26: en cok gelir getiren hizmet dogru (Koltuk x2, 12500)';
  else
    raise exception 'FAIL 26: top_services yanlis';
  end if;
end $$;

do $$
declare r record;
begin
  select * into r from public.report_top_products(current_setting('test.b1')::uuid, 'day', 5,
           current_setting('test.report_asof')::timestamptz) limit 1;
  if r.product_name = 'Kola' and r.sold_quantity = 1 and r.product_revenue_minor = 3000 then
    raise notice 'PASS 27: en cok satilan urun dogru (Kola x1, 3000)';
  else
    raise exception 'FAIL 27: top_products yanlis';
  end if;
end $$;

do $$
declare r record; v_cnt int;
begin
  select count(*) into v_cnt from public.report_top_customers(current_setting('test.b1')::uuid, 'day', 5,
           current_setting('test.report_asof')::timestamptz);
  select * into r from public.report_top_customers(current_setting('test.b1')::uuid, 'day', 5,
           current_setting('test.report_asof')::timestamptz) limit 1;
  -- Misafir seans haric: yalnizca Ali gorunur, harcama 10500.
  if v_cnt = 1 and r.customer_name = 'Ali' and r.spending_minor = 10500 then
    raise notice 'PASS 28: en cok harcayan musteri dogru (Ali 10500, misafir haric)';
  else
    raise exception 'FAIL 28: top_customers yanlis: adet=%, ad=%, harcama=%',
      v_cnt, r.customer_name, r.spending_minor;
  end if;
end $$;

-- =============================================================
-- GUVENLIK SIKILASTIRMA TESTLERI (29-51)
-- Migration 20260718090000 / 090100 / 090200 icin pozitif + negatif senaryolar.
-- =============================================================

-- Owner (U1, B1) baglamina don.
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

-- ---------- P0-1: stok ledger bypass ----------

do $$ begin
  update public.products
     set stock_quantity = 9999
   where id = current_setting('test.p1')::uuid;
  raise exception 'FAIL 29: owner stock_quantity''yi dogrudan yazabildi (ledger bypass)!';
exception when insufficient_privilege then
  raise notice 'PASS 29: dogrudan stock_quantity UPDATE reddedildi (kolon grant''i yok)';
end $$;

do $$ begin
  insert into public.products (business_id, name, unit_price_minor, currency_code, track_stock, stock_quantity)
  values (current_setting('test.b1')::uuid, 'Kacak Urun', 100, 'TRY', true, 500);
  raise exception 'FAIL 30: stok verilerek dogrudan urun INSERT edilebildi!';
exception when insufficient_privilege then
  raise notice 'PASS 30: dogrudan urun INSERT reddedildi (yalniz create_product_with_stock)';
end $$;

-- Pozitif kontrol: izin verilen kolonlar hala duzenlenebilmeli.
update public.products
   set name = 'Kola Zero', unit_price_minor = 3500, is_active = true
 where id = current_setting('test.p1')::uuid;
\echo PASS 31: izin verilen kolonlar (name/unit_price_minor/is_active) guncellenebiliyor

do $$ begin
  update public.products
     set business_id = current_setting('test.b2')::uuid
   where id = current_setting('test.p1')::uuid;
  raise exception 'FAIL 32: business_id degistirilebildi (tenant kacisi)!';
exception when insufficient_privilege then
  raise notice 'PASS 32: business_id UPDATE reddedildi (tenant kimligi sabit)';
end $$;

do $$ begin
  update public.products
     set currency_code = 'USD'
   where id = current_setting('test.p1')::uuid;
  raise exception 'FAIL 33: currency_code degistirilebildi (snapshot tutarsizligi)!';
exception when insufficient_privilege then
  raise notice 'PASS 33: currency_code UPDATE reddedildi';
end $$;

-- RPC ile olusturulan urunde ledger toplami == cache (kaynak/cache tutarliligi).
do $$
declare
  v_prod uuid := current_setting('test.prod')::uuid;
  v_ledger bigint;
  v_cache bigint;
begin
  select coalesce(sum(quantity_delta), 0) into v_ledger
  from public.inventory_movements where product_id = v_prod;
  select stock_quantity into v_cache
  from public.products where id = v_prod;

  if v_ledger = v_cache and v_cache = 24 then
    raise notice 'PASS 34: RPC ilk stogunda ledger toplami (%) = cache (%)', v_ledger, v_cache;
  else
    raise exception 'FAIL 34: ledger (%) ile cache (%) ayristi', v_ledger, v_cache;
  end if;
end $$;

-- Staff yetkisizligi: ne RPC ile urun acabilir ne de mevcut urunu guncelleyebilir.
select set_config('request.jwt.claims','{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

do $$ begin
  perform public.create_product_with_stock(
    current_setting('test.b1')::uuid, 'Staff Urunu', null, 100, 'TRY', true, 5
  );
  raise exception 'FAIL 35: staff RPC ile urun olusturabildi!';
exception when raise_exception then
  if sqlerrm = 'not_authorized' then
    raise notice 'PASS 35: staff create_product_with_stock cagiramiyor (not_authorized)';
  else raise; end if;
end $$;

do $$
declare v_rows integer;
begin
  update public.products set name = 'Staff Degisikligi'
   where id = current_setting('test.p1')::uuid;
  get diagnostics v_rows = row_count;
  -- RLS UPDATE policy'si owner/admin ister; staff icin hicbir satir eslesmez.
  if v_rows = 0 then
    raise notice 'PASS 36: staff urun guncelleyemiyor (RLS policy 0 satir esledi)';
  else
    raise exception 'FAIL 36: staff % urun satiri guncelledi!', v_rows;
  end if;
end $$;

-- Trigger katmani: GRANT'i olan service_role bile cache'e dogrudan yazamaz.
-- Bu, korumanin yalniz grant'e degil DB invariantina dayandigini kanitlar.
set local role service_role;
do $$ begin
  update public.products
     set stock_quantity = 9999
   where id = current_setting('test.p1')::uuid;
  raise exception 'FAIL 37: service_role stock_quantity''yi dogrudan yazabildi!';
exception when raise_exception then
  if sqlerrm = 'stock_quantity_direct_write_denied' then
    raise notice 'PASS 37: service_role dahi cache''e dogrudan yazamiyor (trigger guard)';
  else raise; end if;
end $$;
set local role authenticated;

-- ---------- P0-2: eski onboarding RPC bypass'i ----------

select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

do $$ begin
  perform public.create_business_with_owner('Bypass Isletmesi');
  raise exception 'FAIL 38: eski create_business_with_owner RPC''si hala cagrilabiliyor!';
exception when undefined_function then
  raise notice 'PASS 38: eski create_business_with_owner RPC''si kaldirildi (undefined_function)';
end $$;

-- Hizmet adi bos ise: hizmet de isletme de owner uyeligi de olusmamali.
do $$
declare v_before integer; v_after integer; v_members_before integer; v_members_after integer;
begin
  select count(*) into v_before from public.businesses;
  select count(*) into v_members_before from public.business_members;
  begin
    perform public.complete_onboarding('Hizmetsiz', 'TRY', 'Europe/Istanbul', '   ', 100, 1, 0);
    raise exception 'FAIL 39: hizmetsiz onboarding kabul edildi!';
  exception when raise_exception then
    if sqlerrm <> 'service_name_required' then raise; end if;
  end;
  select count(*) into v_after from public.businesses;
  select count(*) into v_members_after from public.business_members;

  if v_before = v_after and v_members_before = v_members_after then
    raise notice 'PASS 39: hizmet olusturulamayinca isletme ve owner uyeligi de olusmadi';
  else
    raise exception 'FAIL 39: yarim kayit kaldi (isletme %/%, uyelik %/%)',
      v_before, v_after, v_members_before, v_members_after;
  end if;
end $$;

-- ---------- P0-3: uyelik yonetimi + son owner invarianti ----------

-- Test kadrosu: U4 admin, U5 staff olarak B1'e eklenir (owner U1 tarafindan).
select public.add_business_member(
  current_setting('test.b1')::uuid, '44444444-4444-4444-4444-444444444444', 'admin'
) as m_admin \gset
select set_config('test.m_admin', :'m_admin', true);

select public.add_business_member(
  current_setting('test.b1')::uuid, '55555555-5555-5555-5555-555555555555', 'staff'
) as m_owner2 \gset
select set_config('test.m_owner2', :'m_owner2', true);

select set_config('test.m_owner1',
  (select id::text from public.business_members
   where business_id = current_setting('test.b1')::uuid
     and user_id = '11111111-1111-1111-1111-111111111111'), true);

select set_config('test.m_staff',
  (select id::text from public.business_members
   where business_id = current_setting('test.b1')::uuid
     and user_id = '33333333-3333-3333-3333-333333333333'), true);

-- Dogrudan tablo yazmalari tamamen kapali olmali.
do $$ begin
  insert into public.business_members (business_id, user_id, role)
  values (current_setting('test.b1')::uuid, '22222222-2222-2222-2222-222222222222', 'admin');
  raise exception 'FAIL 40: business_members''a dogrudan INSERT yapilabildi!';
exception when insufficient_privilege then
  raise notice 'PASS 40: dogrudan uyelik INSERT reddedildi (yalniz add_business_member)';
end $$;

do $$ begin
  update public.business_members set role = 'owner'
   where id = current_setting('test.m_staff')::uuid;
  raise exception 'FAIL 41: business_members dogrudan UPDATE edilebildi (yetki yukseltme)!';
exception when insufficient_privilege then
  raise notice 'PASS 41: dogrudan uyelik UPDATE reddedildi (yalniz RPC)';
end $$;

do $$ begin
  delete from public.business_members where id = current_setting('test.m_staff')::uuid;
  raise exception 'FAIL 42: business_members dogrudan DELETE edilebildi!';
exception when insufficient_privilege then
  raise notice 'PASS 42: dogrudan uyelik DELETE reddedildi (yalniz RPC)';
end $$;

-- Son owner: silinemez / pasiflestirilemez / rolu dusurulemez.
do $$ begin
  perform public.remove_business_member(current_setting('test.m_owner1')::uuid);
  raise exception 'FAIL 43: son owner kendini silebildi (isletme sahipsiz kalirdi)!';
exception when raise_exception then
  if sqlerrm = 'last_owner_protected' then
    raise notice 'PASS 43: son owner silinemiyor (last_owner_protected)';
  else raise; end if;
end $$;

do $$ begin
  perform public.set_business_member_active(current_setting('test.m_owner1')::uuid, false);
  raise exception 'FAIL 44: son owner pasiflestirilebildi!';
exception when raise_exception then
  if sqlerrm = 'last_owner_protected' then
    raise notice 'PASS 44: son owner pasiflestirilemiyor';
  else raise; end if;
end $$;

do $$ begin
  perform public.update_business_member_role(current_setting('test.m_owner1')::uuid, 'staff');
  raise exception 'FAIL 45: son owner''in rolu dusurulebildi!';
exception when raise_exception then
  if sqlerrm = 'last_owner_protected' then
    raise notice 'PASS 45: son owner''in rolu dusurulemiyor';
  else raise; end if;
end $$;

-- Admin yetki yukseltme korumasi.
select set_config('request.jwt.claims','{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);

do $$ begin
  perform public.update_business_member_role(current_setting('test.m_admin')::uuid, 'owner');
  raise exception 'FAIL 46: admin kendini owner yapabildi!';
exception when raise_exception then
  if sqlerrm = 'not_authorized' then
    raise notice 'PASS 46: admin kendini owner yapamiyor';
  else raise; end if;
end $$;

do $$ begin
  perform public.set_business_member_active(current_setting('test.m_owner1')::uuid, false);
  raise exception 'FAIL 47: admin owner satirini pasiflestirebildi!';
exception when raise_exception then
  if sqlerrm = 'not_authorized' then
    raise notice 'PASS 47: admin owner satirina dokunamiyor';
  else raise; end if;
end $$;

-- Staff hicbir uyelik islemi yapamaz.
select set_config('request.jwt.claims','{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

do $$ begin
  perform public.add_business_member(
    current_setting('test.b1')::uuid, '22222222-2222-2222-2222-222222222222', 'staff'
  );
  raise exception 'FAIL 48: staff uye ekleyebildi!';
exception when raise_exception then
  if sqlerrm = 'not_authorized' then
    raise notice 'PASS 48: staff uyelik yonetemiyor';
  else raise; end if;
end $$;

-- Tenant sinirini asma denemesi: B2 sahibi U2, B1'in uyeligini yonetemez.
select set_config('request.jwt.claims','{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

do $$ begin
  perform public.update_business_member_role(current_setting('test.m_staff')::uuid, 'admin');
  raise exception 'FAIL 49: baska isletmenin uyeligi degistirilebildi!';
exception when raise_exception then
  if sqlerrm = 'not_a_member' then
    raise notice 'PASS 49: baska isletmenin uyeligi degistirilemiyor (not_a_member)';
  else raise; end if;
end $$;

-- Ikinci owner varsa ilk owner GUVENLE ayrilabilir (invariant korunur).
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select public.update_business_member_role(current_setting('test.m_owner2')::uuid, 'owner');
select public.set_business_member_active(current_setting('test.m_owner1')::uuid, false);

-- Ayrilan owner artik aktif uye olmadigi icin business_members SELECT
-- policy'si ona hicbir satir gostermez (dogru davranis). Invarianti bu yuzden
-- HALA uye olan yeni owner (U5) baglaminda dogruluyoruz.
select set_config('request.jwt.claims','{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);

do $$
declare v_active_owners integer;
begin
  select count(*) into v_active_owners
  from public.business_members
  where business_id = current_setting('test.b1')::uuid
    and role = 'owner' and is_active;

  if v_active_owners = 1 then
    raise notice 'PASS 50: ikinci owner varken ilk owner ayrilabildi, 1 aktif owner kaldi';
  else
    raise exception 'FAIL 50: ayrilma sonrasi aktif owner sayisi % (1 olmaliydi)', v_active_owners;
  end if;
end $$;

-- Atomik sahiplik devri: U5 (owner) -> U4 (admin).
select set_config('request.jwt.claims','{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);

select public.transfer_business_ownership(
  current_setting('test.b1')::uuid, current_setting('test.m_admin')::uuid
);

do $$
declare v_new_owner public.member_role; v_old_owner public.member_role; v_owner_count integer;
begin
  select role into v_new_owner from public.business_members
   where id = current_setting('test.m_admin')::uuid;
  select role into v_old_owner from public.business_members
   where id = current_setting('test.m_owner2')::uuid;
  select count(*) into v_owner_count from public.business_members
   where business_id = current_setting('test.b1')::uuid and role = 'owner' and is_active;

  if v_new_owner = 'owner' and v_old_owner = 'admin' and v_owner_count = 1 then
    raise notice 'PASS 51: sahiplik atomik devredildi (hedef owner, cagiran admin, tek owner)';
  else
    raise exception 'FAIL 51: devir bozuk (yeni=%, eski=%, owner adedi=%)',
      v_new_owner, v_old_owner, v_owner_count;
  end if;
end $$;

-- =============================================================
-- ODEME VE TAHSILAT TESTLERI (52-70)
-- Kontrat: docs/contracts/payment-contract.md
--
-- Izole kurulum: yukaridaki testler B1'in sahipligini/uyeligini degistirdigi
-- icin odeme testleri KENDI isletmesini (B3) ve kendi kullanicilarini kurar.
-- Boylece bu blok yukaridaki testlerin son durumuna bagimli degildir.
-- =============================================================

-- auth.users yazimi superuser gerektirir; rolu gecici olarak birakiyoruz.
reset role;

insert into auth.users (instance_id, id, aud, role, email)
values
  ('00000000-0000-0000-0000-000000000000','66666666-6666-6666-6666-666666666666','authenticated','authenticated','payowner@test.local'),
  ('00000000-0000-0000-0000-000000000000','77777777-7777-7777-7777-777777777777','authenticated','authenticated','paystaff@test.local'),
  ('00000000-0000-0000-0000-000000000000','88888888-8888-8888-8888-888888888888','authenticated','authenticated','payadmin@test.local'),
  ('00000000-0000-0000-0000-000000000000','99999999-9999-9999-9999-999999999999','authenticated','authenticated','payrival@test.local');

set local role authenticated;

-- ---------- B3 kurulumu (U6 owner) ----------
-- Hizmet: dakikasi 10,00 TRY, yuvarlama 1 dk, minimum 45 dk.
-- Seans hemen tamamlandigi icin aktif sure ~0 => charged = max(0, 45) = 45 dk
-- => grand_total = 45 * 1000 = 45000 kurus = 450,00 TRY (deterministik).
select set_config('request.jwt.claims','{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}', true);

select public.complete_onboarding(
  'Odeme Testi', 'TRY', 'Europe/Istanbul',
  'Saatlik Salon', 1000, 1, 45
) as b3 \gset
select set_config('test.b3', :'b3', true);

select id as s3 from public.services where business_id = :'b3' \gset
select set_config('test.s3', :'s3', true);

select public.add_business_member(:'b3', '77777777-7777-7777-7777-777777777777', 'staff') as m_pstaff \gset
select set_config('test.m_pstaff', :'m_pstaff', true);
select public.add_business_member(:'b3', '88888888-8888-8888-8888-888888888888', 'admin') as m_padmin \gset
select set_config('test.m_padmin', :'m_padmin', true);

-- Odenecek seans: baslat + tamamla.
select public.start_session(:'b3', :'s3') as psess \gset
select set_config('test.psess', :'psess', true);
select public.complete_session(:'psess');

do $$
declare v_total bigint; v_status public.session_status;
begin
  select grand_total_minor, status into v_total, v_status
  from public.sessions where id = current_setting('test.psess')::uuid;
  if v_total = 45000 and v_status = 'completed' then
    raise notice 'PASS 52: odenecek seans hazir (tamamlandi, toplam 45000 kurus)';
  else
    raise exception 'FAIL 52: seans hazir degil (toplam=%, durum=%)', v_total, v_status;
  end if;
end $$;

-- ---------- 53: tamamlanmis seans varsayilan olarak ODENMEMISTIR ----------
do $$
declare v jsonb;
begin
  v := public.get_session_payment_summary(current_setting('test.psess')::uuid);
  if v->>'payment_status' = 'unpaid'
     and (v->>'net_paid_minor')::bigint = 0
     and (v->>'remaining_minor')::bigint = 45000 then
    raise notice 'PASS 53: tamamlanan seans odenmemis basliyor (unpaid, kalan 45000)';
  else
    raise exception 'FAIL 53: beklenmeyen ozet %', v;
  end if;
end $$;

-- ---------- 54: STAFF tahsilat kaydedebilir (kismi odeme) ----------
select set_config('request.jwt.claims','{"sub":"77777777-7777-7777-7777-777777777777","role":"authenticated"}', true);

do $$
declare v jsonb;
begin
  v := public.record_session_payment(
    current_setting('test.psess')::uuid, 'cash', 30000, 'idem-cash-1'
  );
  perform set_config('test.pay_cash', v->>'payment_id', true);
  if v->>'payment_status' = 'partially_paid'
     and (v->>'net_paid_minor')::bigint = 30000
     and (v->>'remaining_minor')::bigint = 15000
     and (v->>'replayed')::boolean = false then
    raise notice 'PASS 54: staff 30000 nakit tahsil etti => partially_paid, kalan 15000';
  else
    raise exception 'FAIL 54: beklenmeyen ozet %', v;
  end if;
end $$;

-- ---------- 55: AŞIRI ODEME sunucuda reddedilir ----------
do $$
declare v jsonb;
begin
  begin
    v := public.record_session_payment(
      current_setting('test.psess')::uuid, 'card', 20000, 'idem-over-1'
    );
    raise exception 'FAIL 55: kalan 15000 iken 20000 tahsilat KABUL EDILDI';
  exception when sqlstate 'P0001' then
    if sqlerrm = 'payment_exceeds_balance' then
      raise notice 'PASS 55: asiri odeme reddedildi (payment_exceeds_balance)';
    else
      raise exception 'FAIL 55: yanlis hata %', sqlerrm;
    end if;
  end;
end $$;

-- ---------- 56: AYNI idempotency key IKINCI odeme uretmez ----------
do $$
declare v jsonb; v_count integer;
begin
  v := public.record_session_payment(
    current_setting('test.psess')::uuid, 'cash', 30000, 'idem-cash-1'
  );
  select count(*) into v_count from public.payments
   where business_id = current_setting('test.b3')::uuid and idempotency_key = 'idem-cash-1';

  if v_count = 1
     and (v->>'replayed')::boolean = true
     and (v->>'net_paid_minor')::bigint = 30000 then
    raise notice 'PASS 56: ayni idempotency key tek odeme uretti (replayed=true)';
  else
    raise exception 'FAIL 56: kayit adedi %, ozet %', v_count, v;
  end if;
end $$;

-- ---------- 57: BOLUNMUS odeme paid durumuna ulasir ----------
do $$
declare v jsonb;
begin
  v := public.record_session_payment(
    current_setting('test.psess')::uuid, 'card', 15000, 'idem-card-1'
  );
  perform set_config('test.pay_card', v->>'payment_id', true);
  if v->>'payment_status' = 'paid'
     and (v->>'net_paid_minor')::bigint = 45000
     and (v->>'remaining_minor')::bigint = 0 then
    raise notice 'PASS 57: 30000 nakit + 15000 kart => paid, kalan 0';
  else
    raise exception 'FAIL 57: beklenmeyen ozet %', v;
  end if;
end $$;

-- ---------- 58: odeme para birimi seansinkiyle AYNI ----------
do $$
declare v_bad integer;
begin
  select count(*) into v_bad
  from public.payments p
  join public.payment_allocations a on a.payment_id = p.id
  join public.sessions s on s.id = a.session_id
  where a.session_id = current_setting('test.psess')::uuid
    and p.currency_code <> s.currency_code_snapshot;
  if v_bad = 0 then
    raise notice 'PASS 58: tum odemeler seans para birimiyle ayni (TRY)';
  else
    raise exception 'FAIL 58: % odemede para birimi uyusmazligi', v_bad;
  end if;
end $$;

-- ---------- 59: STAFF iptal EDEMEZ ----------
do $$
begin
  begin
    perform public.void_payment(current_setting('test.pay_card')::uuid, 'yanlis giris');
    raise exception 'FAIL 59: staff odeme iptal edebildi';
  exception when sqlstate 'P0001' then
    if sqlerrm = 'not_authorized' then
      raise notice 'PASS 59: staff iptal edemedi (not_authorized)';
    else
      raise exception 'FAIL 59: yanlis hata %', sqlerrm;
    end if;
  end;
end $$;

-- ---------- 60: STAFF iade EDEMEZ ----------
do $$
begin
  begin
    perform public.refund_payment(
      current_setting('test.pay_cash')::uuid, 10000, 'idem-ref-x', 'musteri istedi'
    );
    raise exception 'FAIL 60: staff iade edebildi';
  exception when sqlstate 'P0001' then
    if sqlerrm = 'not_authorized' then
      raise notice 'PASS 60: staff iade edemedi (not_authorized)';
    else
      raise exception 'FAIL 60: yanlis hata %', sqlerrm;
    end if;
  end;
end $$;

-- ---------- 61: ADMIN iptal edebilir; iptal edilen odeme NET TOPLAMDAN CIKAR ----------
select set_config('request.jwt.claims','{"sub":"88888888-8888-8888-8888-888888888888","role":"authenticated"}', true);

do $$
declare v jsonb; v_status public.payment_status;
begin
  v := public.void_payment(current_setting('test.pay_card')::uuid, 'kart cekimi iptal edildi');
  select status into v_status from public.payments
   where id = current_setting('test.pay_card')::uuid;

  if v_status = 'voided'
     and v->>'payment_status' = 'partially_paid'
     and (v->>'net_paid_minor')::bigint = 30000
     and (v->>'remaining_minor')::bigint = 15000 then
    raise notice 'PASS 61: admin iptal etti, iptalli odeme net toplamdan cikti';
  else
    raise exception 'FAIL 61: durum=%, ozet=%', v_status, v;
  end if;
end $$;

-- ---------- 62: iptal edilen odeme SILINMEZ, kayit durur ----------
do $$
declare v_exists boolean; v_reason text;
begin
  select true, void_reason into v_exists, v_reason
  from public.payments where id = current_setting('test.pay_card')::uuid;
  if coalesce(v_exists,false) and v_reason = 'kart cekimi iptal edildi' then
    raise notice 'PASS 62: iptal edilen odeme fiziksel silinmedi, gerekce saklandi';
  else
    raise exception 'FAIL 62: kayit kayboldu veya gerekce yok';
  end if;
end $$;

-- ---------- 63: ayni odeme IKINCI kez iptal edilemez ----------
do $$
begin
  begin
    perform public.void_payment(current_setting('test.pay_card')::uuid, 'tekrar');
    raise exception 'FAIL 63: ayni odeme iki kez iptal edildi';
  exception when sqlstate 'P0001' then
    if sqlerrm = 'payment_already_voided' then
      raise notice 'PASS 63: ikinci iptal kararli hata dondurdu (payment_already_voided)';
    else
      raise exception 'FAIL 63: yanlis hata %', sqlerrm;
    end if;
  end;
end $$;

-- ---------- 64: ADMIN kismi iade edebilir; orijinal kayit DEGISMEZ ----------
do $$
declare v jsonb; v_orig_amount bigint; v_orig_status public.payment_status;
begin
  v := public.refund_payment(
    current_setting('test.pay_cash')::uuid, 10000, 'idem-refund-1', 'musteri memnun kalmadi'
  );
  select amount_minor, status into v_orig_amount, v_orig_status
  from public.payments where id = current_setting('test.pay_cash')::uuid;

  -- net = 30000 tahsilat - 10000 iade = 20000; kalan = 45000 - 20000 = 25000
  if v->>'payment_status' = 'partially_paid'
     and (v->>'net_paid_minor')::bigint = 20000
     and (v->>'refunded_minor')::bigint = 10000
     and (v->>'remaining_minor')::bigint = 25000
     and v_orig_amount = 30000
     and v_orig_status = 'completed' then
    raise notice 'PASS 64: kismi iade yeni kayit acti, orijinal odeme degismedi';
  else
    raise exception 'FAIL 64: ozet=%, orijinal tutar=%, orijinal durum=%',
      v, v_orig_amount, v_orig_status;
  end if;
end $$;

-- ---------- 65: iade IADE EDILEBILIR tutari asamaz ----------
do $$
begin
  begin
    -- 30000'lik tahsilattan 10000 iade edildi => kalan iade edilebilir 20000
    perform public.refund_payment(
      current_setting('test.pay_cash')::uuid, 25000, 'idem-refund-2', 'fazla iade denemesi'
    );
    raise exception 'FAIL 65: iade edilebilir tutar asildi ama kabul edildi';
  exception when sqlstate 'P0001' then
    if sqlerrm = 'refund_exceeds_refundable' then
      raise notice 'PASS 65: asiri iade reddedildi (refund_exceeds_refundable)';
    else
      raise exception 'FAIL 65: yanlis hata %', sqlerrm;
    end if;
  end;
end $$;

-- ---------- 66: iptal ve iade DENETIM kaydi olusturur ----------
do $$
declare v_recorded integer; v_voided integer; v_refunded integer;
begin
  select
    count(*) filter (where event_type = 'payment_recorded'),
    count(*) filter (where event_type = 'payment_voided'),
    count(*) filter (where event_type = 'payment_refunded')
  into v_recorded, v_voided, v_refunded
  from public.payment_events
  where business_id = current_setting('test.b3')::uuid;

  if v_recorded = 2 and v_voided = 1 and v_refunded = 1 then
    raise notice 'PASS 66: denetim kayitlari yazildi (2 tahsilat, 1 iptal, 1 iade)';
  else
    raise exception 'FAIL 66: denetim sayilari kayit=% iptal=% iade=%',
      v_recorded, v_voided, v_refunded;
  end if;
end $$;

-- ---------- 67: AKTIF / IPTAL EDILMIS seans odenemez ----------
do $$
declare v_active uuid; v_cancelled uuid;
begin
  v_active := public.start_session(
    current_setting('test.b3')::uuid, current_setting('test.s3')::uuid
  );
  begin
    perform public.record_session_payment(v_active, 'cash', 1000, 'idem-active-1');
    raise exception 'FAIL 67a: aktif seans odenebildi';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'session_not_payable' then
      raise exception 'FAIL 67a: yanlis hata %', sqlerrm;
    end if;
  end;

  perform public.cancel_session(v_active);
  begin
    perform public.record_session_payment(v_active, 'cash', 1000, 'idem-cancel-1');
    raise exception 'FAIL 67b: iptal edilmis seans odenebildi';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'session_not_payable' then
      raise exception 'FAIL 67b: yanlis hata %', sqlerrm;
    end if;
  end;

  raise notice 'PASS 67: aktif ve iptal edilmis seanslar odenemedi (session_not_payable)';
end $$;

-- ---------- 68: CAPRAZ TENANT okuma engellenir ----------
select set_config('request.jwt.claims','{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated"}', true);

do $$
declare v_visible integer;
begin
  select count(*) into v_visible
  from public.payments where business_id = current_setting('test.b3')::uuid;
  if v_visible = 0 then
    raise notice 'PASS 68: baska isletmenin uyesi odemeleri GOREMIYOR (RLS)';
  else
    raise exception 'FAIL 68: caprazdan % odeme gorundu', v_visible;
  end if;
end $$;

-- ---------- 69: CAPRAZ TENANT mutasyonu engellenir ----------
do $$
begin
  begin
    perform public.record_session_payment(
      current_setting('test.psess')::uuid, 'cash', 1000, 'idem-cross-1'
    );
    raise exception 'FAIL 69a: caprazdan odeme kaydedildi';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'not_a_member' then
      raise exception 'FAIL 69a: yanlis hata %', sqlerrm;
    end if;
  end;

  begin
    perform public.void_payment(current_setting('test.pay_cash')::uuid, 'caprazdan iptal');
    raise exception 'FAIL 69b: caprazdan iptal edildi';
  exception when sqlstate 'P0001' then
    -- Varligi sizdirmamak icin "bulunamadi" doner.
    if sqlerrm <> 'payment_not_found' then
      raise exception 'FAIL 69b: yanlis hata %', sqlerrm;
    end if;
  end;

  begin
    perform public.get_session_payment_summary(current_setting('test.psess')::uuid);
    raise exception 'FAIL 69c: caprazdan ozet okundu';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'session_not_found' then
      raise exception 'FAIL 69c: yanlis hata %', sqlerrm;
    end if;
  end;

  raise notice 'PASS 69: caprazdan tahsilat/iptal/ozet ucu de engellendi';
end $$;

-- ---------- 70: DOGRUDAN tablo yazimi hicbir role acik degil ----------
select set_config('request.jwt.claims','{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}', true);

do $$
declare v_insert_blocked boolean := false;
        v_update_blocked boolean := false;
        v_delete_blocked boolean := false;
begin
  -- Owner bile dogrudan yazamaz: GRANT yok, RLS'te insert/update/delete
  -- politikasi da yok (fail-closed).
  begin
    insert into public.payments (
      business_id, payment_kind, payment_method, amount_minor,
      currency_code, idempotency_key, received_by_member_id
    ) values (
      current_setting('test.b3')::uuid, 'collection', 'cash', 100,
      'TRY', 'idem-direct-1',
      (select id from public.business_members
        where business_id = current_setting('test.b3')::uuid
          and user_id = '66666666-6666-6666-6666-666666666666')
    );
  exception when insufficient_privilege or check_violation then
    v_insert_blocked := true;
  end;

  begin
    update public.payments set amount_minor = 1
     where id = current_setting('test.pay_cash')::uuid;
    -- Grant yoksa buraya hic gelinmez; geldiyse etkilenen satir 0 olmali.
    if not found then v_update_blocked := true; end if;
  exception when insufficient_privilege then
    v_update_blocked := true;
  end;

  begin
    delete from public.payments where id = current_setting('test.pay_cash')::uuid;
    if not found then v_delete_blocked := true; end if;
  exception when insufficient_privilege then
    v_delete_blocked := true;
  end;

  if v_insert_blocked and v_update_blocked and v_delete_blocked then
    raise notice 'PASS 70: odeme tablosuna dogrudan INSERT/UPDATE/DELETE engellendi';
  else
    raise exception 'FAIL 70: dogrudan yazim acik (insert=%, update=%, delete=%)',
      v_insert_blocked, v_update_blocked, v_delete_blocked;
  end if;
end $$;

-- ---------- 71: RAPOR satis ile tahsilati AYRI dondurur ----------
-- B3 durumu: seans toplami 45000; 30000 nakit tahsil edildi; 15000 kart
-- tahsilati IPTAL edildi; 10000 iade edildi.
-- Beklenen: satis 45000 (degismedi), nakit 30000, kart 0 (iptalli sayilmaz),
-- iade 10000, net tahsilat 20000, alacak 25000.
do $$
declare r record;
begin
  select * into r
  from public.report_collection_summary(current_setting('test.b3')::uuid)
  where period = 'day';

  if r.finalized_sales_minor = 45000
     and r.cash_collected_minor = 30000
     and r.card_collected_minor = 0
     and r.refunded_minor = 10000
     and r.net_collected_minor = 20000
     and r.outstanding_minor = 25000 then
    raise notice 'PASS 71: rapor satis(45000) ile net tahsilati(20000) ayri dondurdu, iptalli kart sayilmadi';
  else
    raise exception 'FAIL 71: satis=%, nakit=%, kart=%, iade=%, net=%, alacak=%',
      r.finalized_sales_minor, r.cash_collected_minor, r.card_collected_minor,
      r.refunded_minor, r.net_collected_minor, r.outstanding_minor;
  end if;
end $$;

-- ---------- 72: rapor CAPRAZ TENANT'a kapali ----------
select set_config('request.jwt.claims','{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated"}', true);

do $$
begin
  begin
    perform * from public.report_collection_summary(current_setting('test.b3')::uuid);
    raise exception 'FAIL 72: caprazdan tahsilat raporu okundu';
  exception when sqlstate 'P0001' then
    if sqlerrm = 'not_a_member' then
      raise notice 'PASS 72: caprazdan tahsilat raporu engellendi (not_a_member)';
    else
      raise exception 'FAIL 72: yanlis hata %', sqlerrm;
    end if;
  end;
end $$;

-- ---------- 73: idempotency anahtari BASKA seansa yeniden kullanilamaz ----------
-- Regresyon: bu guard olmadan istek "basarili + replayed" donuyor ama ikinci
-- seans HIC odenmiyordu. Arayuz tahsil edildi saniyor, kayit yok => sessiz
-- para kaybi. Istemciye guvenilmez; sunucu bunu reddetmek zorunda.
select set_config('request.jwt.claims','{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}', true);

do $$
declare v_other uuid; v_net bigint;
begin
  v_other := public.start_session(
    current_setting('test.b3')::uuid, current_setting('test.s3')::uuid
  );
  perform public.complete_session(v_other);

  begin
    -- 'idem-cash-1' zaten test.psess icin kullanildi.
    perform public.record_session_payment(v_other, 'cash', 1000, 'idem-cash-1');
    raise exception 'FAIL 73: anahtar baska seansta yeniden kullanilabildi';
  exception when sqlstate 'P0001' then
    if sqlerrm <> 'payment_idempotency_key_reused' then
      raise exception 'FAIL 73: yanlis hata %', sqlerrm;
    end if;
  end;

  -- Ikinci seans gercekten odenmemis olmali (sessizce "odendi" gorunmemeli).
  -- Dahili yardimci authenticated'a kapali oldugu icin genel API'den okunur.
  select (public.get_session_payment_summary(v_other)->>'net_paid_minor')::bigint
    into v_net;
  if v_net <> 0 then
    raise exception 'FAIL 73: ikinci seans net_paid % (0 olmaliydi)', v_net;
  end if;

  raise notice 'PASS 73: anahtar yeniden kullanimi reddedildi, sessiz odeme kaybi yok';
end $$;

-- ---------- 74: ayni guard IADE tarafinda da var ----------
do $$
begin
  begin
    -- 'idem-refund-1' zaten test.pay_cash iadesi icin kullanildi;
    -- simdi BASKA bir orijinal odeme (pay_card) icin deneniyor.
    perform public.refund_payment(
      current_setting('test.pay_card')::uuid, 1000, 'idem-refund-1', 'yanlis anahtar'
    );
    raise exception 'FAIL 74: iade anahtari baska odemede yeniden kullanilabildi';
  exception when sqlstate 'P0001' then
    if sqlerrm not in ('payment_idempotency_key_reused', 'not_authorized', 'payment_not_found') then
      raise exception 'FAIL 74: yanlis hata %', sqlerrm;
    end if;
    raise notice 'PASS 74: iade tarafinda da anahtar yeniden kullanimi engellendi (%)', sqlerrm;
  end;
end $$;

-- ---------- 75: TOPLU odeme durumu tek turda doner ve tenant sizdirmaz ----------
do $$
declare v_rows integer; r record;
begin
  select count(*) into v_rows
  from public.get_sessions_payment_status(array[current_setting('test.psess')::uuid]);

  select * into r
  from public.get_sessions_payment_status(array[current_setting('test.psess')::uuid]);

  if v_rows = 1
     and r.session_total_minor = 45000
     and r.net_paid_minor = 20000
     and r.remaining_minor = 25000
     and r.payment_status = 'partially_paid' then
    raise notice 'PASS 75: toplu durum RPC dogru ozet dondurdu';
  else
    raise exception 'FAIL 75: satir=%, ozet=%', v_rows, r;
  end if;
end $$;

-- Capraz tenant: uye olunmayan seans sonuca HIC girmemeli.
select set_config('request.jwt.claims','{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated"}', true);

do $$
declare v_rows integer;
begin
  select count(*) into v_rows
  from public.get_sessions_payment_status(array[current_setting('test.psess')::uuid]);
  if v_rows = 0 then
    raise notice 'PASS 76: toplu durum RPC caprazdan hicbir satir sizdirmadi';
  else
    raise exception 'FAIL 76: caprazdan % satir dondu', v_rows;
  end if;
end $$;

-- ---------- 77: odeme tablolarinda authenticated YALNIZCA select yetkisine sahip ----------
-- Regresyon: Supabase varsayilanlari authenticated'a TUM tablolarda TRUNCATE,
-- TRIGGER ve REFERENCES birakiyor. TRUNCATE RLS'i TAMAMEN ATLAR; tek komutla
-- tum isletmelerin odemeleri silinebilirdi. Bu, "hicbir odeme kaydi fiziksel
-- olarak silinmez" garantisini cururdu. 20260719150000 ile kapatildi.
do $$
declare v_extra text;
begin
  select string_agg(privilege_type, ',' order by privilege_type)
    into v_extra
  from information_schema.role_table_grants
  where grantee = 'authenticated'
    and table_schema = 'public'
    and table_name in ('payments', 'payment_allocations', 'payment_events')
    and privilege_type <> 'SELECT';

  if v_extra is null then
    raise notice 'PASS 77: odeme tablolarinda authenticated yalnizca SELECT yetkisine sahip';
  else
    raise exception 'FAIL 77: fazladan yetkiler duruyor: %', v_extra;
  end if;
end $$;

rollback;
\echo === 77/77 TEST TAMAMLANDI (rollback ile temiz birakildi) ===
