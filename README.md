# SüreTakip

Dakika bazlı işletme takip ve ücret hesaplama uygulaması. Zaman bazlı hizmetleri
canlı sayaçla ücretlendirir, işleme ürün ekler ve tutarı atomik olarak kapatır.

**Stack:** Flutter (Material 3) · Riverpod · GoRouter · Supabase (Postgres + RLS)

## Gereksinimler

- Flutter SDK (Dart `^3.10.4`)
- Supabase CLI + Docker (yerel veritabanı ve migration'lar için)

## Yapılandırma (Supabase anahtarları)

Uygulama, Supabase bağlantı bilgilerini **derleme zamanında** `--dart-define`
ile alır; `.env` artık uygulama içine asset olarak paketlenmez.

1. Örnek dosyayı kopyalayın:
   ```bash
   cp .env.example .env
   ```
2. `.env` içini kendi Supabase projenizin değerleriyle doldurun:
   ```
   SUPABASE_URL=https://<proje-ref>.supabase.co
   SUPABASE_ANON_KEY=<anon-key>
   ```

`.env` git tarafından yok sayılır (`.gitignore`); anahtarlar repoya girmez.

## Çalıştırma

```bash
flutter pub get
flutter run --dart-define-from-file=.env
```

> `--dart-define-from-file` verilmezse uygulama başlangıçta anlaşılır bir hata
> (`SUPABASE_URL ve SUPABASE_ANON_KEY tanımlı değil`) ile durur.

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
docs/           mimari, faz planı, uygulama yol haritası
```

## Yol haritası

Fazlı plan ve mevcut durum için `docs/implementation-roadmap.md` ve kök
dizindeki `PLAN.md` dosyalarına bakın.

## Yayın öncesi (Faz 8)

- [ ] Android release imzalama (`android/app/build.gradle.kts` hâlâ debug key ile imzalıyor)
- [ ] Uygulama ikonları ve splash
- [ ] Store metaverileri
