# ADR 0002 — Ödeme ve Tahsilat Modeli

- **Durum:** Kabul edildi
- **Tarih:** 2026-07-19
- **Bağlam sahibi:** Claude Code (mimari / veritabanı / güvenlik)
- **İlgili:** `docs/contracts/payment-contract.md`,
  `supabase/migrations/20260719120000_payments.sql`

---

## Bağlam

Uygulama bir seansın **satış tutarını** kesinleştiriyordu
(`complete_session` → `sessions.grand_total_minor`) ama paranın fiilen
tahsil edilip edilmediğine dair hiçbir kaydı yoktu.

Bu, işletme için iki farklı sorunun aynı sayıya bakılarak yanıtlanması
demekti:

- "Bugün ne kadar iş yaptım?" → satış
- "Kasada ne kadar para var, kimden alacağım kaldı?" → tahsilat

Bu ikisi gerçek hayatta ayrışır: müşteri kısmen öder, sonra öder, nakit +
kart böler, ya da hiç ödemeden gider.

## Karar

Ödeme yaşam döngüsü, seans yaşam döngüsünden **tamamen ayrı** modellenir.

### 1. `sessions.status` ile ödeme durumu birbirine karıştırılmaz

`completed` yalnızca "hizmet bitti, tutar kesinleşti" demektir.
**Ödendi demek değildir.** Ödeme durumu ayrı türetilir.

*Alternatif (reddedildi):* `sessions` tablosuna `is_paid` / `paid_amount`
kolonu eklemek. Reddedilme nedeni: kısmi ödeme, çok yöntemli ödeme, iade ve
iptal senaryolarında tek kolon yetmiyor; ayrıca aynı gerçeği iki yerde
tutmak (ledger + kolon) tutarsızlık kaynağı olur.

### 2. Ödeme durumu SAKLANMAZ, TÜRETİLİR

`unpaid` / `partially_paid` / `paid`, her sorguda
`payment_allocations` + `payments` üzerinden hesaplanır.

*Neden:* Tek doğruluk kaynağı ledger'dır. Denormalize bir durum kolonu,
iade veya iptal sonrası güncellenmeyi unutursa **sessizce yanlış** olur —
finansal veride en tehlikeli hata tipi budur.

*Ödün:* Her okumada bir toplama (aggregate) maliyeti. Kabul edildi, çünkü
seans başına ödeme sayısı tek haneli ve `(session_id)` indeksi mevcut.
Ölçüm gerektiğinde v2'de materialized view değerlendirilebilir.

### 3. Ödeme, seansa doğrudan değil `payment_allocations` üzerinden bağlanır

*Neden:* Bugün bir ödeme tek seansa gidiyor. Ama "müşteri üç seansın
borcunu tek seferde ödedi" senaryosu gerçek ve yakın. Araya tahsis tablosu
koymak bunu **şema değişikliği olmadan** mümkün kılar.

*Ödün:* v1 için bir seviye fazladan join. Kabul edildi.

### 4. Fiziksel silme yok — iptal durum değişimi, iade yeni kayıt

- Yanlış tahsilat → `status = 'voided'` + gerekçe + denetim olayı
- Para iadesi → **yeni** `refund` kaydı, orijinal dokunulmaz

*Neden:* Finansal kayıt denetlenebilir olmalıdır. "Ne olduğu" kadar "ne
olmuştu ve kim değiştirdi" da saklanmalıdır. `inventory_movements`
ledger'ında alınan aynı karar burada da uygulanır.

### 5. Tutar her zaman pozitif; yönü `payment_kind` taşır

İade kayıtlarında da `amount_minor > 0`.

*Neden:* `> 0` invariantı istisnasız kalır. Negatif tutarlı "tahsilat" gibi
anlamsız satırlar veritabanı seviyesinde imkansızlaşır. İşareti okuyan
tarafın yorumlaması yerine, yön ayrı ve açık bir kolonda durur.

### 6. Aşırı ödeme ve eşzamanlılık koruması sunucudadır

`record_session_payment` seansı `for update` ile kilitler, kalan bakiyeyi
**kilidin altında yeniden hesaplar**, sonra kabul/ret verir.

*Neden:* İstemci bakiyeyi bilse bile ona güvenilemez. İki cihaz aynı anda
ödeme girerse biri bekler ve güncel bakiyeyi görür.

*Kanıt:* `supabase/tests/payment_concurrency_test.sh` iki gerçek bağlantıyla
bunu doğrular (ikinci ödeme `payment_exceeds_balance` alır, toplam aşılmaz).

### 7. Idempotency işletme başına tekil anahtarla

`unique (business_id, idempotency_key)`. Tekrar isteği yeni kayıt açmaz,
mevcut sonucu `replayed: true` ile döndürür. Tam eşzamanlı çakışmada
`unique_violation` yakalanır ve yine tek ödeme kalır.

*Neden:* Mobilde ağ kopması ve kullanıcının tekrar basması olağandır.
Çift tahsilat kabul edilemez.

### 8. Tahsil eden kişi ad olarak DÖNDÜRÜLMEZ

`business_members` tablosunda ad kolonu yok; tek kimlik `auth.users.email`.
E-postayı ödeme geçmişinde döndürmek yeni bir PII sızıntısı olurdu.
Bunun yerine opak `received_by_member_id` + sunucuda hesaplanan
`received_by_me` (bool) döner.

*Sonuç:* Arayüz "Sen" / "Ekip üyesi" ayrımı yapabilir. Gerçek ad gösterimi
istenirse, üye profili ayrı bir iş olarak ele alınmalıdır.

### 9. Yazma yalnızca RPC üzerinden

Ödeme tablolarına hiçbir role `INSERT/UPDATE/DELETE` verilmez; RLS'te de
yalnızca `SELECT` politikası tanımlanır. Politika yokluğu = deny
(fail-closed).

*Neden:* Tutar, bakiye, üye kimliği ve zaman damgası sunucuda türetilmeli.
İstemciye açık bir yazma yolu bırakmak bu güvenceyi tamamen geçersiz kılar.

## Sonuçlar

**Olumlu**

- Satış ve tahsilat raporda ayrı ayrı doğru okunur
- Kısmi ve çok yöntemli ödeme doğal olarak desteklenir
- Her finansal değişiklik denetlenebilir
- Aşırı ödeme ve çift ödeme sunucuda imkansız
- Tenant izolasyonu composite FK ile veritabanı seviyesinde

**Olumsuz / kabul edilen ödünler**

- Ödeme durumu her okumada hesaplanır (indeksle hafifletildi)
- Tahsis tablosu v1 için fazladan bir join
- Ödeme geçmişinde kişi adı gösterilemez (profil özelliği gerektirir)

## Bilinen sınırlar (v1 kapsamı dışı)

- **İade kayıtları iptal edilemez.** Yanlış girilen bir iadenin düzeltmesi
  ele alınmadı; `payment_kind_not_voidable` ile açıkça reddedilir.
- **Bir ödeme birden çok seansa tahsis edilemez.** Şema destekliyor, RPC
  henüz tek seans yazıyor.
- **Tamamlanmamış seans ödenemez.** Ön ödeme/kapora senaryosu kapsam dışı.
- Gerçek kart işleme, banka/POS entegrasyonu, e-fatura kapsam dışıdır;
  bu modül dışarıda alınmış parayı yalnızca **kaydeder**.
