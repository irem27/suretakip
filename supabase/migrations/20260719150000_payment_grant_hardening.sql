-- =============================================================
-- SüreTakip - Ödeme tablolarında yetki sıkılaştırması
--
-- BULGU (2026-07-19 güvenlik incelemesi):
-- Supabase'in varsayılan bootstrap'ı `authenticated` rolüne şemadaki TÜM
-- tablolarda TRUNCATE, TRIGGER ve REFERENCES yetkisi bırakıyor. Biz yalnızca
-- SELECT verdik ama bu varsayılanlar üstte duruyor.
--
-- Neden önemli:
--   * TRUNCATE, RLS'i TAMAMEN ATLAR. Politika filtresi uygulanmaz; tek komutla
--     tüm işletmelerin ödeme kayıtları silinebilir. Bu, modülün "hiçbir ödeme
--     kaydı fiziksel olarak silinmez" garantisini doğrudan çürütür.
--   * TRIGGER, tabloya trigger takmaya izin verir — yetki yükseltme vektörü.
--   * REFERENCES, tabloya FK kurmaya izin verir; varlık çıkarımına yarayabilir.
--
-- Bugünkü sömürülebilirlik: PostgREST bir TRUNCATE uç noktası sunmadığı için
-- mobil istemci bunu doğrudan çağıramaz. Yani bu bir "gizli/derinlemesine
-- savunma" açığıdır, aktif olarak sömürülen bir delik değil. Yine de ödeme
-- verisinde kabul edilemez: garantiyi GRANT seviyesinde kapatıyoruz.
--
-- KAPSAM NOTU: Aynı varsayılanlar sessions, session_items, products,
-- inventory_movements ve businesses tablolarında da duruyor. Onlar bu işin
-- kapsamı dışında olduğu için burada DEĞİŞTİRİLMEDİ; ayrı bir sıkılaştırma
-- işi olarak raporlandı. Önerilen düzeltme aynı desendir.
-- =============================================================

revoke truncate, trigger, references
  on public.payments, public.payment_allocations, public.payment_events
  from authenticated;

-- anon'a zaten hiçbir yetki verilmedi; varsayılan bir kalıntı varsa o da kapansın.
revoke all
  on public.payments, public.payment_allocations, public.payment_events
  from anon;

-- Meşru okuma yolu korunur.
grant select
  on public.payments, public.payment_allocations, public.payment_events
  to authenticated;
