# Menü Sayaç - Genel Mimari

Bu doküman, projeyi iki veya daha fazla geliştirici ile tutarlı şekilde ilerletmek için temel mimari kararları ve çalışma kurallarını tanımlar.

## 1) Mimari Yaklaşım

Proje, **feature-first** ve **clean architecture** prensipleri ile ilerler.

- Feature-first: Kod, teknik katman yerine iş alanlarına göre bölünür.
- Clean architecture: Her feature içinde data, domain, presentation ayrımı korunur.
- Bağımlılık yönü: `presentation -> domain -> data`.
- UI içinde business logic yazılmaz.
- Supabase sorguları doğrudan UI içinde yapılmaz; repository üzerinden yapılır.

## 2) Hedef Teknoloji Seti

- Flutter (Material 3)
- Dart null safety
- Riverpod
- GoRouter
- Supabase (Auth + Realtime + PostgreSQL)
- Freezed + json_serializable
- uuid
- intl
- flutter_dotenv

## 3) Klasör Yapısı

```text
lib/
  app/
    app.dart
    router/
    theme/
    providers/
  core/
    constants/
    errors/
    extensions/
    utils/
    services/
    widgets/
  features/
    auth/
      data/
      domain/
      presentation/
    businesses/
      data/
      domain/
      presentation/
    customers/
      data/
      domain/
      presentation/
    services/
      data/
      domain/
      presentation/
    products/
      data/
      domain/
      presentation/
    sessions/
      data/
      domain/
      presentation/
    reports/
      data/
      domain/
      presentation/
  main.dart
```

Feature içinde önerilen alt yapı:

```text
data/
  datasources/
  repositories/
  models/

domain/
  entities/
  repositories/
  usecases/

presentation/
  controllers/
  providers/
  pages/
  widgets/
```

## 4) Katman Sorumlulukları

### 4.1 Presentation

- Sayfalar, widgetlar, form validasyonları, kullanıcı etkileşimi.
- Riverpod controller/provider ile ekran state yönetimi.
- Sadece domain/usecase çağırır.

### 4.2 Domain

- Entity, value object, business kuralı ve usecase.
- Framework bağımsız olmalı.
- Fiyat/süre hesaplama gibi kritik kurallar burada tutulur.

### 4.3 Data

- Supabase datasource implementasyonları.
- DTO/model ve mapping işlemleri.
- Repository interface implementasyonları.

## 5) Uygulama Çekirdeği (app/ ve core/)

### app/

- `app.dart`: MaterialApp.router, tema, router bağlama.
- `router/`: Route isimleri, guard, yönlendirme.
- `providers/`: Uygulama seviyesinde provider tanımları.
- `theme/`: Açık/koyu tema ve ortak stil kararları.

### core/

- `constants/`: Sabit anahtarlar, app-level default değerler.
- `errors/`: Domain exception türleri ve hata mapleme.
- `services/`: Supabase init, tarih/para servisleri gibi altyapı servisleri.
- `utils/`: Saf utility fonksiyonları.
- `widgets/`: Feature bağımsız ortak UI bileşenleri.

## 6) Router ve Guard Stratejisi

- Tüm path ve route name değerleri merkezi dosyada tutulur.
- Auth guard kuralları:
  - Giriş yoksa login'e yönlendir.
  - Giriş var ama business yoksa onboarding'e yönlendir.
  - Giriş + business varsa dashboard'a yönlendir.

## 7) State Yönetimi (Riverpod)

Provider katmanları:

- App-level provider: Supabase client, auth state, current user.
- Feature-level provider: liste/detail/query providerları.
- Controller provider: mutate işlemleri (ekle, güncelle, tamamla).

Kural:

- Async işlemler `AsyncValue` ile yönetilir.
- Loading, error, data durumları ekranlarda açıkça ele alınır.

## 8) Modelleme Kuralları

- Domain entity ve modelde immutable yaklaşım.
- Freezed + json_serializable standartları uygulanır.
- ID tipleri UUID.
- Fiyat alanları PostgreSQL tarafında `numeric(12,2)`.
- Dart tarafında para hesapları merkezi utility/value object ile yapılır.

## 9) İş Kuralı Yerleşimi

- Süre ve ücret hesaplama logic'i UI'da bulunmaz.
- Bu logic, domain içinde test edilebilir servis olarak tutulur:
  - `SessionPriceCalculator`
- Snapshot mantığı (service/product fiyatının işlem anında sabitlenmesi) data + domain tarafından zorunlu kılınır.

## 10) Supabase ve SQL Sınırları

- Tablolar: businesses, business_members, customers, services, products, sessions, session_items.
- RLS tüm tablolarda aktif.
- Yetki kontrolü business üyeliği üzerinden yapılır.
- Kritik tamamla işlemleri (stok düşümü + toplam kaydı) atomik şekilde RPC/transaction ile yapılır.

## 11) Kodlama Standartları

- `lib/` içi importlarda package import kullanılır.
- Küçük ve sorumluluğu net widgetlar tercih edilir.
- Aynı business logic birden fazla yerde tekrarlanmaz.
- UI dosyaları sadece render + user interaction içermelidir.
- Lint ihlali bırakılmaz (`flutter analyze` temiz olmalı).

## 12) Test Stratejisi (İlk Plan)

- Unit test önceliği: süre/ücret hesaplama ve snapshot kuralları.
- Widget test: login, servis formu, ürün formu, aktif işlem ekranı.
- Repository test: Supabase katmanı mock ile doğrulanır.

## 13) Ekip Çalışma Akışı

### Branch stratejisi

- `main`: her zaman stabil.
- `feature/<alan>-<kisa-aciklama>` formatı kullanılır.

Örnek:

- `feature/auth-register-flow`
- `feature/services-crud`
- `feature/session-price-calculator`

### PR kontrol listesi

Her PR için minimum gereksinim:

1. `flutter analyze` temiz.
2. İlgili testler çalışır durumda.
3. Yeni logic için en az 1 test eklenmiş.
4. UI'da business logic yok.
5. Route, provider ve repository katman ayrımı korunmuş.

## 14) Sonraki Adım Planı

Bu dokümandan sonra ekip olarak şu sırayla ilerlenir:

1. Supabase migration + RLS dosyaları
2. Domain entity/model ve repository kontratları
3. Services CRUD
4. Products CRUD
5. Customers CRUD
6. Sessions başlat/duraklat/tamamla akışı
7. History + Reports sorguları
8. Genişletilmiş test paketi

---

Not: Bu doküman yaşayan bir dokümandır. Yeni kararlar alındığında güncellenmelidir.
