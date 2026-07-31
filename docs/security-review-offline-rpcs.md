# Güvenlik İncelemesi — Offline Supabase RPC'leri

- **İnceleyen:** Claude (RLS/RPC güvenlik rolü)
- **Tarih:** 2026-07-22
- **Kapsam:** `create_customer`, `sync_start_session`, `sync_session_event`,
  `get_changes`, `get_customers_snapshot`, `record_customer_sync_change` trigger,
  `sync_changes`/`sync_processed_operations`/`security_events` tabloları.

## Doğrulanan güvenlik özellikleri (geçti)

- **SECURITY DEFINER sertleştirme:** Tüm fonksiyonlar `set search_path = ''`
  ve şema-nitelikli (`public.`/`pg_catalog.`/`extensions.`) nesne kullanır.
- **Execute grant matrisi:** İç tablolar (`sync_changes`, `sync_processed_
  operations`, `security_events`) ve trigger fonksiyonu `public/anon/
  authenticated`'tan revoke; RPC'ler yalnız `authenticated`'a grant, `public/
  anon`'dan revoke. pgTAP testleriyle doğrulandı.
- **Tenant kontrolü:** Her RPC `auth.uid()` null → `auth_required`, ardından
  `is_business_member(p_business_id)` (aktiflik kontrollü) → değilse `FORBIDDEN`.
  Kullanıcı yalnız üyesi olduğu işletmenin verisini çeker; `p_business_id`'ye
  körlemesine güvenilmez.
- **Idempotency:** Normalize payload hash SUNUCUDA (SHA-256) hesaplanır; aynı
  key'e eşzamanlı istekler `pg_advisory_xact_lock` ile serileştirilir; aynı
  key + farklı hash → `IDEMPOTENCY_PAYLOAD_MISMATCH`.
- **Injection:** Tüm sorgular parametreli; dinamik SQL yok.
- **Version disiplini:** `server_version` yalnız `BEFORE UPDATE` trigger'ıyla
  artar; AFTER feed trigger'ı artmış version'ı görür.
- **Tenant-agnostik conflict:** `CUSTOMER_ID_CONFLICT`/`SESSION_ID_CONFLICT`
  varlık üzerinden cross-tenant bilgi sızdırmaz; `security_events` alarmı üretir.

## Bulgular

| # | Sınıf | Bulgu | Durum |
|---|---|---|---|
| F-F | MEDIUM | `get_changes`/`get_customers_snapshot` `p_limit` üst sınırsızdı; istemci dev limitle kendi tenant'ında DoS oluşturabilirdi | ✅ Kapatıldı: `least(..., 1000)` tavanı; yeniden uygulandı, delta testi 8/8 |
| F-A | LOW/MEDIUM | `sync_changes` payload'ı `phone/email/notes` PII kopyası taşıyor (v3 §7.3.2 hassas alanların feed'de ikinci kopyasını önermez) | ⏳ Öneri (aşağı) |

### F-A ayrıntı ve öneri

`sync_changes` sunucu-özeldir (istemci grant'i yok) ve yalnız membership-kontrollü
`get_changes` ile okunur; yani PII, `customers` ile aynı erişim sınırındadır. Risk
**duplikasyon ve retention**tır, cross-tenant sızıntı değil. Öneriler:

- Change feed retention'ı sınırla (desteklenen en uzun offline süreden kısa
  olmamak kaydıyla) ve horizon temizliği ekle (`CURSOR_TOO_OLD` zaten hazır).
- En hassas alan olan `notes`'u feed payload'ından çıkarmayı değerlendir; istemci
  gerekiyorsa güncel satırı yetkili RPC ile ayrıca çeker.

Bu, ürün/retention kararı gerektirir ve bir release blocker değildir.

## Sonuç

Offline RPC katmanında **açık CRITICAL/HIGH güvenlik bulgusu yoktur.** Tek MEDIUM
(limit tavanı) kapatıldı. F-A retention/veri-minimizasyonu önerisi olarak açık;
Faz D (yerel şifreleme) ve retention politikası ile birlikte ele alınmalıdır.
