# SüreTakip Gizlilik Politikası

> **Taslak.** Yayınlanmadan önce `[...]` ile işaretli alanlar (veri sorumlusu
> kimliği, iletişim, yürürlük tarihi) doldurulmalı ve bir hukukçu tarafından
> gözden geçirilmelidir. Mağaza gereksinimi: bu metin herkese açık bir URL'de
> yayımlanmalı; URL hem Google Play Data Safety hem App Store Privacy formuna
> girilmelidir.

**Son güncelleme:** [GG.AA.YYYY]
**Veri sorumlusu:** [Şirket/şahıs adı], [adres], [KEP/e-posta]

## 1. Kapsam

Bu politika, SüreTakip mobil uygulamasının (bundle: `com.suretakip.app`)
işlediği kişisel verileri açıklar. Uygulama, işletmelerin dakika bazlı hizmet
takibi ve ücretlendirmesi için kullanılır.

## 2. İşlenen veriler

| Kategori | Örnek | Amaç |
|----------|-------|------|
| Hesap | E-posta adresi, kimlik doğrulama belirteçleri | Giriş, hesap güvenliği |
| İşletme | İşletme adı, üyelik ve roller | Uygulama işlevi, çok kullanıcılı erişim |
| Müşteri (işletmenin girdiği) | Ad, iletişim, işlem geçmişi | İşletmenin kendi kayıt tutması |
| İşlem | Seans süreleri, ürün/hizmet kalemleri, tutarlar, ödemeler | Ücret hesabı, raporlama |
| Teknik | Cihaz tanımlayıcısı (senkron için), hata kayıtları | Çevrimdışı senkron, kararlılık |

Uygulama **konum, kişiler, kamera veya reklam tanımlayıcısı toplamaz.**
Uygulama içi reklam ve üçüncü taraf analitik/izleme kullanılmaz.

## 3. Veri nerede saklanır

- **Cihazda:** Veriler yerel olarak **şifreli** bir veritabanında (SQLCipher)
  tutulur; çevrimdışı çalışmayı mümkün kılar.
- **Sunucuda:** Supabase (Postgres) üzerinde saklanır. Satır-seviyesi güvenlik
  (RLS) ile her işletmenin verisi diğer kullanıcılardan izole edilir. Barındırma
  bölgesi: [Supabase proje bölgesi].

## 4. Veri paylaşımı

Kişisel veriler pazarlama amacıyla satılmaz veya kiralanmaz. Veriler yalnızca
hizmetin çalışması için kullanılan altyapı sağlayıcısı (Supabase) ile, sözleşmesel
gizlilik yükümlülükleri altında işlenir. Yasal zorunluluk halinde yetkili
mercilerle paylaşım yapılabilir.

## 5. Saklama süresi

Veriler, hesap aktif olduğu sürece ve [saklama süresi/yasal yükümlülük]
boyunca tutulur. Hesap silme talebinde ilgili veriler [süre] içinde silinir.

## 6. Kullanıcı hakları (KVKK / GDPR)

Kullanıcı; verilerine erişme, düzeltme, silme, işlemeyi kısıtlama ve taşınabilirlik
haklarına sahiptir. Talepler için: **[iletişim e-postası]**. Başvurular en geç
[yasal süre] içinde yanıtlanır.

## 7. Çocukların gizliliği

Uygulama 18 yaş altına yönelik değildir ve bilerek çocuklardan veri toplamaz.

## 8. Güvenlik

Aktarım TLS ile şifrelenir; yerel veri SQLCipher ile şifrelenir; sunucu erişimi
RLS ve kimlik doğrulama ile denetlenir. Buna rağmen hiçbir yöntem %100 güvenli
değildir.

## 9. Değişiklikler

Bu politika güncellenebilir. Önemli değişiklikler uygulama veya bu URL üzerinden
duyurulur.

## 10. İletişim

Gizlilikle ilgili sorular: **[iletişim e-postası]** — [şirket adı], [adres].
