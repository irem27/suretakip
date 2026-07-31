# SüreTakip — İnceleme Sonrası Uygulama Yol Haritası

> **Tarihsel belge:** Bu dosya 16 Temmuz 2026'daki erken iskelet durumunu
> kaydeder; "henüz yok" listeleri bugünün repo durumunu temsil etmez. Güncel
> mimari için [`architecture.md`](architecture.md), offline uygulama ve faz durumu
> için [`offline-first-contract.md`](offline-first-contract.md) kullanılmalıdır.

> Hazırlanma tarihi: 16 Temmuz 2026  
> İncelenen dal/commit: `main` / `f725ab6`  
> Kaynaklar: `docs/architecture.md`, `docs/project-phases.md`, mevcut Flutter kodu ve Stitch tasarım çıktıları

## 1. Yönetici özeti

Proje doğru teknoloji seçimleri ve iyi bir mimari niyetle başlatılmış, ancak şu anda **çalışan ürün değil, erken aşama bir Flutter iskeletidir**.

Mevcut olanlar:

- Flutter, Material 3, Riverpod, GoRouter ve Supabase başlangıç kurulumu
- Merkezi tema ve route sabitleri
- E-posta/şifre ile giriş yapan geçici login ekranı
- Çıkış işlemi ve sabit veriler gösteren dashboard
- Mimari ve faz planı belgeleri
- 13 adet Stitch ekran çıktısı ve bir tasarım sistemi belgesi

Henüz olmayan ana parçalar:

- Supabase migration, tablo, constraint, index, RLS ve RPC'ler
- İşletme/üyelik modeli ve rol bazlı yetkilendirme
- Domain entity, value object, use case ve repository katmanları
- Register, şifre sıfırlama ve onboarding
- Hizmet, ürün ve müşteri CRUD akışları
- Süreli işlem motoru, fiyat hesaplama, ürün ekleme ve atomik tamamlama
- Geçmiş, raporlar ve gerçek dashboard verileri
- Anlamlı unit/widget/repository/RLS test paketi
- CI/CD ve release hazırlığı

Önerilen sıra: önce mevcut iskeleti tekrar üretilebilir hale getir, sonra güvenli veri ve domain temelini kur, ardından dikey ürün akışlarını teslim et. Session motoruna, RLS ve fiyat kuralları testlerle sabitlenmeden başlanmamalıdır.

## 2. İncelemede bulunan mevcut durum

### 2.1 Kod ve mimari

| Alan | Mevcut durum | Yapılacak |
|---|---|---|
| Uygulama başlangıcı | `.env` yükleniyor, Supabase başlatılıyor, `ProviderScope` açılıyor | Test edilebilir environment/bootstrap ayrımı |
| Router | Yalnızca `/login` ve `/dashboard`; sadece auth kontrolü var | Business/onboarding guard ve feature route'ları |
| Auth | Login gerçek; Supabase doğrudan UI'dan çağrılıyor | Data/domain/repository/controller katmanlarına taşıma |
| Dashboard | Metrikler sabit `0`; yeni işlem butonu boş | Repository verisi, loading/error/data durumları |
| Veri katmanı | Yok | Supabase datasource ve repository implementasyonları |
| Domain katmanı | Yok | Entity, value object, use case ve iş kuralları |
| Supabase | Sadece client init var | Local proje, migration, RLS, RPC, testler |
| Testler | Tek login render testi | Unit, widget, repository, RLS ve akış testleri |

### 2.2 Doğrudan düzeltilmesi gereken başlangıç sorunları

1. `pubspec.yaml` içinde `.env` zorunlu asset, fakat temiz klonda yalnızca `.env.example` var.
   - `flutter analyze`: `asset_does_not_exist`
   - `flutter test`: asset bundle oluşturulamıyor
   - Bu nedenle `docs/project-phases.md` içindeki “Faz 0 tamamlandı” çıkış kriteri bugün tekrar üretilemiyor.
2. `test/widget_test.dart` yalnızca login metinlerinin render edildiğini kontrol ediyor; auth davranışı, provider state'i ve hata durumları test edilmiyor. Geçici bir kopyada `.env` eklendiğinde bu testin geçtiği doğrulandı.
3. Login ve logout, kabul edilen mimariye aykırı biçimde presentation katmanından doğrudan Supabase'e gidiyor.
4. Android ana manifestinde release için `INTERNET` izni yok; izin sadece debug/profile manifestlerinde bulunuyor.
5. Android application ID, uygulama etiketi ve release signing hâlâ Flutter varsayılanı (`com.example.menusayac`, debug signing).
6. Proje adı kodda “Menü Sayaç/menusayac”, tasarımlarda ve ürün tanımında “SüreTakip”. İsim tekilleştirilmeli.
7. README hâlâ varsayılan Flutter metni; kurulum, environment, Supabase ve geliştirme akışı anlatılmıyor.
8. Design system ile mevcut Flutter teması farklı renk ve radius değerleri kullanıyor. Tek kaynak seçilmeli.

## 3. Kodlamadan önce kapanacak ürün kararları

Bu kararlar Faz 1 migration'ı yazılmadan kısa bir ADR veya `docs/product-decisions.md` içinde kesinleştirilmelidir.

### 3.1 Rol/yetki matrisi

Önerilen başlangıç matrisi:

| Yetki | Owner | Manager | Employee |
|---|---:|---:|---:|
| İşletme ayarları | Tam | Görüntüle | Hayır |
| Üye davet/rol/pasifleştirme | Tam | Karara bağlı | Hayır |
| Hizmet/ürün/müşteri yönetimi | Tam | Tam | Görüntüle veya sınırlı |
| İşlem başlat/duraklat/tamamla | Tam | Tam | Tam |
| Fiyat veya tamamlanan işlem düzeltme | Tam | Karara bağlı | Hayır |
| Rapor ve gelir görüntüleme | Tam | Tam | Karara bağlı |
| İşletme silme/devretme | Tam | Hayır | Hayır |

Karar: manager üye yönetebilecek mi; employee mali raporları ve alış/satış fiyatlarını görebilecek mi?

### 3.2 İşlem ve ücret kuralları

- `exact`, `floor`, `ceil` tam olarak hangi saniye/dakika formülüyle çalışacak?
- Minimum ücret veya minimum dakika var mı?
- Bir müşteri veya çalışan için aynı anda birden fazla aktif işlem olabilir mi?
- Bir işlem iptal edilebilir mi; iptal edilen ürünler stoğa döner mi?
- Tamamlanmış işlem düzenlenebilir/iade edilebilir mi; kim yapabilir?
- Cihaz saati yerine sunucu zamanı hangi noktalarda zorunlu olacak?

### 3.3 Stok ve finans kuralları

- Yetersiz stokta tamamlama reddedilecek mi? Öneri: **evet, transaction fail closed**.
- Stoksuz satış/negatif stok izni var mı?
- Para yalnızca tek işletme para biriminde mi tutulacak?
- Dart tarafında kayan noktalı sayı kullanılmayacak; küçük para birimi integer veya doğrulanmış Money value object seçilecek.
- Gün/hafta/ay rapor sınırları işletmenin `timezone` alanına göre hesaplanacak.

### 3.4 Eksik ürün kapsamı kararları

- Çok kullanıcılı hedef için davet kabulü, üyeyi pasifleştirme ve işletme değiştirme akışı eklenecek.
- Tasarımda hizmet kategorileri var; mevcut yedi tablo planında kategori tablosu yok. Ayrı `service_categories` tablosu mu, hizmet üzerinde basit alan mı kullanılacağı kararlaştırılacak.
- Denetlenebilirlik için üye/rol değişikliği, işlem tamamlama/iptal ve stok düzeltmelerinin audit kaydı kapsamı belirlenecek.

## 4. Hedef klasör ve sorumluluk haritası

```text
lib/
  app/
    app.dart
    router/                 # merkezi route ve guard'lar
    theme/                  # DESIGN.md ile uyumlu tema/tokenlar
    providers/              # app-level client/auth/business bağlamı
  core/
    errors/                 # typed exception/failure ve hata mapleme
    extensions/
    services/               # bootstrap, clock, locale gibi altyapı
    utils/                  # saf yardımcılar; business logic değil
    widgets/                # feature bağımsız ortak UI
  features/
    auth/
    businesses/             # onboarding, üyeler, işletme seçimi
    services/
    products/
    customers/
    sessions/
    reports/
      data/
        datasources/
        models/
        repositories/
      domain/
        entities/
        repositories/
        usecases/
      presentation/
        controllers/
        providers/
        pages/
        widgets/
supabase/
  migrations/               # şema, RLS, RPC, view/index
  tests/                    # yetki ve kritik SQL davranış testleri
test/
  core/
  features/                 # source yapısını aynalayan testler
```

Temel sınırlar:

- UI yalnızca render ve kullanıcı etkileşimi yapar.
- UI, Supabase client'ını doğrudan çağırmaz.
- Presentation controller → domain use case → repository → datasource akışı korunur.
- Para, süre, snapshot ve yetki kuralları domain/DB katmanında test edilir.
- Tenant güvenliğinin son sözü uygulama filtresi değil RLS'dir.

## 5. Faz bazlı uygulama planı

### Faz 0A — İskeleti tekrar üretilebilir hale getir

Amaç: Temiz klonda kurulum, analiz ve testlerin güvenilir çalışması.

Yapılacaklar:

- [ ] Ürün adını kesinleştir; package/bundle ID değiştirme etkilerini dokümante et.
- [ ] `.env` asset stratejisini düzelt:
  - test/build'i gizli yerel dosyanın varlığına bağımlı bırakma,
  - `.env.example` içinde yalnızca placeholder tut,
  - bootstrap config'i testte override edilebilir yap.
- [ ] Login widget testini `ProviderScope`/override edilen providerlarla izole et.
- [ ] Android ana manifestine gerekli ağ iznini ekle.
- [ ] `com.example.*`, uygulama etiketleri ve debug release signing borcunu kayda al; gerçek kimlikleri release fazında tamamla.
- [ ] README'yi gerçek kurulum komutları, environment anahtarları, mimari ve tasarım yolu ile güncelle.
- [ ] `s_retakip_design_system/DESIGN.md` değerlerini Flutter theme/tokenlarına eşle; mevcut teal tema mı navy/coral tasarım mı kaynak olacak kararlaştır.
- [ ] En az format/analyze/test çalıştıran temel PR CI workflow'unu ekle; test borcunu Faz 8'e erteleme.
- [ ] En az Android emülatör ve iOS simülatörde app shell smoke test yap.

Doküman/kod referansları:

- `docs/architecture.md` — app/core sınırları ve kod standartları
- `docs/project-phases.md` — Faz 0 çıkış kriterleri ve zorunlu komutlar
- `lib/main.dart`, `lib/core/services/supabase_initializer.dart`
- `test/widget_test.dart`, `pubspec.yaml`, `.env.example`
- `../s_retakip_design_system/DESIGN.md`

Çıkış kriteri:

- [ ] Temiz klonda belgelenmiş tek kurulum akışı çalışır.
- [ ] `flutter analyze` sıfır uyarı/hata.
- [ ] `flutter test` başarılı.
- [ ] Uygulama geçerli config ile açılır; eksik config anlaşılır hata verir.

Kaçınılacaklar:

- Gerçek Supabase anahtarını Git'e eklemek
- Testleri gerçek uzak Supabase projesine bağlamak
- `.env` bulunmadığında anlamsız asset-bundle hatası üretmek

### Faz 1 — Supabase şeması, tenant izolasyonu ve RLS

Amaç: Bütün feature'ların dayanacağı güvenli veri temelini kurmak.

Yapılacaklar:

- [ ] Supabase CLI/local geliştirme akışını kur; `supabase/migrations` oluştur.
- [ ] Önce şema sözlüğü ve ER kararlarını yaz; sonra migration üret.
- [ ] Çekirdek tabloları oluştur:
  - `businesses`
  - `business_members`
  - `customers`
  - `services`
  - `products`
  - `sessions`
  - `session_items`
- [ ] Karara göre `service_categories`, invitation, pause history ve audit yapısını ekle.
- [ ] UUID PK, FK, unique ve check constraint'leri ekle.
- [ ] Çapraz işletme referanslarını yalnızca tekil UUID FK'lere bırakma; `(id, business_id)` unique + composite FK veya eşdeğer transaction doğrulamasıyla session/customer/service/product bağlarının aynı tenant'a ait olmasını zorunlu kıl.
- [ ] Parayı `numeric(12,2)`, tarihleri timezone-aware, rolleri/status'leri sınırlı değerler olarak tanımla.
- [ ] `business_id`, status, aktiflik, tarih ve rapor filtrelerine uygun index'leri ekle.
- [ ] `updated_at` trigger'ı ekle.
- [ ] Her tenant tablosunda RLS'yi aç; non-member erişimini varsayılan olarak reddet.
- [ ] Policy'lerde güvenli üyelik helper'ı kullan; recursion ve yetki yükseltme riskini test et. `security definer` gerekiyorsa sabit/güvenli `search_path`, schema-qualified nesneler ve en az yetki ilkesi uygula.
- [ ] Owner/manager/employee için SELECT/INSERT/UPDATE/pasifleştirme truth table testlerini yaz.
- [ ] Kullanıcının kendi rolünü owner'a yükseltemediğini ve son owner'ın silinemediğini doğrula.
- [ ] Session tamamlama RPC kontratını, idempotency ve stok kilitleme yaklaşımını bu fazda sabitle; implementasyon Faz 6'da.

Çıkış kriteri:

- [ ] `supabase db reset` temiz çalışır.
- [ ] `supabase db lint` temizdir.
- [ ] Her tablo RLS korumasındadır.
- [ ] Business A üyesi Business B verisini okuyamaz/değiştiremez.
- [ ] Rol matrisi SQL testleriyle kanıtlanır.
- [ ] Migration geri alınabilirlik/ileri düzeltme yaklaşımı belgelenmiştir.

Kaçınılacaklar:

- Sadece client-side `business_id` filtresine güvenmek
- Policy içinde istemeden recursive `business_members` sorgusu
- Service role key'i mobil uygulamaya koymak
- Para alanında float kullanmak

### Faz 2 — Domain çekirdeği ve repository kontratları

Amaç: UI ve Supabase'den bağımsız, test edilebilir iş kuralları oluşturmak.

Yapılacaklar:

- [ ] `Business`, `BusinessMember`, `Customer`, `Service`, `Product`, `Session`, `SessionItem` entity'lerini oluştur.
- [ ] Domain entity ile Supabase DTO/model ayrımını koru.
- [ ] Freezed/json_serializable üretim akışını kur ve generated file politikasını kararlaştır.
- [ ] `Money`, süre ve rounding value object'lerini oluştur.
- [ ] `SessionPriceCalculator` API'sini kararlarla birlikte sabitle.
- [ ] Repository interface'lerini domain altında oluştur.
- [ ] Auth, validation, authorization, network, database ve unknown failure hiyerarşisini kur.
- [ ] Bir `Clock` soyutlaması ekleyerek süre testlerini cihaz saatinden bağımsızlaştır.
- [ ] Kullanım senaryolarını tek amaçlı use case'lere ayır.

Öncelikli test matrisi:

- [ ] exact/floor/ceil sınırları
- [ ] 0 saniye, 59/60/61 saniye ve uzun süreler
- [ ] birden fazla pause ve açık pause
- [ ] minimum ücret/dakika kararı
- [ ] ürün quantity ve snapshot toplamı
- [ ] para yuvarlama ve büyük değerler
- [ ] tamamlanmış işlemde güncel katalog fiyatının geçmiş toplamı değiştirmemesi

Çıkış kriteri:

- [ ] Domain Supabase/Flutter UI bağımlılığı olmadan test edilebilir.
- [ ] Kritik fiyat/süre testlerinin tamamı geçer.
- [ ] Tüm feature'lar için repository kontratı nettir.

### Faz 3 — Auth, işletme onboarding ve üyelik

Amaç: Kullanıcıyı güvenli biçimde doğru işletme bağlamına sokmak.

Yapılacaklar:

- [ ] Mevcut login çağrısını auth datasource/repository/controller katmanlarına taşı.
- [ ] Register, forgot password ve session restore akışlarını ekle.
- [ ] Supabase hata metinlerini kullanıcıya doğrudan göstermek yerine Türkçe hata mapleme uygula.
- [ ] Router durum makinesini kur:
  - session yok → login
  - session var, business yok → onboarding
  - session + seçili business var → dashboard
- [ ] Onboarding: işletme adı, para birimi, timezone, ilk hizmet ve opsiyonel ilk ürün.
- [ ] Business + owner membership oluşturmayı atomik/idempotent sunucu işlemi yap.
- [ ] Davet, davet kabulü, üye listesi, rol değiştirme ve pasifleştirme akışlarını rol matrisine göre ekle.
- [ ] Birden fazla işletmesi olan kullanıcı için işletme seçimi/değiştirme davranışını belirle.

Tasarım referansları:

- `../giri_yap/code.html`
- `../s_retakip_a_l_ekran/code.html`
- Register/forgot/onboarding için yeni tasarım gerekir; `DESIGN.md` dili korunur.

Çıkış kriteri:

- [ ] Auth ve onboarding happy/error/loading durumları testlidir.
- [ ] Kullanıcı yetkisi olmayan route'a giremez.
- [ ] Owner üyeliği yarım kalmış işletme kaydı üretmez.

### Faz 4 — Hizmet yönetimi

Amaç: İlk tamamlanmış dikey CRUD dilimini teslim etmek.

Yapılacaklar:

- [ ] Service datasource, repository, use case, provider ve controller'larını ekle.
- [ ] Liste, detay, ekle, düzenle ve aktif/pasif akışlarını tamamla.
- [ ] Ad, dakika ücreti, rounding ve minimum ücret kararlarını validate et.
- [ ] Kategori kararı uygulanacaksa kategori yönetimini aynı tenant/RLS kurallarıyla ekle.
- [ ] Listeyi business bağlamı ve aktiflik filtresiyle sorgula.
- [ ] Silme yerine pasifleştirme uygula; geçmiş snapshot'ları koru.

Tasarım referansları:

- `../hizmetler_listesi/code.html`
- `../yeni_hizmet_ekle/code.html`
- `../hizmet_detay/code.html`
- `../hizmet_kategorileri/code.html`

Çıkış kriteri:

- [ ] Owner/manager CRUD yapabilir; employee davranışı rol matrisiyle uyumludur.
- [ ] Loading/empty/error/data durumları görünürdür.
- [ ] Repository ve widget testleri geçer.

### Faz 5 — Ürün ve müşteri yönetimi

Amaç: Session öncesi kalan katalog ve müşteri temelini tamamlamak.

Products:

- [ ] Liste, arama, ekle, düzenle ve aktif/pasif akışları
- [ ] Fiyat > 0, stok >= 0 validasyonları
- [ ] `track_stock` kapalı/açık davranışı
- [ ] Yetkili stok düzeltme işlemi ve gerekiyorsa audit kaydı

Customers:

- [ ] Liste, arama, ekle ve düzenle akışları
- [ ] Ad zorunluluğu, telefon/e-posta normalizasyonu ve validasyonu
- [ ] Misafir işlem için `customer_id = null` yaklaşımı; yapay “Misafir” kayıt çoğaltmama
- [ ] Arama alanları için uygun index ve debounce

Tasarım referansları:

- `../r_nler/code.html`
- `../m_teriler/code.html`
- `../tan_mlar_men_s/code.html`

Çıkış kriteri:

- [ ] Ürün ve müşteri akışları tenant izolasyonuyla uçtan uca çalışır.
- [ ] Negatif stok ve geçersiz fiyat DB constraint + domain validasyonuyla engellenir.

### Faz 6 — Session motoru

Amaç: Uygulamanın temel değerini, dayanıklı ve atomik süreli işlem akışı olarak teslim etmek.

Alt dilimler:

1. İşlem başlat
   - müşteri veya misafir seçimi
   - hizmet seçimi
   - service adı/fiyatı/rounding/minimum alanlarının snapshot'ı
   - server timestamp ve işlemi başlatan üye
2. Aktif sayaç
   - persisted timestamp'lerden hesaplanan süre; her tick'i DB'ye yazmama
   - uygulama kapanıp açıldığında doğru devam
   - canlı hizmet, ürün ve genel toplam
3. Pause/resume
   - ardışık ve tekrarlı pause'larda idempotent davranış
   - farklı cihaz/üye yarış koşullarında version/status kontrolü
4. Ürün ekleme
   - ürün fiyat/ad snapshot'ı
   - aynı ürün için quantity artırma
   - aktif/pasif ve stok uygunluk kontrolü
5. Atomik tamamlama
   - tek RPC/transaction
   - status ve version precondition
   - client'tan gelen `business_id`, zaman ve toplam değerlerine güvenmeme
   - stored snapshot'lardan server-side zaman/toplam üretimi veya doğrulaması
   - session ve ürün satırlarında `FOR UPDATE` veya eşdeğer güvenli stok kilidi
   - yetersiz stokta hiçbir kısmi değişiklik bırakmadan hata
   - `ended_at`, `charged_minutes`, üç toplam ve tamamlayan üye kaydı
   - aynı isteğin tekrarında çift stok düşmeme

Tasarım referansları:

- `../yeni_i_lem_ba_lat/code.html`
- `../hizmet_se_imi_alt_paneli/code.html`
- `../i_lem_detay_aktif/code.html`
- `../i_lemi_tamamla/code.html`
- `../ana_sayfa/code.html`

Zorunlu testler:

- [ ] App restart / session restore
- [ ] Birden fazla pause/resume
- [ ] Aynı session'ı eşzamanlı iki kez tamamlama
- [ ] Aynı son stok ürününü iki session'ın eşzamanlı tamamlama denemesi
- [ ] Snapshot fiyatlarının katalog değişiminden etkilenmemesi
- [ ] Yetkisiz üyenin session mutate edememesi
- [ ] Ağ hatası sonrası retry'nin çift yazım/çift stok düşümü yapmaması

Çıkış kriteri:

- [ ] Session toplamı Dart domain ve DB doğrulamasında aynı sonucu verir.
- [ ] Tamamlama tamamen atomik ve idempotenttir.
- [ ] Uygulama kapanması sayaç doğruluğunu bozmaz.

### Faz 7 — Dashboard, geçmiş ve raporlar

Amaç: Operasyon ve finans görünürlüğünü gerçek verilerle sağlamak.

Yapılacaklar:

- [ ] Dashboard'daki sabit metrikleri repository/provider verisine bağla.
- [ ] Aktif işlemler ve son tamamlananlar listesi.
- [ ] Geçmiş: tarih, müşteri, hizmet, durum ve çalışan filtreleri.
- [ ] İşlem detayında snapshot hizmet/ürün satırları ve audit bilgisi.
- [ ] İşletme timezone'una göre günlük/haftalık/aylık sınırları tanımla.
- [ ] Rapor view/RPC'leri:
  - toplam gelir
  - hizmet/ürün geliri
  - en çok kullanılan hizmetler
  - en çok satılan ürünler
  - en çok harcayan müşteriler
- [ ] Büyük listelerde server-side filtreleme, pagination ve index kullan.
- [ ] Owner/manager/employee rapor görünürlüğünü rol matrisiyle uygula.

Tasarım:

- Dashboard için `../ana_sayfa/code.html` referans alınır.
- Geçmiş ve rapor detay ekranları tasarım paketinde yok; implementasyondan önce wireframe/onay gerekir.

Çıkış kriteri:

- [ ] Dashboard ve rapor toplamları aynı fixture veri setinde birebir eşleşir.
- [ ] DST/timezone sınır testleri geçer.
- [ ] Filtreli sorgular kabul edilebilir veri hacminde ölçülür.

### Faz 8 — Stabilizasyon, güvenlik ve release hazırlığı

Amaç: Test edilmiş, gözlemlenebilir ve yayınlanabilir sürüm adayı üretmek.

Yapılacaklar:

- [ ] Unit/widget/repository/RLS/integration test matrisindeki açıkları kapat.
- [ ] GitHub Actions: format, analyze, test ve migration lint/reset kontrolleri.
- [ ] Tüm loading/empty/error/offline durumlarını ve Türkçe metinleri gözden geçir.
- [ ] Telefon/tablet, küçük ekran, büyük font ve dark mode kontrolleri.
- [ ] Erişilebilirlik: 48px touch target, kontrast, semantic label ve klavye/focus.
- [ ] Log/crash reporting seçimi; loglarda token, e-posta ve kişisel veri maskeleme.
- [ ] Supabase staging/production ayrımı, secret yönetimi, backup/restore ve migration release prosedürü.
- [ ] Android application ID, signing, app adı/ikonları; iOS bundle ID/signing ve deep link ayarları.
- [ ] Gizlilik politikası, veri saklama/silme ve hesap silme gereksinimleri.
- [ ] Pilot işletme ile kabul testleri ve release checklist.

Çıkış kriteri:

- [ ] CI zorunlu kontrolleri yeşil.
- [ ] Kritik kullanıcı akışları staging'de kabul edilmiş.
- [ ] Release build gerçek backend'e bağlanıp login/session/tamamlama smoke testini geçer.
- [ ] Açık P0/P1 hata yoktur.

### Faz 8.5 — Ödeme ve tahsilat (tamamlandı: 2026-07-19)

Amaç: "Müşteri ne kadar borçlandı" ile "ne kadarı fiilen tahsil edildi"yi ayırmak.

Yapılanlar:

- [x] **Kontrat önce**: `docs/contracts/payment-contract.md` — tablo, RPC, hata
      kodu, yetki matrisi, JSON şekli. Flutter buna karşı yazıldı.
- [x] ADR 0002 — model kararları ve reddedilen alternatifler.
- [x] Migration `20260719120000_payments.sql`: `payments`,
      `payment_allocations`, `payment_events` + 3 enum; composite FK'lerle
      tenant izolasyonu; append-only denetim.
- [x] RPC'ler: `record_session_payment`, `get_session_payment_summary`,
      `void_payment`, `refund_payment` — `security definer`, `FOR UPDATE`,
      tek transaction.
- [x] Migration `20260719130000_payment_reports.sql`:
      `report_collection_summary` — satış ile tahsilat **ayrı** döner.
- [x] RLS + GRANT: yalnızca SELECT; yazma yolu hiç açılmadı (fail-closed).
- [x] SQL testleri 52-74 (toplam 74/74 geçti).
- [x] `payment_concurrency_test.sh` — iki gerçek bağlantıyla aşırı ödeme koruması.
- [x] Flutter: `lib/features/payments/` veri katmanı, controller, checkout akışı,
      seans detayı, geçmiş rozetleri, rapor sunumu.

Çalışma sırasında yakalanan iki gerçek hata (ikisi de düzeltildi ve
regresyon testi yazıldı):

1. **Hayalet hata kodu** — kontrat `payment_currency_mismatch` tanımlıyordu
   ama RPC para birimini seanstan kopyaladığı için bu durum yapısal olarak
   imkansızdı. Kod kaldırıldı, gerekçe kontrata yazıldı.
2. **Sessiz ödeme kaybı** — idempotency anahtarı başka bir seans için
   yeniden kullanılırsa istek "başarılı + replayed" dönüyor ama ikinci seans
   hiç ödenmiyordu. `payment_idempotency_key_reused` guard'ı eklendi
   (test 73-74).

### Faz 9 — Offline-first hazırlığı (MVP sonrası)

Amaç: Online MVP'yi bozmadan güvenli yerel çalışma ve senkronizasyon tasarlamak.

Yapılacaklar:

- [ ] Repository kontratlarını local/remote datasource kombinasyonu için gözden geçir.
- [ ] Hangi işlemlerin offline yapılabileceğini sınıflandır.
- [ ] Conflict çözümü, idempotency key, tombstone ve sync queue tasarımını yaz.
- [ ] Session zamanının offline güven modelini belirle.
- [ ] Stok ve tamamlama gibi güçlü tutarlılık gerektiren işlemleri bağlantı yokken fail closed tutup tutmayacağına karar ver.
- [ ] Drift/SQLite ile sınırlı proof of concept oluştur; ayrı ADR ve test planı hazırla.

Not: Offline senkronizasyon MVP session motoru stabil olmadan üretim kapsamına alınmamalıdır.

## 6. Öğrenme ve teknik devir protokolü

Bu proje yalnızca teslim edilmeyecek; geliştirilen her bölüm ekip üyelerinin açıklayabileceği şekilde ilerletilecektir. Amaç, kod incelemesinde veya teknik görüşmede “Bu neden böyle yapıldı?” sorusuna cevap verebilmektir.

Her görev veya PR tamamlandığında aşağıdaki öğrenme paketi hazırlanır:

1. **Ne yaptık?**  
   Özelliğin kullanıcıya ve sisteme kattığı değer, 3-5 maddede sade biçimde anlatılır.
2. **Neden böyle yaptık?**  
   Mimari karar, seçilen yaklaşım ve reddedilen önemli alternatif açıklanır.
3. **Kod nerede?**  
   Değişen ana dosyalar ve her dosyanın sorumluluğu gösterilir.
4. **Veri nasıl akıyor?**  
   UI → controller → use case → repository → Supabase zinciri gerçek örnek üzerinden izlenir.
5. **Güvenlik nasıl sağlanıyor?**  
   İlgili RLS, rol kontrolü, tenant izolasyonu ve negatif test anlatılır.
6. **Nasıl doğruladık?**  
   Çalıştırılan komutlar, test senaryoları ve beklenen sonuçlar paylaşılır.
7. **Bana ne sorabilirler?**  
   Konuya özel 5-10 kısa soru ve cevap hazırlanır.
8. **Ben gösterebilir miyim?**  
   Geliştirici özelliği kendi cihazında açar, kod yolunu gösterir ve en az bir testi kendisi çalıştırır.

Her faz sonunda 15-30 dakikalık mini devir oturumu yapılır:

- Önce geliştirici kendi cümleleriyle özelliği anlatır.
- Ardından kritik dosyalar birlikte okunur.
- Bir happy-path ve bir error/authorization testi çalıştırılır.
- Açıklanamayan noktalar kısa not olarak kaydedilir ve sonraki fazdan önce kapatılır.

Her önemli konu için `docs/learning/` altında kısa not tutulması önerilir:

```text
docs/learning/
  00-project-foundation.md
  01-supabase-schema-and-rls.md
  02-domain-and-money.md
  03-auth-and-onboarding.md
  04-services-products-customers.md
  05-session-engine.md
  06-reports-and-release.md
```

Notlar ders kitabı gibi uzun olmamalıdır. Her not şu şablonu kullanır:

```md
# Konu

## Problem neydi?
## Çözüm nasıl çalışıyor?
## Değişen ana dosyalar
## Kritik güvenlik/iş kuralları
## Çalıştırılacak komutlar
## Bana sorulabilecek sorular ve cevapları
## Kendi cümlelerimle özet
```

Öğrenme çıkış kriteri:

- [ ] Geliştirici ilgili özelliğin veri akışını ekrana bakmadan çizebilir.
- [ ] En az bir tasarım kararının nedenini açıklayabilir.
- [ ] İlgili testleri ve hata senaryosunu kendisi çalıştırabilir.
- [ ] Güvenlik açısından neyin client'ta, neyin RLS/RPC tarafında korunduğunu anlatabilir.
- [ ] Değişen ana dosyaların sorumluluklarını söyleyebilir.

## 7. İki geliştirici için önerilen iş bölümü

Paralellik yalnızca sınırlar netken kullanılmalıdır; aynı dosyalar üzerinde eşzamanlı çalışma yapılmamalıdır.

| Sprint | Geliştirici A | Geliştirici B | Birlikte kapı |
|---|---|---|---|
| 0 | Bootstrap/env/test düzeltmeleri | Ürün kararları, README, design token eşleme | Faz 0A doğrulama |
| 1 | Supabase schema/constraints/index | Domain entity/value object/repository kontratları | Şema-domain alan eşleşmesi + RLS |
| 2 | Auth datasource/repository/onboarding backend | Auth/onboarding UI/router | Auth + business E2E |
| 3 | Services + products data/domain | Services + products UI | CRUD/RLS testleri |
| 4 | Customers + session RPC | Customers + session UI/controller | Session concurrency testleri |
| 5 | Report view/RPC/index | Dashboard/history/report UI | Rapor mutabakatı |
| 6 | CI/security/release altyapısı | UX/accessibility/device testleri | Staging kabul testi |

Branch önerileri:

- `feature/baseline-bootstrap`
- `feature/supabase-schema-rls`
- `feature/domain-core`
- `feature/auth-onboarding`
- `feature/services-crud`
- `feature/products-customers`
- `feature/session-engine`
- `feature/history-reports`

Her PR küçük bir dikey veya altyapı dilimi olmalı; migration ile ona bağlı domain alan değişikliği aynı PR'da ya da açıkça sıralı PR'larda tutulmalıdır.

## 8. Her PR için Definition of Done

- [ ] Kabul kriterleri PR açıklamasında yazılı.
- [ ] UI'da business logic veya doğrudan Supabase çağrısı yok.
- [ ] Tenant/RBAC etkisi değerlendirilmiş; gerekiyorsa RLS testi var.
- [ ] Yeni iş kuralının unit testi var.
- [ ] Loading, empty, error ve success durumları ele alınmış.
- [ ] Türkçe kullanıcı mesajları anlaşılır; backend ham hatası gösterilmiyor.
- [ ] `dart format --output=none --set-exit-if-changed .` temiz.
- [ ] `flutter analyze` temiz.
- [ ] `flutter test --coverage` başarılı.
- [ ] Codegen kullanılan değişikliklerde `flutter pub run build_runner build --delete-conflicting-outputs` sonrası generated dosya farkı kontrol edilmiş.
- [ ] SQL değiştiyse `supabase db reset` ve `supabase db lint` başarılı.
- [ ] Generated dosyalar güncel ve tekrar üretilebilir.
- [ ] Doküman/README etkisi güncellenmiş.
- [ ] Yeni secret, service-role key veya kişisel veri repoya/loglara girmemiş.
- [ ] İlgili `docs/learning/` notu veya öğrenme özeti hazırlanmış.
- [ ] Geliştirici değişikliği kendi cümleleriyle anlatıp en az bir testi çalıştırabilmiş.

## 9. İlk başlanacak görev listesi

Aşağıdaki sıra, bugün doğrudan issue/PR iş listesine çevrilebilir:

1. **P0 — Temiz klon doğrulamasını düzelt**  
   `.env` asset/bootstrap ve `ProviderScope` test sorununu gider; analyze/test'i yeşile getir.
2. **P0 — Ürün karar oturumu**  
   Rol matrisi, fiyat yuvarlama, minimum ücret, stok alt sınırı, iptal/iade ve timezone kararlarını yazılı onayla.
3. **P0 — Supabase local temel**  
   CLI/config/migration/test klasörlerini kur; README komutlarını yaz.
4. **P0 — Şema + RLS ilk migration**  
   İşletme, üyelik ve katalog tablolarını constraint/index/policy testleriyle oluştur.
5. **P0 — Domain çekirdeği**  
   Money, duration/rounding, entity ve repository kontratlarını unit testlerle ekle.
6. **P1 — Auth refactor + onboarding**  
   UI'daki doğrudan Supabase çağrılarını kaldır; business guard ve owner oluşturmayı tamamla.
7. **P1 — İlk dikey dilim: Services CRUD**  
   Data'dan UI'a bütün katmanları ve RLS testini örnek desen olarak teslim et.
8. **P1 — Products + Customers**
9. **P0 ürün çekirdeği — Session engine + atomik completion RPC**
10. **P1 — History/Reports; ardından stabilizasyon ve release**

## 10. Bilinen riskler ve önlemler

| Risk | Etki | Önlem |
|---|---|---|
| RLS yanlış kurgusu | İşletmeler arası veri sızıntısı | Deny-by-default, policy truth table, non-member testleri |
| Client-side toplam/stok | Finans ve stok tutarsızlığı | Server-side atomik, idempotent RPC |
| Cihaz saatine güvenme | Sayaç manipülasyonu/yanlış ücret | Persisted server timestamps ve test edilebilir clock |
| Float para hesabı | Kuruş farkları | `numeric(12,2)` + Money value object |
| Snapshot eksikliği | Geçmiş faturaların değişmesi | Session ve item snapshot constraint/testleri |
| Eşzamanlı tamamlama | Çift stok düşümü | Status/version precondition, lock ve idempotency |
| Belirsiz rol matrisi | Güvenlik açığı veya operasyon engeli | Migration öncesi onaylı yetki tablosu |
| Tasarım/kod isim uyumsuzluğu | Teknik ve marka borcu | Faz 0A'da tek isim ve token kaynağı |
| Offline kapsamının erken alınması | MVP gecikmesi ve conflict hataları | Online MVP sonrası ayrı ADR/PoC |

## 11. Başarı ölçütü

İlk kullanılabilir MVP şu uçtan uca senaryo kanıtlandığında tamamlanmış sayılmalıdır:

1. Owner kayıt olur ve işletmesini oluşturur.
2. Hizmet, ürün ve müşteri ekler.
3. Employee davet edilir ve yalnızca izinli ekran/işlemleri kullanır.
4. Müşteri için süreli işlem başlatılır; duraklatılır ve devam ettirilir.
5. Aktif işleme ürün eklenir.
6. İşlem tek atomik işlemle tamamlanır; toplam ve stok doğru kalır.
7. Uygulama yeniden açıldığında geçmiş değişmez.
8. Dashboard ve raporlar tamamlanan işlemle aynı finansal sonucu gösterir.
9. Başka işletmenin kullanıcısı bu verilere hiçbir istemci veya doğrudan API denemesiyle erişemez.
10. Analyze, test, RLS kontrolleri ve staging kabul testi CI'da geçer.
