# SüreTakip

Dakika bazlı işletme takip ve ücret hesaplama uygulaması. Zaman bazlı hizmetleri
canlı sayaçla ücretlendirir, işleme ürün ekler ve tutarı atomik olarak kapatır.

**Stack:** Flutter (Material 3) · Riverpod · GoRouter · Supabase (Postgres + RLS)

## Gereksinimler

- Flutter SDK (Dart `^3.10.4`)
- Supabase CLI + Docker (yerel veritabanı ve migration'lar için)

## Ortam yapılandırması (Supabase anahtarları)

Uygulama, Supabase bağlantı bilgilerini **derleme zamanında** `--dart-define`
ile alır; env dosyaları uygulama içine asset olarak paketlenmez. Staging ve
production birbirinden ayrı Supabase projeleri kullanmalıdır.

1. Her ortam için örnek dosyayı kopyalayın:
   ```bash
   cp .env.example .env.staging
   cp .env.example .env.production
   ```
2. Dosyaları yalnızca ait oldukları Supabase projesinin değerleriyle doldurun:
   ```
   SUPABASE_URL=https://<proje-ref>.supabase.co
   SUPABASE_ANON_KEY=<anon-key>
   ```

`.env`, `.env.staging`, `.env.production` ve diğer `.env.*` dosyaları git
tarafından yok sayılır; yalnızca güvenli placeholder içeren `.env.example`
repoya girer. Ortam dosyalarına service-role anahtarı veya başka sunucu sırrı
yazmayın.

## Çalıştırma

Bağımlılıkları bir kez alın:

```bash
flutter pub get
```

Staging:

```bash
flutter run --dart-define-from-file=.env.staging
flutter build appbundle --release --dart-define-from-file=.env.staging
```

Production:

```bash
flutter run --release --dart-define-from-file=.env.production
flutter build appbundle --release --dart-define-from-file=.env.production
```

`flutter build ipa` ile iOS paketi üretilecekse aynı komutlara ilgili
`--dart-define-from-file` argümanı eklenir; imzalama ayarları önce tamamlanmış
olmalıdır.

> `--dart-define-from-file` verilmezse uygulama başlangıçta anlaşılır bir hata
> (`SUPABASE_URL ve SUPABASE_ANON_KEY tanımlı değil`) ile durur.

### Yerel Supabase + Android emülatörü

Android emülatöründe `localhost` / `127.0.0.1` **emülatörün kendisini** işaret
eder; host makine `10.0.2.2` üzerinden erişilir. Yerel Supabase'e bağlanacaksanız
ayrı bir env dosyası kullanın:

```bash
sed 's|127\.0\.0\.1|10.0.2.2|' .env > .env.android
flutter run --dart-define-from-file=.env.android
```

iOS simulator host ağını paylaştığı için bu değişiklik gerekmez; aynı `.env`
iOS'ta çalışır, Android emülatöründe çalışmaz. (`.env.*` gitignore kapsamındadır.)

### Android SDK / JDK notu

Gradle, JDK 25 ile `What went wrong: 25` hatası verir. JDK 17 gerekir:

```bash
brew install openjdk@17
flutter config --jdk-dir /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
```

## Veritabanı (Supabase yerel)

```bash
supabase start                 # yerel Postgres + Studio (Docker gerekli)
supabase db reset              # migration'ları sıfırdan uygular
```

RLS senaryo testleri:

```bash
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2-)" -f supabase/tests/rls_test.sql
```

Şema ve güvenlik `supabase/migrations/` altında; RLS senaryo testleri
`supabase/tests/rls_test.sql` içinde (rollback ile temiz biter).

## Kalite kontrolleri

```bash
flutter analyze     # sıfır uyarı
flutter test        # hepsi yeşil
```

## Proje yapısı

```
lib/
  app/          MaterialApp, router, tema, global provider'lar
  core/         sabitler, servisler (Supabase init), ortak yardımcılar
  features/     alan bazlı modüller (auth, dashboard, ...)
supabase/
  migrations/   şema + RLS
  tests/        RLS senaryo testleri
docs/           mimari, faz planı, gözlemlenebilirlik ve yayın belgeleri
```

## Yol haritası

Fazlı plan ve mevcut durum için
[`docs/implementation-roadmap.md`](docs/implementation-roadmap.md) dosyasına
bakın.

## Kalite kapıları (CI)

`.github/workflows/ci.yml` her PR ve `main` push'unda şunları zorunlu kılar:

- `dart format --set-exit-if-changed` (biçim)
- `flutter analyze --fatal-infos` (statik analiz)
- `flutter test --coverage` + **kapsam alt sınırı** (`MIN_COVERAGE`, şu an %52)
- `supabase db reset` (tüm migration'lar temiz uygulanır)
- **`supabase/tests/rls_test.sql`** — tenant izolasyonu, rol matrisi, seans
  durum makinesi, stok ledger'ı, onboarding atomikliği ve rapor aggregate'leri

> Kapsam kapısı bir *ratchet*'tir: hedef **%80**. Kapsam arttıkça
> `MIN_COVERAGE` yükseltilmelidir (bugün: %56,7).

## Yayın öncesi (Faz 8)

Tek sayfalık süreç için
[`docs/release-checklist.md`](docs/release-checklist.md) dosyasını kullanın.

- [ ] **Android release imzalama** — `android/app/build.gradle.kts` hâlâ debug
      key ile imzalıyor. **Yayın engelleyicisi**: bu haliyle Play Store'a çıkılamaz.
- [ ] Test kapsamını %80'e çıkar (açık: data katmanının kalanı, ekran testleri)
- [ ] Rol farkındalıklı UI (staff'a owner/admin aksiyonları gösterilmemeli)
- [ ] Şifre sıfırlama deep link (`redirectTo` + app link) ve yeni şifre ekranı
- [ ] Uygulama ikonları ve splash
- [ ] Store metaverileri
