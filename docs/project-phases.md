# Menü Sayaç - Faz Bazlı Uygulama Planı

Bu doküman, projeyi baştan sona adım adım tamamlamak için fazlara ayrılmış bir çalışma planıdır.

## Kullanım Şekli

- Her faz tek bir hedefe odaklanır.
- Faz tamamlanmadan bir sonraki faza geçilmez.
- Her faz sonunda doğrulama komutları çalıştırılır.
- PR'lar mümkün olduğunca faz veya alt faz bazında açılır.

## Faz 0 - Proje Zemini (Tamamlandı)

Amaç: Çalışan bir Flutter iskeleti ve temel app shell oluşturmak.

Yapılanlar:

1. Flutter proje kurulumu
2. Paketlerin eklenmesi
3. app/core/features klasör yapısının açılması
4. Supabase init + dotenv kurulumu
5. Material 3 tema iskeleti
6. GoRouter başlangıç yapısı
7. Geçici login ve dashboard ekranı

Çıkış kriteri:

- `flutter pub get` başarılı
- `flutter test` başarılı
- `flutter analyze` temiz

## Faz 1 - Veritabanı ve Güvenlik Temeli (Tamamlandı - 2026-07-17)

> **Güncelleme (2026-07-17):** Bu faz, aşağıdaki adımların ötesine geçen
> production modeliyle (v2) tamamlandı: kuruş bazlı `bigint` para,
> `owner/admin/staff` rolleri, `session_time_entries` zaman ledger'ı,
> `inventory_movements` stok ledger'ı + cache trigger'ı, 6 transaction-safe
> seans RPC'si ve 20 senaryoluk test paketi (`supabase/tests/rls_test.sql`).
> Ayrıca tamamlama RPC'si Faz 6'ya bırakılmayıp DB tarafında şimdiden
> implemente edildi. Detay: [database-design.md](database-design.md).

Amaç: Supabase tarafında tüm tablo, index, constraint, RLS ve yetki modelini hazır etmek.

Adımlar:

1. Migration klasör yapısını oluştur (`supabase/migrations`).
2. Tabloları oluştur:
   - businesses
   - business_members
   - customers
   - services
   - products
   - sessions
   - session_items
3. Foreign key, unique ve check constraint'leri ekle.
4. İstenen alanlara index ekle (`business_id`, `status`, `started_at`, vb.).
5. `updated_at` otomatik güncelleme trigger'ı yaz.
6. RLS'i tüm tablolarda aktif et.
7. `business_members` üyelik/yetki kontrolleri için güvenli policy seti yaz.
8. Gerekirse `security definer` helper function ile recursion riskini önle.
9. İşlem tamamlama için atomik RPC tasarımını çıkar (implementasyon Faz 6'da).

Çıkış kriteri:

- Migration temiz uygulanır ✅
- RLS aktif ve policy testleri geçer ✅ (20/20)
- Owner/Admin/Staff rolleri beklenen izinleri verir ✅ (güncellendi: 2026-07-17 — roller owner/admin/staff oldu)

## Faz 2 - Domain Çekirdeği ve Kontratlar

Amaç: Tüm feature'lar için entity, repository interface ve temel usecase kontratlarını netleştirmek.

Adımlar:

1. Domain entity'leri oluştur:
   - Business
   - BusinessMember
   - Customer
   - Service
   - Product
   - Session
   - SessionItem
2. Freezed + json_serializable ile model yapısını standardize et.
3. Repository interface'lerini domain katmanında yaz.
4. Value object/utility kararını uygula:
   - Para yönetimi (numeric hassasiyet)
   - Süre/dakika dönüşümleri
5. Merkezi exception hiyerarşisini oluştur:
   - NetworkException
   - AuthenticationException
   - AuthorizationException
   - ValidationException
   - DatabaseException
   - UnknownException
6. Supabase hata mapleme stratejisini tanımla.

Çıkış kriteri:

- Domain katmanı framework bağımsız derlenebilir
- Repository kontratları tüm feature'lar için hazır

## Faz 3 - Auth + Onboarding Akışı

Amaç: Kimlik doğrulama ve işletme oluşturma akışını tamamlamak.

Adımlar:

1. Auth ekranlarını tamamla:
   - Login
   - Register
   - Forgot Password
2. Auth repository + datasource implementasyonunu yaz.
3. Auth guard'ı onboarding guard ile genişlet.
4. Register sonrası onboarding akışını bağla.
5. Onboarding ekranlarını oluştur:
   - İşletme adı
   - Para birimi
   - Saat dilimi
   - İlk hizmet (zorunlu)
   - İlk ürün (opsiyonel)
6. `businesses` ve `business_members` kayıtlarını birlikte oluştur.

Çıkış kriteri:

- Yeni kullanıcı kayıt olabilir
- İlk işletmesini oluşturabilir
- Giriş ve yönlendirme kuralları doğru çalışır

## Faz 4 - Services CRUD

Amaç: Hizmet yönetimini tam işlevsel hale getirmek.

Adımlar:

1. Service model/repository/data source implementasyonu.
2. Hizmet listesi ekranı.
3. Hizmet ekleme ve düzenleme ekranları.
4. Form doğrulamaları:
   - ad zorunlu
   - dakika ücreti > 0
5. Ücretlendirme alanlarını forma ekle: `rounding_interval_minutes` (>0) ve
   `minimum_charge_minutes` (>=0). (güncellendi: 2026-07-17 — ~~exact/floor/ceil~~
   yerine dakika aralığına yukarı yuvarlama modeli geldi)
6. Silme yerine aktif/pasif yaklaşımı uygula.
7. Riverpod provider/controller yapısını finalize et.

Çıkış kriteri:

- Hizmet CRUD akışları uçtan uca çalışır
- Liste, filtre ve aktif/pasif durumu doğru görünür

## Faz 5 - Products ve Customers CRUD

Amaç: Ürün ve müşteri yönetimini tamamlamak.

Adımlar (Products):

1. Ürün listesi/ekle/düzenle ekranları.
2. Stok takibi alanlarını ekle (`trackStock`, `stockQuantity`).
3. Form doğrulamaları:
   - ürün adı zorunlu
   - fiyat > 0
   - stok negatif olamaz
4. Aktif/pasif desteği.

Adımlar (Customers):

1. Müşteri listesi + arama.
2. Yeni müşteri ve düzenleme ekranı.
3. Form doğrulamaları:
   - ad zorunlu
   - e-posta girildiyse valid format
4. Misafir müşteri desteğini session akışına hazırlık olarak ekle.

Çıkış kriteri:

- Ürün ve müşteri CRUD işlemleri tam çalışır
- Validation ve hata mesajları kullanıcı dostu görünür

## Faz 6 - Session Engine (Başlat / Aktif / Duraklat / Ürün Ekle / Tamamla)

Amaç: Uygulamanın çekirdeği olan süreli işlem akışını tamamlamak.

> **Güncelleme (2026-07-17):** DB tarafı (RPC'ler, zaman/stok ledger'ları,
> atomik tamamlama) Faz 1'de implemente edildi. Bu faz artık ağırlıklı olarak
> **Flutter entegrasyonu**dur: ekranlar bu RPC'leri çağırır, elle
> insert/update yapmaz. Eski `paused_at`/`total_paused_seconds` modeli ve
> "aynı ürün quantity artırır" kuralı kaldırıldı.

Adımlar (güncellendi: 2026-07-17):

1. Yeni işlem başlat ekranı:
   - müşteri seç/misafir
   - hizmet seç
   - opsiyonel not
2. Başlatmayı `start_session` RPC'sine bağla (snapshot'ları DB alır).
3. Aktif işlem ekranı:
   - canlı süre (görsel timer; gerçek süre `session_time_entries`'ten)
   - canlı hizmet tutarı
   - ürünler toplamı
   - canlı genel toplam
4. Duraklat/devam akışını `pause_session` / `resume_session` RPC'lerine bağla.
5. Ürün ekleme akışı (`add_product_to_session` RPC):
   - arama
   - adet seçimi, opsiyonel satır indirimi
   - aynı ürün tekrar eklenirse YENİ satır açılır (farklı fiyat/indirim desteklenir)
6. `SessionPriceCalculator` domain servisini tamamla (UI'daki canlı tahmin için;
   kesin hesap DB'de):
   - activeDuration (aralıklardan)
   - chargedMinutes (`ceil(dk/interval)*interval`, min. dakika uygulanır)
   - serviceSubtotalMinor / productsSubtotalMinor / grandTotalMinor
7. Tamamlama modalını oluştur (indirim + vergi girişi).
8. Tamamlamayı `complete_session` RPC'sine bağla; iptal için `cancel_session`.

Çıkış kriteri:

- Uygulama kapanıp açılsa da süre doğru hesaplanır
- Tamamlanan işlemlerde snapshot ve toplamlar tutarlı kalır
- Stok düşümü atomik çalışır

## Faz 7 - Geçmiş ve Raporlar

Amaç: Operasyonel geçmiş ve gelir raporlarını tamamlamak.

Adımlar:

1. İşlem geçmişi listesi.
2. Filtreler:
   - tarih
   - müşteri
   - hizmet
   - durum
3. İşlem detay ekranı.
4. Rapor sorguları için view/RPC katmanı oluştur.
5. Rapor ekranları:
   - günlük/haftalık/aylık gelir
   - ürün geliri
   - hizmet geliri
   - en çok kullanılan hizmetler
   - en çok satılan ürünler
   - en çok harcama yapan müşteriler

Çıkış kriteri:

- Filtreler performanslı çalışır
- Dashboard metrikleri raporlarla tutarlıdır

## Faz 8 - Test, Stabilizasyon ve Yayına Hazırlık

Amaç: Uygulamayı production-ready seviyeye çıkarmak.

Adımlar:

1. Unit testleri tamamla:
   - ceil/floor/exact
   - minimum süre
   - pause süresi düşümü
   - ürün/hizmet/genel toplam
   - snapshot kuralları
2. Widget testleri tamamla:
   - login
   - service form
   - product form
   - aktif session
   - tamamlama modalı
3. Repository testlerinde mock/fake altyapısını güçlendir.
4. Hata mesajlarını tamamen Türkçe ve kullanıcı odaklı hale getir.
5. Responsive düzeni telefon + tablet için gözden geçir.
6. Performans ve query gözden geçirme (index/view optimize).
7. Release checklist hazırla.

Çıkış kriteri:

- Kritik akışlar test kapsamına alınmış
- `flutter analyze` ve testler temiz
- Staging ortamında kabul testleri geçmiş

## Faz 9 - Offline-First Geçiş Hazırlığı (Opsiyonel Sonraki Sprint)

Amaç: Mevcut mimariyi bozmadan local cache/offline katmanına geçiş zemini hazırlamak.

Adımlar:

1. Repository arayüzlerini offline senaryoya uygun gözden geçir.
2. Sync stratejisini tanımla (last-write-wins / conflict resolution).
3. Drift/SQLite local datasource prototipi çıkar.
4. Online/offline fallback kararlarını dokümante et.

Çıkış kriteri:

- Offline katman eklenebilirliği mimari olarak netleşmiş
- Ana kodu kırmadan geçiş planı hazır

---

## Fazlara Göre Tasarım Dosyası Eşlemesi

Kaynak tasarım klasörü:

- /Users/iremcan/Downloads/stitch_s_retakip_business_manager

Not:

- Klasör adlarında Türkçe karakterler normalize edildiği için bazı isimler bozulmuş görünüyor (örnek: m_teriler, r_nler).
- Aşağıdaki eşleme, geliştirme sırasını faz planıyla birebir hizalamak için referans alınmalıdır.

### Faz 0 (Tamamlandı) - App Shell ve Geçici Ekranlar

- s_retakip_a_l_ekran/code.html (açılış/yükleme ekranı)
- giri_yap/code.html (giriş ekranı)
- ana_sayfa/code.html (dashboard/ana sayfa)

### Faz 3 - Auth + Onboarding

- giri_yap/code.html (Login)
- s_retakip_a_l_ekran/code.html (ilk açılış akışı)

Not: Register/Forgot Password/Onboarding için birebir tasarım dosyası bu pakette görünmüyor; bu ekranlar mevcut design system ile aynı dilde üretilecek.

### Faz 4 - Services CRUD

- hizmetler_listesi/code.html (hizmet listesi)
- yeni_hizmet_ekle/code.html (hizmet ekle/düzenle formu)
- hizmet_detay/code.html (hizmet detay)
- hizmet_kategorileri/code.html (hizmet kategorileri)

### Faz 5 - Products ve Customers CRUD

- r_nler/code.html (ürünler listesi)
- m_teriler/code.html (müşteri listesi)
- tan_mlar_men_s/code.html (tanımlar menüsü giriş ekranı)

### Faz 6 - Session Engine

- yeni_i_lem_ba_lat/code.html (yeni işlem başlat akışı)
- hizmet_se_imi_alt_paneli/code.html (hizmet seçim alt paneli)
- i_lem_detay_aktif/code.html (aktif işlem detay)
- i_lemi_tamamla/code.html (işlemi tamamlama/onay)
- ana_sayfa/code.html (aktif işlem kartları ve hızlı aksiyonlar)

### Faz 7 - Geçmiş ve Raporlar

- ana_sayfa/code.html (metrik kartları başlangıç referansı)

Not: Ayrı History ve Rapor detay ekranlarının birebir HTML tasarımı bu pakette yok; mevcut design language korunarak üretilecek.

### Faz 8 - Stabilizasyon ve UI Parlatma

- s_retakip_design_system/DESIGN.md (renk, tipografi, spacing, component kuralları)

### Faz 9 - Offline-First

- Doğrudan ekran tasarım bağımlılığı yok.
- UI değişiklikleri gerektiğinde mevcut ekranların aynı görsel dili korunur.

---

## Hızlı İş Dağılımı Önerisi (Ekip İçin)

1. Geliştirici A: Faz 1-2 (DB, RLS, domain kontratları)
2. Geliştirici B: Faz 3-4 (auth + hizmet ekranları)
3. Ortak çalışma: Faz 5-6 (müşteri/ürün + session engine)
4. Son sprint: Faz 7-8 (rapor, test, polish)

Bu dağılımda Faz 6 başlamadan önce Faz 1 ve Faz 2'nin merge edilmiş olması zorunludur.

---

## Her Faz Sonunda Zorunlu Komutlar

```bash
flutter pub get
flutter analyze
flutter test
```

SQL değişikliği olan fazlarda ek olarak:

```bash
# örnek akış (Supabase CLI kullanılıyorsa)
supabase db reset
supabase db lint
```

---

## Önerilen Sprint Dağılımı

- Sprint 1: Faz 1 + Faz 2
- Sprint 2: Faz 3 + Faz 4
- Sprint 3: Faz 5 + Faz 6
- Sprint 4: Faz 7 + Faz 8
- Sprint 5: Faz 9 (opsiyonel)

Not: Ekip kapasitesine göre fazlar alt görevlere ayrılıp paralel ilerletilebilir, ancak Faz 1 ve Faz 2 tamamlanmadan iş akışı feature'larına başlanmamalıdır.
