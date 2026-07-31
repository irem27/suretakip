# Çevrimdışı (Offline) E2E Testleri

Uygulamanın **çevrimdışı çalışması** kritik gereksinimdir: internet olmadan da
tüm fonksiyonlar cihaza kaydeder, bağlantı gelince otomatik senkronize eder.

## Kapsam (offline-first)

| Alan | create | update | setActive/terminal |
|------|:---:|:---:|:---:|
| Müşteri (customers) | ✅ | ✅ | ✅ |
| Seans (sessions) | ✅ start/pause/resume | — | ✅ complete/cancel/addProduct |
| Ürün (products) | ✅ | ✅ | ✅ |
| Hizmet (services) | ✅ | ✅ | ✅ |
| Ödeme (payments) | offline kuyruk (idempotent) | — | — |

Okuma (katalog/liste) da çevrimdışı çalışır: giriş/dashboard'da `OfflineBootstrap`
üyelik + hizmet + ürün kataloğunu yerele **ısıtır** (`lib/core/sync/offline_bootstrap.dart`).
Böylece kullanıcı sonra çevrimdışı kalsa da seans başlatabilir (hizmet + üyelik
yerelde hazırdır).

## Senaryolar

1. **Soğuk offline** (`01-cold-offline.yaml`) — hiç internet yokken önbellekten aç,
   işlem yap.
2. **Kullanım sırasında kesinti** (`02b-offline-add.yaml`) — online başla, internet
   kesil, işlem devam etsin.
3. **Offline düzenleme** (`03b-edit-offline.yaml`) — çevrimdışı müşteri pasife al.
4. **Offline seans** (`04-offline-session.yaml`) — çevrimdışı seans başlat + tamamla.

Her senaryoda bağlantı geri gelince veri sunucuya **otomatik** senkronize olur
(`SyncTriggerService` + `_runFullSync`).

## Çalıştırma

```bash
export SUPABASE_SERVICE_ROLE_KEY=<lokal service_role key>   # supabase status
bash .maestro/offline/run-offline-suite.sh
```

Runner, gerçek bağlantı kesmesi için `adb shell svc wifi/data disable` kullanır —
bu hem uygulamanın sunucu erişimini keser hem de `connectivity_plus`'a sinyal
verir (iptables port bloğu connectivity olayı üretmediğinden kullanılmaz).

## Notlar

- Senkronizasyon SIRALIDIR: bir işlemin outbox op'u, bağımlı olduğu işleme
  (`dependsOnOperationId`) bağlanır; ör. seans TAMAMLAMA, seans BAŞLATMA sunucuya
  gitmeden denenmez. Böylece "seans yok" çakışması oluşmaz.
- Çift-yazımı idempotency defteri (`sync_processed_operations`) engeller.
- iOS: offline MANTIK platformdan bağımsız paylaşılan Dart kodudur (Drift + sync).
  Simülatör host ağını paylaştığından per-app kesme sınırlıdır; gerçek cihazda
  `connectivity_plus` beklendiği gibi çalışır.
