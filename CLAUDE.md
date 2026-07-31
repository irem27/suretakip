# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proje

SüreTakip — dakika bazlı işletme takip ve ücret hesaplama uygulaması. Zaman bazlı hizmetleri canlı sayaçla ücretlendirir, işleme ürün ekler, tutarı atomik olarak kapatır. **Offline-first**: yerel Drift (SQLCipher) veritabanı + outbox tabanlı senkron, sunucu Supabase (Postgres + RLS/RPC).

Stack: Flutter (Material 3) · Riverpod · GoRouter · Drift · Supabase.

## Komutlar

Supabase bağlantısı **derleme zamanında** `--dart-define-from-file` ile gelir; env asset olarak paketlenmez. Bu argüman olmadan uygulama başlangıçta hata verip durur.

```bash
flutter pub get

# Çalıştır / derle (env dosyası zorunlu)
flutter run --dart-define-from-file=.env.staging
flutter build appbundle --release --dart-define-from-file=.env.production

# Kod üretimi (Drift tabloları, Freezed, json_serializable)
dart run build_runner build --delete-conflicting-outputs

# Kalite kapıları — CI ile birebir aynı (aşağıya bak)
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage

# Tek test dosyası / tek test
flutter test test/core/sync/sync_engine_test.dart
flutter test --plain-name 'idempotency anahtarı'

# Supabase (yerel Postgres + RLS/RPC — Docker gerekli)
supabase start
supabase db reset          # tüm migration'ları sıfırdan uygular
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2-)" -f supabase/tests/rls_test.sql
```

Android emülatöründe yerel Supabase için `127.0.0.1` yerine `10.0.2.2` gerekir (README'ye bak). Gradle JDK 17 ister (JDK 25 → `What went wrong: 25`).

## CI kapıları (`.github/workflows/ci.yml`)

Her PR ve `main` push'unda zorunlu — **yerelde çalıştırmadan push etme**:
`dart format --set-exit-if-changed` · `flutter analyze --fatal-infos` (sıfır uyarı, info dahil) · `flutter test --coverage` + kapsam alt sınırı (`MIN_COVERAGE`, şu an %65) · `supabase db reset` · `supabase/tests/rls_test.sql` (51 senaryo). Ayrı Android + iOS build doğrulama job'ları var.

Kapsam kapısı bir **ratchet**: hedef %80. Kapsam artınca `MIN_COVERAGE` yükseltilmeli.

## Mimari

### Katmanlar
- `lib/app/` — `MaterialApp`, router, tema, global provider grafiği (`app/providers/`).
- `lib/core/` — çapraz kesen altyapı: `database/` (Drift), `sync/` (offline motoru), `auth/`, `security/`, `services/` (Supabase init), `value_objects/`, `errors/`, `logging/`.
- `lib/features/<domain>/` — alan modülleri (auth, businesses, customers, dashboard, definitions, history, payments, products, reports, services, sessions). Her biri kendi `data/` + `presentation/` (pages, controllers) katmanına sahip; feature-first bölünme.

### Offline-first senkron (en kritik alan — `lib/core/sync/`)
Yazma işlemleri önce yerel Drift DB'ye yazılır ve **outbox**'a (`sync_outbox_table`) kuyruklanır. `SyncEngine` tek worker ile kuyruğu işler; her kayıt **idempotency anahtarıyla** ilgili RPC'ye (`create_customer`, session/product/service/payment sync RPC'leri) gönderilir. Çift-tahsilat/çift-yazma bu idempotency + sunucu tarafı korumayla engellenir. RPC istemcileri tembel (lazy factory) inşa edilir — ilgili operasyon türü dispatch'te görülmezse provider grafiği hiç kurulmaz.

`sync_trigger_service` senkronu lifecycle/connectivity/explicit tetikler; `offline_bootstrap` çevrimdışına geçmeden önce yerel cache'i ısıtır (uygulama warm olmadan offline'a geçilirse veri boş görünür — bilinen tuzak). `sync_error_classifier` uzak-yazma/self-escalation gibi hataları sınıflandırır; `retry_policy` backoff yönetir.

### Sunucu (`supabase/`)
Şema + güvenlik `migrations/` altında; iş mantığı RPC'lerde (session state machine, stok ledger'ı, onboarding atomikliği, üyelik yönetimi). Tenant izolasyonu RLS ile; senaryolar `tests/rls_test.sql` içinde rollback ile temiz biter. İstemci tarafı yazmalar doğrudan tabloya değil bu RPC'lere gider.

### Router
`GoRouter` **yalnızca bir kez** oluşturulur. Auth/işletme durumu değişince router yeniden yaratılmaz; `refreshListenable` tetiklenip `redirect` yeniden değerlendirilir.

## Konvansiyonlar

- Lint (`analysis_options.yaml`) zorunlu kılar: `always_use_package_imports` (göreli import yasak — `package:suretakip/...` kullan), `avoid_dynamic_calls`, `prefer_const_constructors`, `prefer_final_locals`, `prefer_single_quotes`, `sort_child_properties_last`. `--fatal-infos` yüzünden info-seviye uyarı bile CI'ı düşürür (örn. `unnecessary_underscores`: kullanılmayan callback parametreleri için `(_, __)` değil `(_, _)`).
- Drift tablosu / Freezed model değiştirince `build_runner` çalıştır; üretilen `.g.dart` / `.freezed.dart` dosyalarını elle düzenleme.
- Yeni sync operasyonu eklerken: outbox operasyon türü + RPC istemcisi + `SyncEngine` dispatch kaydı + idempotency anahtarı birlikte gider.
