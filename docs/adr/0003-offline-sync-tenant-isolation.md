# ADR 0003 — Offline sync: tenant/account izolasyonu ve veri kaybı önleme

- **Durum:** Kabul edildi ve uygulandı (testli)
- **Tarih:** 2026-07-22
- **Bağlam:** Offline-first Sprint 1/2 sonrası güvenlik/mimari review (Claude
  rolü). İlgili kod: `lib/core/sync/*`, `lib/features/customers/data/*`.

## Bağlam

Offline müşteri (Sprint 1) ve delta/bootstrap (Sprint 2) uygulandıktan sonra
yapılan kritik review, çok kiracılı (multi-business) ve ortak-cihaz (multi-user)
senaryolarında üç ciddi açık ortaya çıkardı. Bu ADR alınan kararları kaydeder.

## Karar 1 — Snapshot/delta non-ok yanıtı asla merge/tombstone yapmaz (CRITICAL)

`get_customers_snapshot` `FORBIDDEN`/`auth_required` döndürdüğünde istemci bunu
"boş snapshot" sanıp merge ederse, kontrollü merge'ün "snapshot'ta olmayan temiz
kayıtları tombstone et" adımı **tüm yerel synced müşterileri siler** (veri kaybı).

**Karar:** RPC yanıt zarfı (`{result: ok|auth_required|rejected}`) istemci
tarafında modellenir (`CustomerSnapshotPage.ok/authRequired/rejected`). `ok`
değilse bootstrap merge/tombstone YAPMADAN döner; generation korunur, oturum/
bağlantı düzelince aynı tur devam eder.

## Karar 2 — Delta cursor/generation/staging business-scoped'tur (HIGH)

Global cursor anahtarları (`customers_changes_cursor`), aktif işletme değişince
yanlış cursor'la delta uygulanmasına ve tenant karışmasına yol açar.

**Karar:** Tüm sync_state anahtarları `:$businessId` ile ayrılır. `_inFlight`
tek future değil, iş-başına map'tir (bir işletmenin turu diğerini bloklamaz ya
da onun sonucunu döndürmez).

## Karar 3 — Outbox claim account-scoped'tur; logout worker'ı durdurur (HIGH)

Ortak cihazda kullanıcı A'nın bekleyen outbox kayıtları, B giriş yaptığında
B'nin oturumuyla gönderilmemelidir (yanlış aktör, audit sahteciliği riski).

**Karar:** `claimReady(actorUserId, businessId)` yalnız
`original_actor_user_id == currentUserId` ve aktif işletmenin kayıtlarını claim
eder. Aktör `null` ise (oturum kapalı) hiçbir kayıt claim edilmez → worker fiilen
durur, veri korunur. A tekrar giriş yaptığında kaldığı yerden gönderilir. Nihai
yetki kararı yine sunucu RPC'sinin `auth.uid()` kontrolündedir.

## Karar 4 — Server upsert tombstone alanlarını temizler (MEDIUM)

Silinip sunucuda yeniden oluşturulan bir müşteri, yerelde `is_deleted=true`
kalırsa görünmez. `upsertServerCustomers` artık `is_deleted=false`,
`deleted_at=null` yazar.

## Karar 5 — İlk veri çekimi provider construction yan etkisi değildir (MEDIUM)

Legacy "full pull" provider oluşturulurken tetiklenmez. Kanonik bootstrap/delta
yalnız `SyncTriggerService` üzerinden açılış/foreground/bağlantı tetikleriyle,
tek-worker garantisiyle çalışır.

## Sonuçlar

- Dirty (bekleyen/çatışmalı) yerel kayıtlar snapshot/delta tarafından hiçbir
  koşulda ezilmez veya silinmez.
- Çapraz kullanıcı / çapraz işletme gönderim ve veri karışması engellenir.
- Regresyon testleri: `test/core/sync/customer_delta_sync_test.dart` (snapshot
  non-ok veri kaybı, tenant izolasyonu) ve
  `test/core/sync/offline_customer_sync_test.dart` (account izolasyonu).

## Kapsam dışı (sonraki fazlar)

Yerel DB şifrelemesi (Faz D), cihaz kaydı/revoke (Faz E), permission snapshot
ve PIN (Faz F), conflict/review UI (Faz G2) ayrı ADR/fazlarda ele alınır.
