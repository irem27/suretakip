-- =============================================================
-- SüreTakip - Migration 9: Eski onboarding RPC'sinin kaldırılması (P0-2)
--
-- SORUN: create_business_with_owner (20260717130100_rls.sql) authenticated
-- kullanıcılara açıktı. Bu fonksiyon işletme + owner üyeliği yaratır ama
-- ZORUNLU İLK HİZMETİ yaratmaz. Kullanıcı uygulamanın onboarding ekranını
-- atlayıp bu RPC'yi doğrudan çağırarak "hizmetsiz işletme" üretebiliyordu.
-- Hizmetsiz işletmede start_session imkansızdır; kullanıcı açılışta kilitli
-- bir hesapla kalır ve destek müdahalesi gerekir.
--
-- complete_onboarding (20260717130300) aynı işi TEK transaction'da, zorunlu
-- ilk hizmetle birlikte yapar ve uygulamanın kullandığı yol zaten budur.
-- Yani eski fonksiyon yalnızca bir bypass yüzeyidir; karşılığında hiçbir
-- ürün akışı sağlamaz.
--
-- ÇÖZÜM: yetkiyi geri al ve fonksiyonu düşür. Fonksiyonun tamamen
-- kaldırılması, yalnız REVOKE'a göre daha güçlüdür: ileride biri yanlışlıkla
-- grant verse bile çağrılacak bir fonksiyon kalmaz.
--
-- KULLANIM DOĞRULAMASI (bu migration yazılmadan önce yapıldı):
--   grep -rn "create_business_with_owner" lib test supabase docs README.md
--   -> Uygulama kodunda (lib/) HİÇ kullanım yok; BusinessesRemoteDataSource
--      zaten AppConstants.completeOnboardingRpc çağırıyor.
--   -> Tek kullanım supabase/tests/rls_test.sql kurulumundaydı; aynı commit
--      içinde complete_onboarding'e taşındı.
-- =============================================================

revoke execute on function public.create_business_with_owner(text, text, text)
  from authenticated, public, anon;

drop function if exists public.create_business_with_owner(text, text, text);

-- Onboarding'in tek kapısı complete_onboarding'dir. Garantileri:
--   * businesses + business_members(owner) + services satırları tek
--     transaction'da yazılır; herhangi biri patlarsa hepsi rollback olur
--     ("işletme var ama hizmeti yok" veya "işletme var ama sahibi yok"
--     durumları oluşamaz),
--   * p_service_name boş ise service_name_required ile reddedilir —
--     yani hizmet ADIMI ATLANAMAZ,
--   * businesses tablosuna doğrudan INSERT grant'i hiç verilmemiştir, bu
--     yüzden RPC'siz işletme yaratmanın başka yolu yoktur.
comment on function public.complete_onboarding(
  text, text, text, text, bigint, integer, integer, boolean, text, bigint
) is
  'Onboarding''in TEK giris noktasi. Isletme + owner uyeligi + zorunlu ilk '
  'hizmet (+ opsiyonel ilk urun) tek transaction. Eski create_business_with_owner '
  'RPC''si 20260718090100 ile kaldirildi: hizmetsiz isletme uretebiliyordu.';
