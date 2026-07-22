# SüreTakip Offline-First Sözleşmesi

> Durum: Sprint 1 + Sprint 2 + Faz C tamam, güvenlik sertleştirmesi (tenant/
> account izolasyonu) tamam, yerel şifreleme (Faz D) tamam · Açık CRITICAL/HIGH
> bulgu yok · Son doğrulama: 22 Temmuz 2026  
> Bu dosya, `SureTakip_Offline_Mimari_v3.md` planını mevcut repo gerçekliğiyle
> uzlaştıran kanonik uygulama sözleşmesidir. Kod ile bu dosya çelişirse
> önce sözleşme karara bağlanır, sonra iki taraf birlikte değiştirilir.

## 1. Bugün gerçekte olanlar

- Online business/member/customer/service/product/session/payment altyapısı,
  RLS ve RPC'ler mevcuttur.
- **Offline müşteri (Sprint 1) uçtan uca çalışır ve UI'ya bağlıdır:** liste
  Drift stream'inden okunur, yeni müşteri local+outbox tek transaction'da
  oluşturulur, idempotent `create_customer` RPC'siyle push edilir, listede
  sync durum rozeti gösterilir; online→Drift mini-bootstrap pull dirty-aware'dir.
- **Offline seans (Faz C) UI'ya bağlıdır:** start/pause/resume local+outbox
  event'leri, `depends_on` sıralı, restart-safe; süre zaman damgasından
  hesaplanır (kapanıp açılınca donmaz). Complete/cancel/add-product hâlâ online.
- **Delta pull + bootstrap (Sprint 2) uygulandı ve testlidir:** `sync_changes`
  feed + customers trigger, `get_changes` ve `get_customers_snapshot` RPC'leri
  (keyset), staging/generation tablosu, snapshot-öncesi cursor yakalama,
  dirty-aware kontrollü merge ve `CURSOR_TOO_OLD` full resync.
- **Tenant/account izolasyonu sertleştirildi:** delta cursor/generation/staging
  business-scoped; outbox claim yalnız oturumdaki kullanıcının kendi işletmesi
  içindir (logout → hiçbir kayıt gönderilmez); snapshot non-ok yanıtı merge/
  tombstone YAPMAZ (veri kaybı önlenir).
- Bağlantı/yaşam-döngüsü tetikleyicisi (`SyncTriggerService`) açılış/foreground/
  bağlantı-dönüşünde push+delta çalıştırır (tek-worker garantili). `sync_conflicts`
  Drift tablosu mevcuttur.
- **Yerel DB şifreleme (Faz D) tamamlandı:** Drift/SQLite SQLCipher ile şifreli;
  DB anahtarı secure storage'da (Keystore/Keychain, `first_unlock_this_device`),
  kodda sabit değil, loglanmıyor. Android `allowBackup=false` + `FLAG_SECURE`,
  iOS file protection eklendi. Plaintext→şifreli dev geçişi dirty olmayan DB'yi
  güvenle yeniden oluşturur. 5 güvenlik testi + tam süit yeşil.
- Yerel PIN, cihaz kaydı, permission snapshot ve review kuyruğu henüz yoktur
  (Faz E/F/G2).
- Mevcut rol enum'u `owner | admin | staff`'tır. `manager`, `cashier` ve
  `playground_staff` rol değil; ileride permission anahtarları olabilir.
- Mevcut şemada `branches` yoktur. `branch_id` alanı ürün kararı + migration
  olmadan local veya remote sözleşmeye eklenmez.

## 2. Değişmez ilkeler

1. İlk cihaz/hesap doğrulaması internet olmadan yapılamaz.
2. UI mutation için doğrudan Supabase'e gitmez; repository önce local DB'ye yazar.
3. Domain kaydı ile outbox kaydı aynı Drift transaction'inda commit edilir.
4. Her mutation kararlı bir `operation_id` ve `idempotency_key` taşır.
5. Ağ/auth hatası pending veriyi silmez veya otomatik logout üretmez.
6. Yetki istemci snapshot'ıyla sınırlanabilir; nihai karar RLS/RPC'dedir.
7. Service-role anahtarı, cihaz hesabı parolası, PIN, pepper ve DB anahtarı
   uygulama loguna veya istemci paketine girmez.
8. Finans ve stok ledger'ları append-only'dir. Genel soft-delete kuralı bu
   tablolara uygulanmaz; düzeltme ters kayıtla yapılır.

## 3. Fazlar ve kapılar

| Faz | Durum | Çıkış kapısı |
|---|---|---|
| A — Online tenant/domain temeli | ✅ Tamamlandı | RLS/RPC ve Flutter testleri yeşil |
| B — Offline customer push | ✅ Tamamlandı | Liste Drift'ten, idempotent tek kayıt, UI'ya bağlı |
| C — Offline session event'leri | ✅ Tamamlandı | Start/pause/resume sıralı, restart-safe, UI'ya bağlı |
| G1 — Delta pull + bootstrap | ✅ Tamamlandı | Keyset snapshot + cursor + full resync, dirty-aware, testli |
| Güvenlik — Tenant/account izolasyonu | ✅ Tamamlandı | Scoped cursor + actor-scoped claim + snapshot non-ok abort |
| D — Yerel güvenlik kapısı (şifreleme) | ✅ Tamamlandı | SQLCipher + secure key store + FLAG_SECURE + iOS file protection; testli (262 test) |
| E — Cihaz kimliği | ⏳ Bekliyor | Register/verify/revoke + owner token'ını kaldırma |
| F — Çoklu personel/yetki + PIN | ⏳ Bekliyor | Aktör membership + permission/emergency snapshot |
| G2 — Conflict/review kuyruğu | ⏳ Bekliyor | `sync_conflicts` UI + kabul/red akışı |
| H — Offline finans/stok | ⏳ Bekliyor | Ledger ve concurrency testleri |

Offline ekranlar son kullanıcıya "güvenli" diye açılmadan önce Faz D (şifreleme)
tamamlanmalıdır. Delta/bootstrap ve tenant izolasyonu bu doğrulamadan geçmiştir.

## 4. Outbox v1 — mevcut kod sözleşmesi

Mevcut alanlar:

```text
id, operation_id, business_id, original_actor_user_id,
submitted_by_user_id?, device_id,
aggregate_type, aggregate_id, operation_type,
sequence_number, depends_on_operation_id?,
payload_json, payload_version, idempotency_key,
expected_server_version?, status, priority, attempt_count,
next_attempt_at?, last_attempt_at?, processing_token?,
last_error_code?, last_error_message?,
created_at, synced_at?
```

Durumlar:

```text
localOnly | pending | processing | retrying | synced | conflicted | rejected
```

Kurallar:

- `processing` bir terminal durum değildir. Beş dakikalık lease'i aşan kayıt
  `PROCESSING_LEASE_EXPIRED` koduyla `pending` yapılır ve aynı idempotency
  anahtarıyla yeniden gönderilir.
- Claim, uygun durum kontrolüyle atomik yapılır. Her claim benzersiz bir
  `processing_token` taşır; eski worker bu token değiştikten sonra terminal
  veya retry sonucu yazamaz.
- Engine dispatch'ten hemen önce tek operasyon claim eder; auth nedeniyle erken
  çıkış, gönderilmemiş başka operasyonları `processing` durumunda bırakmaz.
- Taze `processing` lease'ine dokunulmaz.
- Bağımlı operasyon, ebeveyn `synced` olmadan gönderilmez.
- Bağımlılık uygunluğu `LIMIT` uygulanmadan önce sorguda filtrelenir;
  bloklu bir operasyon arkadaki bağımsız operasyonları aç bırakamaz.
- **Account izolasyonu:** `claimReady` yalnız oturumdaki kullanıcının
  (`original_actor_user_id == currentUserId`) ve aktif işletmenin kayıtlarını
  claim eder. Oturum kapalıysa (aktör `null`) HİÇBİR kayıt claim edilmez →
  worker fiilen durur, veri korunur. Ortak cihazda A'nın bekleyen kaydı B'nin
  oturumunda gönderilmez; A tekrar girince gönderilir.
- Ebeveyn `rejected/conflicted` olursa çocuğun nasıl sonlandırılacağı Faz G2
  öncesi ayrı test ve hata koduyla tanımlanacaktır.

## 5. Outbox v2 — cihaz/personel fazında eklenecekler

Faz E/F migration'ında, tek seferde ve geriye uyumlu olarak:

```text
actor_business_member_id (required)
original_actor_user_id (nullable)
authorization_snapshot_version
authorization_review_required (status)
```

`branch_id` yalnız şube modeli kabul edilirse eklenir. Mobil payload, backend RPC
imzası kesinleşmeden bu alanları tahmin ederek göndermez.

## 6. Kimlik, PIN ve süre modeli

- Faz D: tek owner'ın mevcut Supabase session'ı geçici olarak kullanılır.
- Faz E: ortak cihazda owner token'ı yerine düşük yetkili cihaz hesabına
  geçilir. Provisioning bir Edge Function/sunucu akışıdır ve yarım kurulum
  için idempotent retry/cleanup sözleşmesi olmadan yayına alınmaz.
- PIN cihaz-yerel ve 6 hanelidir. Aynı cihazda benzersiz olması zorunlu değildir;
  kullanıcı önce profilini seçer. Zayıf desenler reddedilir.
- PIN salt'ı Argon2 API'sine ayrı salt parametresi olarak verilir; byte encoding
  ve pepper birleştirme biçimi test vektörüyle sabitlenmeden kodlanmaz.
- PIN kilidi reboot ile atlatılamaz: monotonik sayaç yanında reboot epoch ve
  güvenli duvar/sunucu çapası tutulur; belirsizlikte online doğrulama istenir.
- Kalıcı cihaz durumu `active | suspended | revoked` olur. `offline`,
  `offlineEligible` ve `expired`, timestamp + bağlantıdan türetilen durumlardır.
- Permission snapshot iki ayrı liste taşır:

```json
{
  "permissions": ["session.read", "session.create"],
  "emergency_permissions": ["session.read", "session.complete_existing"],
  "verified_at": "server timestamp",
  "expires_at": "verified_at + 24h",
  "emergency_expires_at": "verified_at + 72h",
  "version": 1
}
```

Snapshot HMAC'i sunucu imzası değil, cihaz-yerel bütünlük MAC'idir; root +
anahtar çıkarımına karşı güven sınırı sayılmaz.

## 7. Revoke ve review kararı

Revoked cihaz hesabı normal domain RPC'si çağıramaz. Bu nedenle "push yapma"
ile "otomatik review'a gönder" aynı anda varsayılmaz:

- cihaz pending veriyi localde korur ve yeni mutation üretmez;
- kurtarma, aktif owner/admin yeniden kimlik doğrulamasından sonra ayrı, kısıtlı
  recovery endpoint'i ile yapılır;
- recovery endpoint payload hash, idempotency, güncel domain invariant'ı,
  approver yetkisi ve tekil onay kilidini transaction içinde tekrar doğrular.

## 8. Platform güvenliği

- Android backup kapsamı local DB ve anahtarları dışlar.
- `FLAG_SECURE` manifest ayarı değil, hassas ekran açılırken window/runtime
  flag'idir; iOS için ayrı uygulama yaşam döngüsü koruması gerekir.
- SQLCipher anahtarı ile `device_master_key` ayrı rastgele anahtarlardır.
- Keychain/Keystore kaybında pending şifreli DB'nin kurtarılamayabileceği
  kullanıcıya açıkça bildirilir; sık sync bu riskin ana azaltımıdır.
- 72 saat sonrası sınırsız hassas okuma yoktur; PII maskeleme/cache TTL
  ürün kararı Faz D'de verilmelidir.

## 9. Bir sonraki uygulama sırası

Tamamlananlar: outbox crash/lease + dependency terminal davranışı testli;
offline customer/session + delta SQL ve Flutter testleri CI'da; delta/bootstrap
+ tenant/account izolasyonu uygulandı ve testli.

Kalan sıra:

1. **(Uygulanıyor)** SQLCipher + secure storage adaptörü + FLAG_SECURE + iOS
   file protection; yerel DB migration kurtarma/backup prosedürü.
2. Argon2 test vektörü, zayıf PIN ve kilit/reboot testleri (Faz F).
3. Cihaz kaydı (register/verify/revoke) ve permission snapshot (Faz E/F).
4. `sync_conflicts` review UI + kabul/red akışı (Faz G2).
5. Offline-aware router ve tek owner PIN ekranını aç.
6. Gerçek Android/iOS kill/restart/uçak modu kabulünü tamamla.

## 10. Minimum kabul

- `flutter analyze` temiz; tüm Flutter testleri yeşil (mevcut: 258 test).
- Offline SQL paketi gerçek Postgres'te yeşil (create_customer 8 + session 8 +
  delta 8 = 24 pgTAP testi).
- Aynı operasyon tekrarda tek server kaydı üretir.
- RPC öncesi kapanan uygulamadaki stale `processing` kaydı yeniden gönderilir.
- Auth/ağ hatası pending kaydı silmez.
- Uygulama kill/restart sonrası local customer/session ve outbox korunur.
- **Snapshot/delta hiçbir non-ok yanıtta yerel önbelleği silmez.**
- **Delta cursor ve outbox claim tenant/account-scoped'tur; ortak cihazda
  çapraz kullanıcı gönderimi olmaz.**
- Faz D (şifreleme) tamamlanmadan offline mod son kullanıcıya "güvenli" diye
  sunulmaz.

## 11. Delta pull ve bootstrap sözleşmesi (uygulandı)

RPC'ler (tümü membership kontrollü, yalnız `authenticated` execute, sonuç
zarfı `{result: ok|auth_required|rejected}`):

```text
get_changes(p_business_id, p_cursor bigint, p_limit)
  → { result:'ok', changes:[{change_seq, entity_type, entity_id,
        operation:'upsert'|'delete', server_version, payload}],
      next_cursor, has_more, server_time }
  → { result:'rejected', error_code:'CURSOR_TOO_OLD' }  // istemci full resync
  → { result:'rejected', error_code:'FORBIDDEN' } / { result:'auth_required' }

get_customers_snapshot(p_business_id, p_after_id uuid?, p_limit)
  → { result:'ok', customers:[...], next_after_id, has_more, server_cursor }
  → FORBIDDEN / auth_required (istemci merge/tombstone YAPMAZ)
```

İstemci kuralları:

- Cursor `change_seq` (bigint); yalnız `change_seq > cursor` işlenir.
- `has_more=true` iken tam sayfa gelse bile pagination sürer.
- Bootstrap: keyset (id ASC, OFFSET yok); `server_cursor` İLK sayfadan yakalanır
  (snapshot-öncesi cursor) ve sonraki sayfalarla ezilmez.
- Snapshot staging'e yazılır, sonra kontrollü merge: temiz kopyalar upsert,
  dirty (bekleyen) kayıtlar korunur, snapshot'ta olmayan TEMİZ kayıtlar
  tombstone (dirty'ye dokunulmaz), staging silinir, cursor tek transaction'da
  ilerletilir.
- `CURSOR_TOO_OLD` → bekleyen outbox ve dirty working copy silinmeden full resync.
- Cursor/generation/snapshot-cursor anahtarları `:$businessId` ile scoped'tur.
