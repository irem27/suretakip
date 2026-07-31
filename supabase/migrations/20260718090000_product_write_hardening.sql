-- =============================================================
-- SüreTakip - Migration 8: Ürün yazma yolunun sıkılaştırılması (P0-1)
--
-- SORUN: 20260717130100_rls.sql, authenticated role'e products tablosunda
-- GENEL insert/update yetkisi veriyordu. RLS policy'si yalnızca "hangi
-- SATIRA" dokunulabileceğini sınırlar, "hangi KOLONA" değil. Dolayısıyla
-- owner/admin şunu yapabiliyordu:
--
--   update products set stock_quantity = 99999 where id = ...;
--   insert into products (..., stock_quantity) values (..., 99999);
--
-- Bu, append-only inventory_movements ledger'ını tamamen atlar: ledger
-- toplamı ile cache ayrışır, stok denetlenemez hale gelir ve satış anındaki
-- "yeterli stok var mı" kontrolü uydurma bir sayıya dayanır.
--
-- ÇÖZÜM (üç katman):
--   1. GRANT katmanı  : genel insert/update kaldırılır, UPDATE yalnız
--                       güvenli kolonlara column-level olarak verilir.
--   2. RLS katmanı    : products INSERT policy'si düşürülür — grant ileride
--                       yanlışlıkla geri verilse bile RLS insert'i reddeder.
--   3. TRIGGER katmanı: stock_quantity'ye ledger trigger'ı dışından yazmak
--                       DB seviyesinde imkansız kılınır (service_role ve
--                       SECURITY DEFINER yolları dahil).
--
-- Bu migration ileri yönlüdür; önceki migration dosyaları değiştirilmemiştir.
-- =============================================================

-- ---------- Katman 1: GRANT ----------
-- Genel yetkiyi tamamen geri al, sonra yalnız güvenli kolonlara ver.
revoke insert, update on public.products from authenticated;

-- Ürün DÜZENLEME: yalnız bu kolonlar. Listede OLMAYAN kolonlar:
--   stock_quantity -> ledger trigger'ının cache'i (Katman 3 korur)
--   business_id    -> tenant kimliği; değişmesi kaydı başka işletmeye taşır
--   currency_code  -> geçmiş snapshot'larla tutarlılık; para birimi değişimi
--                     ürün kopyalanarak yapılır, yerinde düzenlenerek değil
--   id/created_at/updated_at -> sistem kolonları
grant update (
  name,
  sku,
  unit_price_minor,
  track_stock,
  is_active,
  archived_at
) on public.products to authenticated;

-- Ürün OLUŞTURMA: hiç grant verilmez. Tek yol create_product_with_stock
-- RPC'sidir (SECURITY DEFINER); ilk stoğu cache'e değil ledger'a 'initial'
-- hareketi olarak yazar, cache'i trigger doldurur.

-- ---------- Katman 2: RLS ----------
-- Grant kaldırıldığı için bu policy zaten ulaşılamaz durumda. Yine de
-- DÜŞÜRÜYORUZ: ileride biri "grant insert on products to authenticated"
-- yazarsa, INSERT policy'si olmayan bir RLS tablosu insert'i REDDEDER.
-- Politikayı bırakmak, o hatayı sessizce çalışır hale getirirdi.
drop policy if exists "owner/admin can insert products" on public.products;

-- UPDATE policy'si korunur: column-level grant "hangi kolon", RLS "hangi
-- satır" sorusunu yanıtlar. İkisi birlikte gerekir.

-- ---------- Katman 3: TRIGGER ----------
-- stock_quantity'ye yalnızca apply_inventory_movement() yazabilir.
-- Mekanizma: ledger trigger'ı transaction-local bir bayrak açar, cache'i
-- günceller, bayrağı hemen kapatır. Guard trigger'ı bayrak kapalıyken
-- gelen her stock_quantity değişimini reddeder.
--
-- Not: bu koruma GRANT'ten bağımsız çalışır; service_role ve gelecekte
-- yazılacak SECURITY DEFINER fonksiyonlar da bu kapıdan geçmek zorundadır.

-- SECURITY DEFINER ZORUNLU: bu trigger, authenticated rolünün artık UPDATE
-- yetkisi OLMAYAN stock_quantity kolonuna yazar. Önceden fonksiyon çağıran
-- rolle çalışıyor ve authenticated'ın genel UPDATE grant'ine yaslanıyordu;
-- o grant kaldırıldığı için trigger'ın kendisi "permission denied" alırdı.
-- Artık tablo sahibi yetkisiyle çalışır: cache'e yazabilen TEK yol budur.
-- set search_path = '': arama yolu zehirlenmesine karşı (tüm nesneler
-- şema-nitelikli yazılmıştır).
create or replace function public.apply_inventory_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Guard trigger'ına "bu yazma ledger kaynaklıdır" sinyali. true =
  -- transaction-local; commit/rollback ile kendiliğinden temizlenir.
  perform set_config('suretakip.ledger_write', 'on', true);

  update public.products
     set stock_quantity = stock_quantity + new.quantity_delta
   where id = new.product_id
     and track_stock = true;

  -- Pencereyi hemen kapat: aynı transaction'daki sonraki ifadeler
  -- bayraktan faydalanamasın.
  perform set_config('suretakip.ledger_write', 'off', true);
  return new;
end;
$$;

create function public.guard_product_stock_write()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    -- Ürün her zaman sıfır stokla doğar; ilk stok 'initial' ledger
    -- hareketiyle gelir. create_product_with_stock zaten böyle çalışır.
    if coalesce(new.stock_quantity, 0) <> 0 then
      raise exception 'stock_quantity_direct_write_denied'
        using hint = 'Urun sifir stokla olusur; ilk stok inventory_movements '
                     '''initial'' hareketiyle girilir (create_product_with_stock).';
    end if;
    return new;
  end if;

  if new.stock_quantity is distinct from old.stock_quantity
     and coalesce(current_setting('suretakip.ledger_write', true), 'off') <> 'on' then
    raise exception 'stock_quantity_direct_write_denied'
      using hint = 'stock_quantity yalnizca inventory_movements ledger '
                   'trigger''i tarafindan degistirilebilir.';
  end if;

  return new;
end;
$$;

create trigger trg_guard_product_stock_write
  before insert or update on public.products
  for each row execute function public.guard_product_stock_write();

-- ---------- track_stock değişiminin tanımlı davranışı ----------
-- track_stock, "satışta stok düşülsün/kontrol edilsin mi" anahtarıdır;
-- stok verisini SİLMEZ veya SIFIRLAMAZ. Tanım:
--
--   false -> true : Ledger ve cache olduğu gibi korunur. track_stock=false
--                   iken apply_inventory_movement() cache'i güncellemediği
--                   için cache tipik olarak 0'dır; owner/admin 'restock'
--                   veya 'manual_adjustment' hareketiyle gerçek sayımı
--                   girer. Cache doğrudan yazılamaz (Katman 3).
--
--   true -> false : Cache son değerinde DONDURULUR, ledger geçmişi silinmez
--                   (append-only, denetim izi korunur). Sonraki satışlar
--                   stok düşmez ve stok kontrolüne takılmaz.
--
--   false -> true (geri dönüş): Dondurulmuş cache değerinden devam edilir.
--                   Aradaki takipsiz satışlar cache'e yansımadığı için
--                   owner/admin'in 'manual_adjustment' ile sayım yapması
--                   beklenir — bu bilinçli bir operasyonel karardır,
--                   sessiz bir düzeltme değil.
--
-- Kural: her iki yönde de stock_quantity'ye DOĞRUDAN yazılmaz.

comment on function public.guard_product_stock_write() is
  'products.stock_quantity yazmalarini inventory_movements ledger trigger''i '
  'ile sinirlar. Ledger (kaynak) ile cache''in ayrismasini imkansiz kilar.';
