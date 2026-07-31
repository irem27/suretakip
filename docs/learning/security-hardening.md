# Güvenlik Sıkılaştırması — Öğrenme Notu

> 2026-07-18 tarihli çalışmanın sade Türkçe anlatımı. Amaç: koddaki
> değişiklikleri değil, **arkalarındaki fikri** anlamak.

---

## 1. GRANT ile RLS arasındaki fark

Postgres'te bir kullanıcının veriye erişmesi için **iki ayrı kapıdan**
geçmesi gerekir. Bu ayrımı kaçırmak, bu projedeki en büyük açığın sebebiydi.

| | GRANT | RLS (Row Level Security) |
|---|---|---|
| Neyi sorar? | "Bu tabloya hangi **komutla** ve hangi **kolona** girebilirsin?" | "Girdiğin tabloda hangi **satırları** görebilir/yazabilirsin?" |
| Örnek | `grant update (name) on products` | `using (is_business_member(business_id))` |
| Reddederse hata | `permission denied` (42501) | Sessizce **0 satır** etkilenir |

**Kritik nokta:** RLS satır seviyesinde çalışır, kolon seviyesinde **değil**.

Eski kod şöyleydi:

```sql
grant insert, update on public.products to authenticated;   -- GENEL yetki
create policy "owner/admin can update products" ...          -- satır filtresi
```

Policy, "yalnız kendi işletmenin ürünlerini güncelle" diyordu ve bu doğruydu.
Ama **hangi kolonu** güncelleyebileceğini söylemiyordu. Owner şunu yazabilirdi:

```sql
update products set stock_quantity = 99999 where id = <kendi urunum>;
```

Policy bu satıra izin veriyor (kendi işletmesinin ürünü), GRANT ise tüm
kolonlara açık. Sonuç: stok uydurulabiliyordu.

**Çözüm:** genel yetkiyi kaldırıp yalnız güvenli kolonlara vermek:

```sql
revoke insert, update on public.products from authenticated;
grant update (name, sku, unit_price_minor, track_stock, is_active, archived_at)
  on public.products to authenticated;
```

Artık `stock_quantity`, `business_id` ve `currency_code` listede olmadığı
için istemciden dokunulamaz.

---

## 2. Stok ledger/cache modeli

İki farklı yerde stok bilgisi var ve bu **bilinçli** bir tasarım:

```
inventory_movements  (LEDGER — gerçeğin kaynağı)
  +10  initial       "açılış sayımı"
   -2  sale          seans satışı
   +2  sale_reversal seans iptali
  ─────
   10  = gerçek stok

products.stock_quantity  (CACHE — hızlı okuma için)
  10
```

**Ledger** append-only bir defterdir: her hareket ayrı satır, hiçbiri
silinmez veya değiştirilmez. Denetlenebilir — "stok neden 10?" sorusunun
cevabı satır satır okunabilir.

**Cache** ise tek bir sayı. Neden var? Ürün listesi ekranında 200 ürünün
stoğunu göstermek için her seferinde 200 ayrı `SUM()` çalıştırmak
istemiyoruz; tek kolon okumak çok daha hızlı.

**Tehlike:** iki yer varsa ayrışabilirler. Ledger 10 derken cache 99999
diyorsa, hangisi doğru? Satış anındaki "yeterli stok var mı" kontrolü
cache'e baktığı için, uydurma cache = uydurma stok kontrolü.

**Garanti:** cache'e **yalnızca** ledger trigger'ı yazar. Her ledger
insert'i, aynı transaction içinde cache'i günceller. İkisi ya birlikte
değişir ya hiç değişmez.

---

## 3. Neden `stock_quantity` doğrudan yazılamaz

Üç katmanlı savunma kurduk. Her katman tek başına da işe yarar; birlikte
"derinlemesine savunma" (defense in depth) oluştururlar.

**Katman 1 — GRANT:** `stock_quantity` kolonu UPDATE listesinde yok.
İstemci denerse `permission denied` alır.

**Katman 2 — RLS:** `products` INSERT policy'si düşürüldü. Neden? Çünkü
RLS'li bir tabloda **INSERT policy'si yoksa INSERT reddedilir.** Yani
ileride biri yanlışlıkla `grant insert on products to authenticated`
yazarsa, RLS yine de durdurur. (Policy'yi bırakmak tam tersi etki yapardı:
yanlış grant sessizce çalışır hale gelirdi.)

**Katman 3 — TRIGGER:** Asıl garanti burada.

```sql
create trigger trg_guard_product_stock_write
  before insert or update on public.products
  for each row execute function public.guard_product_stock_write();
```

Guard şunu yapar: `stock_quantity` değişmişse ve bu değişiklik ledger
trigger'ından **gelmiyorsa**, hatayla reddet. Ledger trigger'ı yazmadan
önce transaction-local bir bayrak açar, yazar, bayrağı hemen kapatır.

Bu katman GRANT'ten bağımsızdır: `service_role` bile (ki `grant all`
yetkisi vardır) cache'e doğrudan yazamaz. Test 37 tam olarak bunu
kanıtlıyor.

**Yol boyunca çıkan sürpriz:** genel UPDATE yetkisini kaldırınca ledger
trigger'ının **kendisi** kırıldı. Sebep: `apply_inventory_movement()`
SECURITY DEFINER değildi, yani çağıran kullanıcının yetkisiyle çalışıyordu
ve sessizce `authenticated`'ın genel UPDATE grant'ine yaslanıyordu. Onu
ayrıcalıklı hale getirmek gerekti — bu, "cache'e yazabilen tek yol"
tanımını kodda da açık hale getirdi.

---

## 4. SECURITY DEFINER RPC neden kullanılıyor

Bir fonksiyon iki şekilde çalışabilir:

- **SECURITY INVOKER** (varsayılan): fonksiyonu **çağıran** kişinin
  yetkileriyle çalışır.
- **SECURITY DEFINER**: fonksiyonu **yazan** kişinin (tablo sahibi)
  yetkileriyle çalışır.

Bunu **kontrollü bir yetki yükseltme** olarak düşünün. Kullanıcının
`business_members` tablosuna yazma yetkisi yok. Ama
`add_business_member(...)` RPC'sini çağırabiliyor ve o fonksiyon,
tablo sahibi yetkisiyle yazabiliyor.

Kazanç: **yazma yolu tek bir kapıdan geçer.** O kapıda istediğimiz her
kuralı uygulayabiliriz:

```sql
perform 1 from public.businesses where id = p_business_id for update; -- kilit
perform public.assert_can_manage_member(p_business_id, p_role, p_role); -- yetki
-- ancak bundan sonra insert
```

Doğrudan tablo yazmada bu kuralları uygulayacak yer yoktur — policy'ler
"bu satıra dokunabilir misin"i sorar, "bu işlem işletmeyi tutarsız bir
duruma sokar mı"yı soramaz.

**Zorunlu güvenlik detayı:** her SECURITY DEFINER fonksiyonda
`set search_path = ''` vardır ve tüm nesneler `public.` önekiyle yazılır.
Aksi halde saldırgan kendi şemasında sahte bir `products` tablosu
oluşturup arama yolunu "zehirleyebilir" ve fonksiyon yükseltilmiş
yetkiyle onun kodunu çalıştırabilir.

---

## 5. Son owner invariantı

**Invariant** = her zaman doğru kalması gereken kural. Buradaki kural:

> Her işletmenin her an **en az bir aktif owner'ı** vardır.

Eski kodda owner kendi satırını silebiliyor, pasifleştirebiliyor veya
rolünü `staff`'a düşürebiliyordu. Üçü de işletmeyi sıfır owner'la bırakır.

**Neden felaket?** Owner-only işlemler (işletme ayarları, tamamlanmış seans
iptali, owner atama) artık **hiç kimse** tarafından yapılamaz. Kendi kendine
düzeltilemez de — owner atayacak bir owner yoktur. Yalnız `service_role`
ile elle müdahale çözer. Yani kullanıcı tek tıkla hesabını kalıcı olarak
kilitleyebiliyordu.

**Çözüm:** invariantı ihlal edebilecek üç yol da (silme, pasifleştirme,
rol düşürme) aynı kontrolden geçer:

```sql
create function public.assert_not_last_owner(p_member_id uuid) ...
  -- Bu satır owner'lıktan çıkarsa, geriye aktif owner kalıyor mu?
```

**Eşzamanlılık tuzağı:** iki owner aynı anda "ben ayrılıyorum" derse, ikisi
de "diğeri var, sorun yok" görüp ikisi de ayrılabilir → sıfır owner. Bunu
önlemek için her üyelik mutasyonu önce `businesses` satırını kilitler:

```sql
perform 1 from public.businesses where id = v_business_id for update;
```

Aynı işletmedeki üyelik işlemleri böylece sıraya girer.

**Meşru çıkış yolu:** tek owner gerçekten ayrılmak isterse
`transfer_business_ownership` kullanır — hedef owner olur, çağıran admin'e
düşer, tek transaction. Arada hiçbir an sıfır owner oluşmaz.

**Test 50'de öğrenilen ilginç ayrıntı:** owner kendini pasifleştirdikten
sonra `business_members` tablosunda **hiçbir satır göremez** — çünkü SELECT
policy'si aktif üyelik ister. Bu doğru davranıştır (işletmeden ayrıldı),
ama testi yazarken tuzak oldu: doğrulamayı hâlâ üye olan biri yapmalı.

---

## 6. Sunucu zamanı ile monotonik sürenin farkı

İki farklı "zaman" kavramı var:

| | Duvar saati (wall clock) | Monotonik saat |
|---|---|---|
| Ne der? | "Şu an 14:32" | "Başlangıçtan beri 12 dakika 37 saniye geçti" |
| Dart karşılığı | `DateTime.now()` | `Stopwatch.elapsed` |
| Geri gidebilir mi? | **Evet** (kullanıcı saati değiştirir, NTP düzeltir) | **Hayır**, asla azalmaz |

Eski kod geçen süreyi iki duvar saati farkıyla ölçüyordu:

```dart
DateTime effectiveServerNow(DateTime clientNow) =>
    serverAnchor.add(clientNow.difference(clientAnchor));  // ← duvar saati farkı
```

Kullanıcı seans sırasında telefonun saatini 2 saat ileri alırsa, sayaç
aniden 2 saat sıçrar ve fiyat önizlemesi yanlış görünür.

**Çözüm — çapa + monotonik ölçüm:**

- **Çapa (anchor):** mutlak zamanı sunucudan bir kez alırız
  (`server_now` RPC). Cihazın saatine hiç güvenmeyiz.
- **Geçen süre:** o andan itibaren `Stopwatch` ile ölçeriz.

```dart
DateTime get effectiveServerNow =>
    serverAnchor.add(_clock.elapsed - _clockAnchor);  // ← monotonik fark
```

Duvar saati artık denklemde **hiç yok**, dolayısıyla değişmesi sonucu
etkileyemez.

**Önemli sınır:** bu yalnızca **canlı gösterimdir**. Kesin ücret her zaman
`complete_session` RPC'sinden gelir; sunucu, süreyi `session_time_entries`
ledger'ından hesaplar. Cihazdaki sayaç bozulsa bile faturalama doğrudur —
canlı sayaç bir "önizleme", ödeme kaydı değildir.

---

## 7. Değiştirilen ana dosyalar

**Yeni migration'lar (ileri yönlü — eski migration'lar değiştirilmedi):**

| Dosya | Ne yapar |
|---|---|
| `supabase/migrations/20260718090000_product_write_hardening.sql` | Ürün yazma yolu: kolon-bazlı grant, INSERT policy düşürme, stok guard trigger'ı, `apply_inventory_movement` → SECURITY DEFINER |
| `supabase/migrations/20260718090100_onboarding_rpc_hardening.sql` | `create_business_with_owner` kaldırıldı |
| `supabase/migrations/20260718090200_membership_rpcs.sql` | 5 üyelik RPC'si, son owner invariantı, tablo yazma yetkilerinin kaldırılması |

**Testler:**

| Dosya | Ne değişti |
|---|---|
| `supabase/tests/rls_test.sql` | 28 → **51 senaryo**. Kurulum da savunmasız yollardan (doğrudan INSERT) RPC'lere taşındı |

**Uygulama (Dart):**

| Dosya | Ne değişti |
|---|---|
| `lib/core/constants/app_constants.dart` | 5 yeni üyelik RPC adı |
| `lib/core/errors/postgres_error_mapper.dart` | Yeni RPC hataları → Türkçe kullanıcı mesajları |
| `lib/features/businesses/data/datasources/businesses_remote_data_source.dart` | Tablo yazmaları → RPC çağrıları |
| `lib/features/businesses/data/repositories/businesses_repository_impl.dart` | Yeni RPC sözleşmesi; mutasyon sonrası satır sunucudan yeniden okunur |
| `lib/features/businesses/domain/repositories/businesses_repository.dart` | Sözleşme sunucu RPC'leriyle hizalandı |
| `lib/core/utils/monotonic_clock.dart` | **Yeni** — `MonotonicClock` soyutlaması + `Stopwatch` implementasyonu |
| `lib/features/sessions/presentation/controllers/sessions_controllers.dart` | `clientAnchor` (DateTime) → monotonik saat |
| `lib/features/sessions/presentation/pages/session_detail_page.dart` | `_visualNow` kaldırıldı; sayaç monotonik saatten okur |
| `lib/features/businesses/domain/entities/business_capabilities.dart` | **Yeni** — merkezi yetki matrisi (sunucudaki rol kurallarının UI karşılığı) |
| `lib/app/providers/business_selection_controller.dart` | **Yeni** — işletme seçimi ve bağlam temizliği |
| `lib/app/providers/app_providers.dart` | `selectedBusinessId`, `currentMemberProvider`, `businessCapabilitiesProvider`, `activeBusinessScopeProvider` |
| `lib/app/router/app_router.dart` | Katalog yazma route'larına yetki guard'ı (hata durumunda **fail-closed**) |
| Tüm feature controller'ları | İşletme kapsamlı provider'lar `BusinessScope` ile family-key'lendi (bkz. S12) |

**Dokümanlar:** `README.md`, `.github/workflows/ci.yml`, `docs/database-design.md`,
`docs/adr/0001-member-invitations.md` (yeni), bu dosya.

---

## 8. Çalıştırılan test komutları

```bash
# Flutter tarafı
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage

# Supabase tarafı
supabase db reset --local --no-seed
docker exec -i supabase_db_suretakip psql -U postgres -d postgres -q \
  < supabase/tests/rls_test.sql
```

Sonuçlar: `analyze` temiz · Flutter testleri yeşil · satır kapsamı **%69,9**
(CI tabanı %65) · RLS/RPC paketi **51/51**.

---

## 9. Sorulabilecek teknik sorular ve kısa cevaplar

**S1 — RLS zaten varken neden kolon bazlı GRANT'e ihtiyaç duydun?**
RLS satır seviyesinde çalışır, kolon seviyesinde değil. Policy "bu ürüne
dokunabilirsin" der ama "bu ürünün hangi alanına" demez. `stock_quantity`
korumasını yalnız policy ile yazmak mümkün değildi.

**S2 — Neden eski migration dosyasını düzeltmek yerine yeni migration yazdın?**
Migration geçmişi değişmez bir kayıttır. Uygulanmış bir dosyayı değiştirmek,
o migration'ı çalıştırmış ortamlarla yeni ortamlar arasında sessiz bir şema
farkı yaratır. İleri yönlü migration her ortamda aynı sonucu verir.

**S3 — Cache'i tamamen kaldırıp her seferinde ledger'ı toplasan olmaz mıydı?**
Olurdu ve tutarlılık sorunu da hiç doğmazdı. Ama ürün listesi gibi ekranlarda
her satır için `SUM()` çalıştırmak gerekirdi. Cache bir performans kararıdır;
bedeli, tutarlılığı trigger ile garanti etme zorunluluğudur.

**S4 — `service_role` RLS'i baypas ediyor. O zaman bu korumaların anlamı ne?**
`service_role` anahtarı **hiçbir zaman mobil uygulamaya konmaz**; yalnızca
sunucu tarafında bulunur. Ayrıca stok guard'ı bir trigger olduğu için
`service_role`'ü de durdurur — RLS baypası trigger baypası anlamına gelmez
(test 37 bunu kanıtlıyor).

**S5 — `security definer` tehlikeli değil mi?**
Kontrolsüz kullanılırsa evet. Bu yüzden üç kural uygulandı: (1) her
fonksiyonda `set search_path = ''` ve şema-nitelikli isimler, (2) fonksiyonun
ilk işi çağıranın yetkisini doğrulamak, (3) yalnız gerekli fonksiyonlara
`authenticated` execute yetkisi — yardımcılar (`assert_not_last_owner`,
`assert_can_manage_member`) dışarıya hiç açılmadı.

**S6 — `FOR UPDATE` kilidi tam olarak neyi engelliyor?**
Kontrol-sonra-yaz (check-then-act) yarışını. İki owner aynı anda ayrılmaya
kalkarsa, ikisi de "diğer owner var" görüp ikisi de ayrılabilirdi. Kilit,
aynı işletmedeki üyelik mutasyonlarını sıraya sokar; ikinci işlem birincinin
sonucunu görür ve `last_owner_protected` alır.

**S7 — Neden `create_business_with_owner`'ı sadece REVOKE etmedin, sildin?**
REVOKE geri alınabilir bir ayardır; ileride biri farkında olmadan tekrar
grant verebilir. Fonksiyon silinince çağrılacak bir şey kalmaz. Kullanımda
olmadığını önce doğruladım (`grep` ile: uygulama kodunda hiç yoktu, yalnız
test kurulumundaydı).

**S8 — UI'da rol kontrolü yapıyorsan, sunucu kontrolü gereksiz değil mi?**
Tam tersi — sunucu kontrolü **tek gerçek güvenlik sınırıdır**. İstemci kodu
değiştirilebilir, API doğrudan çağrılabilir. UI'daki rol farkındalığı yalnız
kullanıcı deneyimi içindir: staff'a tıklayınca hata verecek bir buton
göstermemek. Güvenlik değil, nezaket.

**S9 — Canlı sayaç yanlışsa müşteri yanlış ücret öder mi?**
Hayır. Kesin tutar `complete_session` RPC'sinde, sunucudaki
`session_time_entries` ledger'ından hesaplanır. Cihaz sayacı yalnız
görseldir. Bu yüzden hata P0 değil P1 olarak sınıflandırıldı.

**S10 — `track_stock` kapatılıp açılırsa stok ne olur?**
Cache son değerinde donar, ledger geçmişi silinmez. Kapalıyken yapılan
satışlar stok düşmez ve cache'e yansımaz. Tekrar açıldığında dondurulmuş
değerden devam edilir; aradaki farkı owner/admin `manual_adjustment`
hareketiyle düzeltir. Bilinçli olarak **sessiz otomatik düzeltme yapılmaz** —
stok farkı görünür bir operasyonel karar olmalıdır.

**S12 — İşletme değiştirince eski işletmenin verisi neden ekranda kalıyordu?**
Riverpod'da bir provider `invalidate` edilince yeni `AsyncLoading` durumu
`copyWithPrevious` ile önceki değeri taşır ve `AsyncValue.when()` varsayılan
olarak (`skipLoadingOnRefresh: true`) yükleme yerine o eski veriyi gösterir.
Yani "yenileme" için doğru olan davranış, "işletme değişimi" için bir veri
sızıntısıydı. Çözüm invalidate listesini uzatmak değil, provider'ları
`BusinessScope` ile **family-key'lemek** oldu: işletme değişince family
anahtarı değişir, bu tamamen farklı bir provider örneğidir ve taşıyacak
önceki değeri yoktur. Sızıntı yamanmadı, yapısal olarak imkânsız hale geldi.
Ders: bir invariantı "her yerde temizlemeyi unutmamakla" değil, ihlal edilmesi
mümkün olmayan bir yapıyla korumak gerekir.

**S11 — Bir hata mesajının `not_authorized` mı `not_a_member` mi döneceğine
nasıl karar verdin?**
`not_a_member`: çağıran o işletmede hiç aktif üye değil (başka tenant'ın
verisine erişim denemesi dahil). `not_authorized`: üye ama rolü yetmiyor.
Ayrım, istemcinin doğru mesajı göstermesini sağlar; ikisi de aynı miktarda
bilgi sızdırır (yani hiç — zaten üye olmadığınız işletmenin varlığını
UUID'siz öğrenemezsiniz).
