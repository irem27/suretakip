# Ödeme ve Tahsilat Kontratı (v1)

> Sahibi: Claude Code (mimari, veritabanı, yetkilendirme, işlem güvenliği)
> Tüketici: Codex (Flutter veri katmanı, controller, UI)
> Durum: Faz 1 — Flutter veri katmanı implementasyonu bu kontrata karşı yazılır.
> Migration: `supabase/migrations/20260719120000_payments.sql`

---

## 1. Neden bu modül var

Uygulama bugün bir seansın **satış tutarını** hesaplıyor ve kesinleştiriyor,
ama **paranın tahsil edilip edilmediğini** kaydetmiyor.

Bu iki şey aynı değildir:

| Kavram | Anlamı | Nerede tutulur |
|---|---|---|
| Satış tutarı | "Müşteri 450,00 ₺ borçlandı" | `sessions.grand_total_minor` |
| Tahsilat | "300,00 ₺ nakit + 150,00 ₺ kart alındı" | `payments` + `payment_allocations` |

**Tamamlanmış bir seans, ödenmiş demek değildir.** Seans yaşam döngüsü
(`sessions.status`) ile ödeme yaşam döngüsü birbirinden bağımsızdır ve
bilinçli olarak ayrı tutulur.

Bu modül dışarıda (nakit, POS, havale) alınmış parayı **kaydeder**. Gerçek
kart işleme, banka entegrasyonu, Stripe/iyzico/PayTR **kapsam dışıdır**.

---

## 2. Para ve para birimi kuralları

- Tüm tutarlar **tam sayı, en küçük birim (kuruş)**: PostgreSQL `bigint`, Dart `int`.
- Kayan noktalı sayı **hiçbir katmanda** kullanılmaz.
- `currency_code` ISO 4217, `^[A-Z]{3}$` check'i ile zorlanır.
- Bir ödemenin para birimi, ödendiği seansın `currency_code_snapshot` değeriyle
  **her zaman aynıdır**: istemci para birimi göndermez, RPC bu değeri seanstan
  kopyalar. Uyuşmazlık yapısal olarak imkansız olduğu için çalışma zamanı
  kontrolü ve buna karşılık gelen bir hata kodu **yoktur** (bkz. §7.1 notu).
- Flutter tarafında mevcut `Money` value object'i yeniden kullanılır; yeni bir
  para ayrıştırma/biçimlendirme kodu yazılmaz.

---

## 3. Enum'lar

```sql
create type public.payment_method as enum ('cash', 'card', 'bank_transfer', 'other');
create type public.payment_kind   as enum ('collection', 'refund');
create type public.payment_status as enum ('completed', 'voided');
```

Ödeme durumu (`payment_status`) **tek bir ödeme kaydının** durumudur.
Seansın ödeme durumu ayrı bir kavramdır (bkz. §6) ve **türetilir, saklanmaz**.

---

## 4. Tablolar

### 4.1 `payments`

| Kolon | Tip | Not |
|---|---|---|
| `id` | uuid pk | |
| `business_id` | uuid not null | → `businesses(id)` on delete restrict |
| `customer_id` | uuid null | composite FK `(customer_id, business_id)` |
| `payment_kind` | payment_kind not null | `collection` \| `refund` |
| `payment_method` | payment_method not null | |
| `status` | payment_status not null default `completed` | |
| `amount_minor` | bigint not null | **`> 0` her zaman** (iade de pozitif yazılır) |
| `currency_code` | text not null | `^[A-Z]{3}$` |
| `original_payment_id` | uuid null | iade → orijinal tahsilat, composite FK |
| `idempotency_key` | text not null | |
| `external_reference` | text null | POS fiş no, havale dekont no vb. |
| `note` | text null | |
| `received_by_member_id` | uuid not null | composite FK |
| `received_at` | timestamptz not null default now() | |
| `voided_by_member_id` | uuid null | |
| `voided_at` | timestamptz null | |
| `void_reason` | text null | |
| `created_at` / `updated_at` | timestamptz not null | |

**Kısıtlar:**

- `unique (id, business_id)` — composite FK hedefi olabilmesi için.
- `unique (business_id, idempotency_key)` — idempotency işletme içinde tekil.
- `chk_payment_amount_positive`: `amount_minor > 0`
- `chk_refund_has_original`:
  `payment_kind = 'refund'` ⇒ `original_payment_id is not null`
  `payment_kind = 'collection'` ⇒ `original_payment_id is null`
- `chk_void_fields`:
  `status = 'voided'` ⇒ `voided_by_member_id`, `voided_at`, `void_reason` **hepsi dolu**
  `status = 'completed'` ⇒ **hepsi null**

**İndeksler:** `(business_id, received_at desc)`, `(business_id, status)`,
`(original_payment_id)`.

> **Neden `amount_minor` iadede de pozitif?** İşaret taşımak yerine yönü
> `payment_kind` taşır. Böylece `> 0` invariantı tek ve istisnasız kalır;
> "negatif tahsilat" gibi anlamsız kayıtlar DB seviyesinde imkansızlaşır.

### 4.2 `payment_allocations`

Bir ödemenin hangi seans(lar)a mahsup edildiğini tutar.

| Kolon | Tip | Not |
|---|---|---|
| `id` | uuid pk | |
| `business_id` | uuid not null | |
| `payment_id` | uuid not null | composite FK `(payment_id, business_id)` |
| `session_id` | uuid not null | composite FK `(session_id, business_id)` |
| `amount_minor` | bigint not null check `> 0` | |
| `created_at` | timestamptz not null | |

- `unique (id, business_id)`
- İndeks: `(session_id)`, `(payment_id)`

> **Neden ayrı tablo?** v1'de bir ödeme tek seansa mahsup edilir. Ayrı tablo
> olması, ileride tek ödemenin birden çok seansa bölünmesini **şema
> değişikliği olmadan** mümkün kılar. Ayrıca "seans başına net tahsilat"
> sorgusu tek yerden, tutarlı biçimde yapılır.

### 4.3 `payment_events` (append-only denetim)

| Kolon | Tip | Not |
|---|---|---|
| `id` | uuid pk | |
| `business_id` | uuid not null | |
| `payment_id` | uuid not null | composite FK |
| `event_type` | text not null | `payment_recorded` \| `payment_voided` \| `payment_refunded` |
| `actor_member_id` | uuid not null | composite FK |
| `reason` | text null | iptal/iade gerekçesi |
| `details` | jsonb null | önceki/sonraki durum |
| `created_at` | timestamptz not null | |

**Hiçbir role UPDATE/DELETE yetkisi verilmez.** `inventory_movements`
ledger'ıyla aynı desen.

### 4.4 Çapraz işletme güvenliği

Tüm çocuk referanslar **composite FK** `(x_id, business_id)` ile kurulur —
mevcut şemanın deseni aynen sürdürülür. Sonuç: başka işletmenin müşterisine,
seansına, personeline veya ödemesine bağlı bir kayıt **veritabanı seviyesinde
imkansızdır**; uygulama hatası bunu delemez.

---

## 5. Fiziksel silme yoktur

`payments`, `payment_allocations`, `payment_events` kayıtları **asla silinmez**.

- Yanlış tahsilat → `void_payment` (durum `voided`, kayıt durur, denetim yazılır)
- Para iadesi → `refund_payment` (**yeni** bir `refund` kaydı, orijinal dokunulmaz)

---

## 6. Seansın ödeme durumu — türetme kuralı

Saklanmaz, sorgu anında hesaplanır (v1 kararı; bkz. ADR).

```
collected_minor = Σ allocation.amount_minor
                  WHERE payment.payment_kind = 'collection'
                    AND payment.status = 'completed'

refunded_minor  = Σ allocation.amount_minor
                  WHERE payment.payment_kind = 'refund'
                    AND payment.status = 'completed'

net_paid_minor  = collected_minor - refunded_minor
remaining_minor = GREATEST(0, session_total_minor - net_paid_minor)
```

`status = 'voided'` olan ödemeler **hiçbir toplama girmez**.

| Koşul | `payment_status` |
|---|---|
| `net_paid_minor = 0` | `unpaid` |
| `0 < net_paid_minor < session_total_minor` | `partially_paid` |
| `net_paid_minor >= session_total_minor` | `paid` |

**`remaining_minor` asla negatif olmaz** (`GREATEST(0, …)`).

Örnek (brief'teki senaryo):
- 450,00 ₺ satış → 300,00 ₺ nakit + 150,00 ₺ kart → net 450,00 → **paid**
- Sonra 100,00 ₺ iade → net 350,00 → **partially_paid**, kalan 100,00 ₺

---

## 7. RPC'ler

Hepsi `security definer`, `set search_path = ''`, şema-nitelikli.
`authenticated` rolüne yalnızca aşağıdaki fonksiyonlar için `execute` verilir.

### 7.1 `record_session_payment`

```sql
public.record_session_payment(
  p_session_id          uuid,
  p_payment_method      public.payment_method,
  p_amount_minor        bigint,
  p_idempotency_key     text,
  p_external_reference  text default null,
  p_note                text default null
) returns jsonb
```

**Kurallar (sırayla):**

1. `p_idempotency_key` boş olamaz → `payment_idempotency_key_required`
2. `p_amount_minor > 0` değilse → `payment_amount_invalid`
3. Seans `FOR UPDATE` ile kilitlenir → `session_not_found`
4. Çağıran aktif üye olmalı → `not_a_member`
5. **Idempotency kontrolü — kilidin ALTINDA:** `(business_id, idempotency_key)`
   zaten varsa yeni kayıt açılmaz, mevcut sonuç `"replayed": true` ile döner.
6. Seans `status = 'completed'` olmalı → aksi halde `session_not_payable`
   (`active`, `paused`, `draft`, `cancelled` reddedilir)
7. **Kilit altında** `remaining_minor` yeniden hesaplanır;
   `p_amount_minor > remaining_minor` ise → `payment_exceeds_balance`
8. `payments` + `payment_allocations` + `payment_events(payment_recorded)`
   **tek transaction**'da yazılır.

> **Sıra neden böyle?** Idempotency kontrolü kilitten ÖNCE yapılırsa, aynı
> anahtarla gelen iki eşzamanlı istek kontrolü birlikte geçip ikisi de
> ilerleyebilir. Seans kilidi önce alındığında ikinci istek bekler ve
> birincinin commit ettiği kaydı görür. Kilit hem aşırı ödemeyi hem çift
> ödemeyi aynı noktada seri hale getirir.

> **Para birimi neden kontrol edilmiyor?** İstemci para birimi göndermez;
> RPC ödemenin `currency_code`'unu doğrudan `sessions.currency_code_snapshot`
> alanından yazar. Uyuşmazlık **yapısal olarak imkansızdır**, bu yüzden
> çalışma zamanı kontrolü ve `payment_currency_mismatch` hata kodu **yoktur**.
> (İnşa ile garanti etmek, kontrol ile yakalamaktan üstündür.)

**Eşzamanlılık:** 4. adımdaki `FOR UPDATE` seri hale getirir. İki cihaz aynı
anda ödeme girerse biri bekler, sonra bakiyeyi **yeniden okur** ve aşım varsa
reddedilir. Toplam tahsilat bakiyeyi asla aşamaz.

**Yarış durumu:** Aynı idempotency key ile eşzamanlı iki istek gelirse unique
constraint tetiklenir; `unique_violation` yakalanır ve mevcut kayıt döner.
Sonuç: **tek ödeme**.

**Yetki:** `owner`, `admin`, `staff` — hepsi tahsilat girebilir.

### 7.2 `get_session_payment_summary`

```sql
public.get_session_payment_summary(p_session_id uuid) returns jsonb
```

Aktif üyelik + tenant izolasyonu zorunlu. Özet + güvenli ödeme geçmişi döner.

**Yetki:** `owner`, `admin`, `staff`.

### 7.3 `void_payment`

```sql
public.void_payment(p_payment_id uuid, p_reason text) returns jsonb
```

- Yalnızca `owner` / `admin` → aksi halde `not_authorized`
- `p_reason` boş olamaz → `payment_reason_required`
- Yalnızca `payment_kind = 'collection'` iptal edilebilir → aksi `payment_kind_not_voidable`
- Zaten `voided` ise → `payment_already_voided` (kararlı domain hatası)
- Kayıt **silinmez**: `status = 'voided'` + `voided_by/at/reason` yazılır
- İptal edilen tahsilat net toplamlardan **çıkar**
- `payment_events(payment_voided)` yazılır

> **v1 sınırı:** İade kayıtları iptal edilemez. Yanlış iade düzeltmesi
> kapsam dışıdır ve ADR'de bilinen sınır olarak kayıtlıdır.

### 7.4 `refund_payment`

```sql
public.refund_payment(
  p_payment_id      uuid,
  p_amount_minor    bigint,
  p_idempotency_key text,
  p_reason          text
) returns jsonb
```

- Yalnızca `owner` / `admin` → `not_authorized`
- Kısmi ve tam iade desteklenir
- Orijinal ödeme `FOR UPDATE` ile kilitlenir
- Orijinal `completed` bir `collection` olmalı
- **İade edilebilir tutar:**
  `refundable = original.amount_minor - Σ(o ödemeye bağlı completed iadeler)`
  `p_amount_minor > refundable` ise → `refund_exceeds_refundable`
- **Yeni** `refund` kaydı açılır (`original_payment_id` dolu), orijinal
  kayıt **değiştirilmez / silinmez**
- Aynı seansa `payment_allocations` satırı + `payment_events(payment_refunded)`
- **Ayrı** idempotency key zorunlu

---

## 8. RPC dönüş şekli (Flutter'a giden JSON)

Tüm dört RPC aynı zarfı döner:

```json
{
  "session_id": "uuid",
  "currency_code": "TRY",
  "session_total_minor": 45000,
  "collected_minor": 45000,
  "refunded_minor": 10000,
  "net_paid_minor": 35000,
  "remaining_minor": 10000,
  "payment_status": "partially_paid",
  "payments": [
    {
      "id": "uuid",
      "payment_kind": "collection",
      "payment_method": "cash",
      "status": "completed",
      "amount_minor": 30000,
      "currency_code": "TRY",
      "original_payment_id": null,
      "external_reference": null,
      "note": null,
      "received_by_member_id": "uuid",
      "received_by_me": true,
      "received_at": "2026-07-19T09:12:44.000Z",
      "voided_by_member_id": null,
      "voided_at": null,
      "void_reason": null
    }
  ]
}
```

`record_session_payment` ve `refund_payment` ek olarak döner:

```json
{ "payment_id": "uuid", "replayed": false }
```

`void_payment` ek olarak döner:

```json
{ "payment_id": "uuid" }
```

**Alan adları yukarıdaki gibi `snake_case`'dir.** Flutter mapper'ı birebir bu
adları okur. `payments` dizisi `received_at` **artan** sırada gelir.

**Sızdırılmayan alanlar:** `user_id`, e-posta, JWT claim'i veya başka
kullanıcıya ait kimlik bilgisi dönmez.

> **Tahsil eden kişi neden isim değil?** `business_members` tablosunda ad
> kolonu **yoktur**; tek kimlik kaynağı `auth.users.email`'dir ve onu ödeme
> geçmişinde döndürmek yeni bir PII sızıntısı olurdu. Bir üye profili/ad
> özelliği eklemek bu modülün kapsamı dışındadır. Bu yüzden kontrat
> `received_by_member_id` (opak) ve sunucuda hesaplanan `received_by_me`
> (bool) döndürür. Arayüz "Sen" / "Ekip üyesi" ayrımını bununla yapar.
> Üye adlarını göstermek istenirse ayrı bir iş olarak profil alanı eklenmeli.

---

## 9. Hata kodları

`raise exception '<kod>'` ile atılır (mevcut desen). Flutter tarafı
`lib/core/errors/postgres_error_mapper.dart` içinde eşler.

| Kod | Anlamı | Önerilen Flutter tipi |
|---|---|---|
| `payment_amount_invalid` | Tutar ≤ 0 | `ValidationException` |
| `payment_idempotency_key_required` | Key boş | `ValidationException` |
| `payment_idempotency_key_reused` | Anahtar **başka** bir seans/ödeme için kullanılmış | `ConflictException` |
| `payment_reason_required` | İptal/iade gerekçesi boş | `ValidationException` |
| `payment_exceeds_balance` | Kalan bakiye aşılıyor | `ConflictException` |
| `refund_exceeds_refundable` | İade edilebilir tutar aşılıyor | `ConflictException` |
| `payment_already_voided` | Zaten iptal edilmiş | `ConflictException` |
| `payment_kind_not_voidable` | İade kaydı iptal edilemez | `ValidationException` |
| `session_not_payable` | Seans tamamlanmış değil | `ConflictException` |
| `payment_not_found` | Ödeme yok / başka tenant | `NotFoundException` |
| `session_not_found` | *(mevcut)* | `NotFoundException` |
| `not_a_member` | *(mevcut)* | `AuthorizationException` |
| `not_authorized` | *(mevcut)* staff iptal/iade denedi | `AuthorizationException` |

Kullanıcıya gösterilen mesajlar **Türkçe** olmalıdır.

---

## 10. Yetki matrisi

| İşlem | owner | admin | staff | üye olmayan |
|---|:---:|:---:|:---:|:---:|
| Ödeme özetini okuma | ✅ | ✅ | ✅ | ❌ |
| Tahsilat kaydetme | ✅ | ✅ | ✅ | ❌ |
| Ödeme iptali (void) | ✅ | ✅ | ❌ | ❌ |
| Para iadesi (refund) | ✅ | ✅ | ❌ | ❌ |
| Tabloya doğrudan INSERT/UPDATE/DELETE | ❌ | ❌ | ❌ | ❌ |

**Hiç kimse** — owner dahil — ödeme tablolarına doğrudan yazamaz.
Tüm mutasyonlar RPC üzerinden geçer.

---

## 11. RLS ve GRANT

```
GRANT SELECT on payments, payment_allocations, payment_events → authenticated
GRANT INSERT/UPDATE/DELETE → HİÇBİRİ (kasıtlı)
```

RLS politikası (üçü de): `select` → `public.is_business_member(business_id)`

`insert` / `update` / `delete` politikası **yoktur** → RLS varsayılanı deny.
Fail-closed: politika unutulursa erişim açılmaz, kapanır.

---

## 12. İstemciye güvenilmeyen değerler

Aşağıdakiler **asla** istemciden alınmaz; sunucu türetir:

`business_id`, `user_id`, `member_id`, rol, seans toplamı, kalan bakiye,
tahsil edilen tutar, ödeme durumu, `received_at`, `voided_at`.

İstemciden gelen tek şeyler: `session_id` / `payment_id`, ödeme yöntemi,
tutar, idempotency key, opsiyonel referans ve not, iptal/iade gerekçesi.

---

## 13. Raporlama

**Satış ≠ tahsilat.** Mevcut ciro raporları "kesinleşmiş satış" anlamını
korur; tahsilat ayrı alanlarda döner. Rapor RPC'si (Claude Code sahipliğinde)
işletme saat dilimini kullanmaya devam eder ve şunları ekler:

| Alan | Anlamı |
|---|---|
| `finalized_sales_minor` | Kesinleşmiş satış toplamı (mevcut anlam, değişmedi) |
| `net_collected_minor` | Net tahsilat (iptal/iade düşülmüş) |
| `cash_collected_minor` | Nakit |
| `card_collected_minor` | Kart |
| `bank_transfer_collected_minor` | Havale/EFT |
| `other_collected_minor` | Diğer |
| `refunded_minor` | Toplam iade |
| `outstanding_minor` | Tahsil edilmemiş bakiye (unpaid + partially_paid) |

---

## 14. Flutter tarafı beklenen yapı (Codex sahipliğinde)

```
lib/features/payments/
  domain/entities/      Payment, SessionPaymentSummary, PaymentInput, RefundInput
  domain/repositories/  PaymentsRepository
  data/datasources/     PaymentsRemoteDataSource  (RPC çağrıları)
  data/repositories/    PaymentsRepositoryImpl    (_guard + hata eşleme)
  presentation/controllers/
  presentation/pages|widgets/
```

Repository işlemleri:

```dart
Future<SessionPaymentSummary> getSessionPaymentSummary(String sessionId);
Future<PaymentMutationResult> recordSessionPayment(PaymentInput input);
Future<PaymentMutationResult> voidPayment({required String paymentId, required String reason});
Future<PaymentMutationResult> refundPayment(RefundInput input);
```

> **`PaymentAllocation` entity'si YOKTUR.** Tahsis kaydı veritabanı tarafında
> bir kavramdır; v1'de ödeme başına tek satırdır ve JSON zarfında
> döndürülmez. Flutter tarafında karşılığı olmayan bir entity üretilmez.

`PaymentMutationResult`, özetin yanında mutasyon meta verisini taşır:

```dart
class PaymentMutationResult {
  final SessionPaymentSummary summary;
  final String paymentId;
  final bool replayed;   // true => bu istek tekrar oynatıldı, YENİ ödeme oluşmadı
}
```

> **`replayed` neden dışarı açılıyor?** Ağ koptuğunda kullanıcı tekrar
> basar. Sunucu doğru davranıp tek ödeme tutar, ama arayüz bunu bilmezse
> "Tahsilat kaydedildi" mesajını ikinci kez gösterip kullanıcıya iki ödeme
> girmiş hissi verir. `replayed = true` geldiğinde arayüz "Bu tahsilat
> zaten kaydedilmişti" demelidir.
>
> `void_payment` için `replayed` her zaman `false` döner (o RPC idempotency
> anahtarı kullanmaz); alan yine de tek tip zarf için mevcuttur.

**Idempotency key üretimi Flutter'ın sorumluluğudur:** kullanıcı "Tahsil et"
niyetini oluşturduğunda **bir kez** üretilir (`uuid` paketi zaten bağımlılıkta)
ve **aynı niyetin tüm yeniden denemelerinde aynısı** kullanılır. Yeni bir
ödeme niyeti = yeni key.

> **Sunucu bunu ayrıca zorlar.** Bir anahtar başka bir seans (veya iadede
> başka bir orijinal ödeme) için yeniden kullanılırsa
> `payment_idempotency_key_reused` atılır. Bu guard olmadan istek
> "başarılı + `replayed: true`" dönüyor ama ikinci seans **hiç ödenmiyordu** —
> arayüz tahsil edildi sanıyor, kayıt yok, para sessizce kayboluyordu.
> İstemcinin doğru davranacağına güvenilmez.

---

## 15. Kabul kriterleri (bu kontrat için)

- [ ] Tamamlanmış seans ödenmemiş kalabilir
- [ ] Tek seansa birden çok yöntemle ödeme yapılabilir
- [ ] Kısmi ödeme desteklenir
- [ ] Aşırı ödeme **sunucuda** engellenir
- [ ] Aynı idempotency key tek ödeme üretir
- [ ] Eşzamanlı cihazlar bakiyeyi aşamaz
- [ ] Staff tahsil eder, iptal/iade edemez
- [ ] Owner/admin iptal ve iade eder, denetim kaydı oluşur
- [ ] Hiçbir ödeme kaydı fiziksel silinmez
- [ ] Tenant izolasyonu SQL testleriyle kanıtlanır
- [ ] Satış ve tahsilat raporda ayrı durur
