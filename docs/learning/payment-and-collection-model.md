# Ödeme ve tahsilat modeli

Bu belge, SüreTakip'te satış ve ödeme bilgilerinin neden ayrı tutulduğunu basitçe anlatır.

## Satış ile tahsilat aynı şey değildir

Satış toplamı, müşterinin işlem sonunda ne kadar borçlandığını gösterir. Seans tamamlanınca bu tutar kesinleşir.

Tahsilat ise işletmenin müşteriden gerçekten aldığı paradır. Müşteri hemen ödeme yapmayabilir, yalnızca bir kısmını ödeyebilir veya birden fazla yöntem kullanabilir. Bu yüzden tamamlanan bir seans otomatik olarak ödenmiş sayılmaz.

Raporlarda da iki bilgi ayrı gösterilir:

- Kesinleşen satış: tamamlanan işlemlerin satış toplamı.
- Net tahsilat: alınan para eksi iadeler.

## Neden `payment_allocations` ayrı bir tablo?

`payments` tablosu para hareketini tutar. `payment_allocations` tablosu ise bu paranın hangi seansa mahsup edildiğini, yani hangi borcu kapattığını tutar.

Bugünkü sürümde bir ödeme tek bir seansa bağlıdır. Yine de bu bağ ayrı tabloda tutulur. Böylece ileride tek ödemenin birden fazla seansa dağıtılması gerekirse `payments` tablosunu değiştirmek gerekmez. Ayrıca bir seansın net tahsilatı tek ve tutarlı bir yerden hesaplanır.

Flutter tarafında ayrı bir `PaymentAllocation` sınıfı yoktur. Bu ayrıntı veritabanında kalır; RPC, uygulamaya hazır ödeme özetini döndürür.

## Bölünmüş ödeme nasıl çalışır?

Aynı seans için birden fazla tahsilat kaydı açılabilir. Her kayıt kendi yöntemini ve tutarını taşır. Örneğin toplamın bir kısmı nakit, kalanı kart olabilir.

Arayüz her başarılı tahsilattan sonra sunucudan gelen güncel özeti gösterir. Kalan bakiye varsa kullanıcı başka bir yöntemle yeni tahsilat girebilir. Girilen tutar kalan bakiyeden büyük olamaz.

## Idempotency çift ödemeyi nasıl önler?

Telefon ödeme isteğini gönderirken ağ kopabilir. Kullanıcı sonucu görmediği için aynı düğmeye tekrar basabilir.

Her ödeme niyeti için Flutter bir kez benzersiz `idempotency_key` üretir. Aynı niyet tekrar denenirse aynı anahtar yeniden kullanılır. Sunucu bu anahtarla daha önce ödeme oluşturduysa yeni bir ödeme açmaz; eski sonucu `replayed: true` ile döndürür.

Arayüz bu durumda “Bu tahsilat zaten kaydedilmişti.” der. Böylece kullanıcı ikinci kez para alınmış gibi düşünmez. Kullanıcı yeni bir tutar veya yeni bir ödeme yöntemi seçerse bu yeni bir niyettir ve yeni anahtar üretilir.

## Neden `FOR UPDATE` kullanılır?

İki cihaz aynı seans için aynı anda ödeme girebilir. İkisi de eski kalan bakiyeyi görürse toplam ödeme borcu aşabilir.

`FOR UPDATE`, ilgili seans veya ödeme satırını işlem bitene kadar kilitler. İlk istek çalışırken ikinci istek bekler. İlk istek tamamlandıktan sonra ikinci istek kalan bakiyeyi yeniden hesaplar. Böylece fazla tahsilat ve eşzamanlı çift kayıt engellenir.

## İadeler neden eski kaydı silmez?

Para hareketleri denetlenebilir olmalıdır. Eski tahsilatı silmek, geçmişte ne olduğunu gizler ve raporları açıklamayı zorlaştırır.

İade yapıldığında yeni bir `refund` ödeme kaydı oluşturulur. Bu kayıt hangi tahsilata ait olduğunu `original_payment_id` ile gösterir. Orijinal tahsilat yerinde kalır. Yanlış tahsilat da silinmez; `voided` durumuna alınır ve gerekçesi saklanır.

Bu yaklaşım sayesinde “kim, ne zaman, ne kadar tahsil etti veya iade etti?” sorusu sonradan cevaplanabilir.

## Ödeme durumu neden seans durumundan ayrı?

Seans durumu işin yaşam döngüsünü anlatır: aktif, duraklatılmış, tamamlanmış veya iptal edilmiş.

Ödeme durumu borcun yaşam döngüsünü anlatır:

- `unpaid`: Ödenmedi.
- `partially_paid`: Kısmi ödendi.
- `paid`: Ödendi.

Tamamlanmış bir seans ödenmemiş kalabilir. Ayrıca ödenmiş bir seansın bir kısmı iade edilince ödeme durumu tekrar `partially_paid` olabilir. Bu nedenle iki durum tek alanda tutulamaz.

Ödeme durumu veritabanında ayrı bir kolon olarak saklanmaz. Tahsilatlar, iadeler ve seans toplamından her sorguda hesaplanır. Böylece eski bir durum bilgisinin yanlış kalması önlenir.

## RLS ve RPC birlikte nasıl çalışır?

RLS, kullanıcının yalnızca üyesi olduğu işletmenin ödeme kayıtlarını okumasına izin verir. Başka işletmenin kayıtları görünmez.

Ödeme tablolarına doğrudan ekleme, güncelleme veya silme izni yoktur. Yazma işlemleri yalnızca RPC'lerle yapılır:

- `record_session_payment`: tahsilat kaydeder.
- `void_payment`: tahsilatı iptal edilmiş duruma getirir.
- `refund_payment`: yeni iade kaydı oluşturur.

RPC, kullanıcının üyeliğini ve rolünü yeniden kontrol eder. Staff tahsilat girebilir; yalnızca owner ve admin iptal veya iade yapabilir. RPC ayrıca tutarı, kalan bakiyeyi, kilidi ve idempotency anahtarını tek veritabanı işlemi içinde kontrol eder.

Kısaca RLS okuma sınırını korur, RPC güvenli yazma kurallarını uygular.

## Hangi dosya hangi katmandan sorumlu?

- `lib/features/payments/domain/entities/`: Uygulamanın bildiği ödeme, özet, giriş ve mutasyon sonucu modelleri.
- `lib/features/payments/domain/repositories/payments_repository.dart`: Veri katmanının sunması gereken işlemlerin sözleşmesi.
- `lib/features/payments/data/datasources/payments_remote_data_source.dart`: Supabase RPC çağrılarını yapar.
- `lib/features/payments/data/repositories/payments_repository_impl.dart`: RPC parametrelerini hazırlar ve JSON sonucunu Dart modellerine çevirir.
- `lib/features/payments/presentation/controllers/payments_controller.dart`: Ekran durumunu, yüklemeyi, tekrar denemeyi ve idempotency anahtarını yönetir.
- `lib/features/payments/presentation/widgets/`: Tahsilat formunu, ödeme özetini, durum rozetini ve geçmişi gösterir.
- `lib/features/sessions/presentation/pages/session_detail_page.dart`: Seans tamamlanınca tahsilat ekranını açar ve tamamlanmış seansın ödeme panelini gösterir.
- `lib/features/history/`: Geçmiş listesindeki ödeme durumunu gösterir.
- `lib/features/reports/`: Kesinleşen satış ile tahsilatı ayrı raporlar.
- `lib/core/errors/postgres_error_mapper.dart`: Sunucunun ödeme hata kodlarını güvenli Türkçe hatalara çevirir.
- `supabase/migrations/`: Tabloları, RLS kurallarını, RPC'leri ve rapor fonksiyonlarını tanımlar.

Geçmiş listesi ödeme durumlarını seans başına ayrı özet çağrılarıyla değil,
`get_sessions_payment_status` RPC'sine tek bir toplu çağrıyla alır. Bu hafif sonuç
rozet ve tutarları içerir; ödeme hareketlerinin ayrıntılı listesi yalnızca seans
detayındaki `get_session_payment_summary` çağrısından yüklenir. Yetki nedeniyle
toplu sonuçta bulunmayan bir seans hata oluşturmaz ve ödeme rozeti olmadan
gösterilir.

## Çalışılmış örnek: bölünmüş ödeme

Satış toplamı 450,00 TRY olsun.

1. Müşteri 300,00 TRY nakit öder.
2. Tahsil edilen toplam 300,00 TRY olur.
3. Kalan bakiye 150,00 TRY olur ve durum `partially_paid` olur.
4. Müşteri 150,00 TRY kartla öder.
5. Tahsil edilen toplam 450,00 TRY olur.
6. Kalan bakiye 0,00 TRY olur ve durum `paid` olur.

Hesap:

```text
450,00 satış
- 300,00 nakit
- 150,00 kart
= 0,00 kalan
```

## Çalışılmış örnek: iade

450,00 TRY satışın tamamı ödenmiş olsun. Sonra 100,00 TRY iade edilsin.

```text
450,00 tahsilat
- 100,00 iade
= 350,00 net ödeme
```

Satış toplamı hâlâ 450,00 TRY'dir. Net ödeme 350,00 TRY, kalan bakiye 100,00 TRY olur. Bu nedenle ödeme durumu `partially_paid` olur.
