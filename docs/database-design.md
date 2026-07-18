# Veritabanı Tasarımı (v2 — Production Modeli)

> Migration'lar: `supabase/migrations/20260717130000..130200`
> Test paketi: `supabase/tests/rls_test.sql` (20 senaryo)
> Bu doküman `architecture.md`'nin veri katmanı bölümünün yerini alır; oradaki
> `numeric(12,2)` para modeli ve `owner/manager/employee` rolleri **güncel değildir**.

## 1. Tasarım Kararları ve Varsayımlar

| Karar | Seçim | Neden |
|-------|-------|-------|
| Para | En küçük birim (kuruş) `bigint` + ISO 4217 `currency_code` | Float yuvarlama hatası imkansız; toplama/çarpma tam sayı aritmetiği |
| Silme | Fiziksel silme yok: `is_active` + `archived_at`; FK'ler `on delete restrict` | Finansal geçmiş korunur; DELETE grant'i çoğu tabloda hiç yok |
| Zaman takibi | `session_time_entries` ledger'ı (aralık kayıtları) | Denetlenebilir; pause/resume geçmişi kaybolmaz; süre `sum(active aralıklar)` |
| Yuvarlama | `charged_minutes = max(ceil(aktif_dk / interval) * interval, minimum_charge)` | Faturalamada standart yukarı yuvarlama (varsayım) |
| Stok | `inventory_movements` ledger (kaynak) + `products.stock_quantity` cache | Liste/stok sorguları tek kolon okur; cache'e yalnızca trigger yazar, her ledger insert'i aynı transaction'da cache'i günceller; `check (stock >= 0)` eşzamanlılıkta bile negatif stoğu engeller |
| Aynı ürün tekrar | `UNIQUE(session_id, product_id)` YOK — ayrı satırlar | Farklı fiyat/indirim senaryoları desteklenir (spec varsayılanı) |
| Roller | `owner / admin / staff` | Spec gereği; eski dokümandaki manager/employee adlandırması kaldırıldı |
| Tenant bütünlüğü | Composite FK: `(customer_id, business_id) → customers(id, business_id)` vb. | "Seansın müşterisi başka işletmeden" durumu DB seviyesinde imkansız; trigger'a gerek kalmaz, index destekli |
| Seans yaşam döngüsü | Yalnızca RPC (tablolara insert/update grant'i yok; `sessions`'ta yalnız `notes, customer_id` kolonları güncellenebilir) | Status makinesi ve finansal alanlar client'tan bozulamazsın |
| Movement kaydı | Yalnızca `track_stock = true` ürünlerde yazılır | Ledger stok yönetilen ürünleri izler (varsayım) |
| `draft` status | Enum'da var, şu an RPC üretmiyor | İleride "hazırlık" akışı için rezerve |

## 2. ER Diyagramı

```mermaid
erDiagram
  businesses ||--o{ business_members : "üyeler"
  businesses ||--o{ customers : ""
  businesses ||--o{ services : ""
  businesses ||--o{ products : ""
  businesses ||--o{ sessions : ""
  customers |o--o{ sessions : "opsiyonel (NULL=misafir)"
  services ||--o{ sessions : "snapshot ile"
  business_members ||--o{ sessions : "opened_by / closed_by"
  sessions ||--o{ session_time_entries : "zaman ledger'ı"
  sessions ||--o{ session_items : "satış satırları"
  products |o--o{ session_items : "snapshot ile"
  products ||--o{ inventory_movements : "stok ledger'ı"
  session_items |o--o| inventory_movements : "sale / sale_reversal"
```

## 3. RPC Kataloğu

| Fonksiyon | Ne yapar | Kritik guard |
|-----------|----------|--------------|
| ~~`create_business_with_owner(name, currency, tz)`~~ **KALDIRILDI** *(20260718090100)* | — | Hizmetsiz işletme üretebiliyordu: kullanıcı onboarding'i atlayıp bu RPC'yi çağırınca `start_session` imkansız hale gelen kilitli bir hesapla kalıyordu. Yerine `complete_onboarding` |
| `add_business_member` / `update_business_member_role` / `set_business_member_active` / `remove_business_member` / `transfer_business_ownership` *(eklendi: 2026-07-18)* | Üyelik mutasyonlarının tek yolu | `business_members`'a doğrudan insert/update/delete grant'i YOK. Her çağrıda çağıranın rolü sunucuda doğrulanır; admin owner satırına dokunamaz ve kimseyi owner yapamaz; **son aktif owner silinemez/pasifleştirilemez/rolü düşürülemez**. Eşzamanlılık `businesses` satırı `FOR UPDATE` ile serileştirilir |
| `complete_onboarding(...)` *(eklendi: 2026-07-17)* | İşletme + owner + zorunlu ilk hizmet + opsiyonel ürün (tek tx) | Hizmetsiz işletme imkansız; herhangi bir adım başarısızsa hepsi rollback. Uygulama onboarding'de bunu kullanır |
| `create_product_with_stock(...)` *(eklendi: 2026-07-17)* | Ürün + varsa ilk stok (tek tx) | İlk stok cache'e değil `inventory_movements`'a `initial` olarak yazılır; cache'i trigger günceller. owner/admin yetkisi. Ürün CRUD create'i bunu kullanır — stok cache'i asla doğrudan yazılmaz |
| `report_revenue_summary` / `report_top_services` / `report_top_products` / `report_top_customers` / `dashboard_metrics` *(eklendi: 2026-07-17)* | Raporlar SUNUCU TARAFINDA aggregate edilir | İşletme saat dilimine göre dönemler (DST dahil), yalnız `completed` seanslar gelire girer, tüm tutarlar minor bigint, `is_business_member` kontrolü. **Uygulama raporları/dashboard'u bu RPC'lerden okur — client'ta toplama yapmaz** (kesme/eksik gelir yok) |
| `start_session(business, service, customer?, notes?)` | Snapshot'lı seans + ilk active aralık | Üyelik, hizmet/müşteri aynı işletmede ve aktif |
| `pause_session(session)` | Açık aralığı kapat, paused aralık aç | `status='active'` şartı → çifte pause imkansız |
| `resume_session(session)` | Paused kapat, active aç | `status='paused'` şartı |
| `add_product_to_session(session, product, qty, discount?, tax?)` | Snapshot'lı satır + sale movement | Ürün `FOR UPDATE` kilidi, stok kontrolü, currency eşleşmesi |
| `complete_session(session, discount?, tax?)` | Süre→ücret hesabı, toplamlar, `completed` | `FOR UPDATE` + status şartı → çifte tamamlama imkansız |
| `cancel_session(session)` | Stok iadesi + `cancelled` | Tamamlanmışı yalnız owner/admin iptal eder; iade satır başına 1 kez (partial unique + on conflict) |

## 4. Örnek Kullanım

```sql
-- Onboarding'in tek kapısı (işletme + owner + ZORUNLU ilk hizmet, tek tx):
select complete_onboarding(
  'Berber Ali', 'TRY', 'Europe/Istanbul',
  'Koltuk', 250, 15, 10                                                     -- → business_id
);
select start_session(:business_id, :service_id);                            -- misafir seans
select start_session(:business_id, :service_id, :customer_id, 'VIP');
select pause_session(:session_id);
select resume_session(:session_id);
select add_product_to_session(:session_id, :product_id, 2, 500);            -- 2 adet, 500 minor indirim
select complete_session(:session_id, 0, 2000);                              -- 2000 minor vergi
select cancel_session(:session_id);

-- Seansın gerçek aktif süresi (saniye):
select coalesce(sum(extract(epoch from coalesce(ended_at, now()) - started_at)), 0)
from session_time_entries
where session_id = :session_id and entry_type = 'active';

-- Elle stok girişi (yalnız owner/admin). Stok DAİMA ledger üzerinden girilir;
-- products.stock_quantity'ye doğrudan UPDATE yetkisi yoktur (20260718090000).
insert into inventory_movements (business_id, product_id, movement_type, quantity_delta, note)
values (:business_id, :product_id, 'restock', 24, 'yeni koli');

-- Üyelik yönetimi (doğrudan tablo yazma yetkisi yok):
select add_business_member(:business_id, :user_id, 'staff');
select update_business_member_role(:member_id, 'admin');
select set_business_member_active(:member_id, false);
select transfer_business_ownership(:business_id, :to_member_id);
```

## 5. Kritik Edge Case'ler

1. **Eşzamanlı satış:** İki cihaz aynı anda son stoğu satarsa: `FOR UPDATE` kilidi sıralar, geç gelen `insufficient_stock` alır. Kilit atlansa bile `check (stock_quantity >= 0)` ikinci düşümü DB'de patlatır → rollback.
2. **Çifte tamamlama/iptal:** `FOR UPDATE` + status kontrolü; iade ayrıca `uq_inventory_item_movement` partial unique ile korunur.
3. **Uygulama çökmesi:** Süre `started_at`/aralıklardan türetilir (server saati); client timer yalnızca görsel.
4. **Fiyat/ad/para birimi değişimi:** Geçmiş seans snapshot kolonlarından okur — test 14 bunu doğrular.
5. **Admin yetki yükseltmesi:** Admin, owner satırı oluşturamaz/değiştiremez/silemez (policy'de `role <> 'owner'` guard'ı).
6. **Currency karışması:** `add_product_to_session` ürün para birimini seans snapshot'ıyla karşılaştırır → `currency_mismatch`.
7. **Müşteri partial unique önerisi (uygulanmadı):** Aynı işletmede e-posta tekilliği istenirse: `create unique index on customers (business_id, lower(email)) where email is not null;` — telefon paylaşan aile müşterileri gibi gerçek hayat durumları yüzünden şimdilik zorlanmadı.

## 6. Rollback Notları

- Supabase migration'ları ileri yönlüdür; geri almak için **ters migration yazılır** (down script otomatik değildir).
- Bu üç migration henüz hiçbir ortama deploy edilmediyse en güvenli yol: dosyayı düzeltip `supabase db reset` (yalnızca lokalde!).
- Production'a çıktıktan sonra: enum'a değer eklemek kolay (`alter type ... add value`), çıkarmak pratikte imkansız — enum değişikliklerini önden iyi düşün.
- `drop table` sırası FK zinciriyle terstir: inventory_movements → session_items → session_time_entries → sessions → products/services/customers → business_members → businesses.
- `supabase db reset` production'da ASLA çalıştırılmaz; lokal geliştirme komutudur.

## 7. Test Paketi

`supabase/tests/rls_test.sql` — **51 senaryo**: tenant izolasyonu, rol matrisi, RPC durum makinesi, stok ledger/cache tutarlılığı, snapshot bağımsızlığı, constraint'ler ve 2026-07-18 güvenlik sıkılaştırmasının pozitif/negatif testleri (29-51: doğrudan `stock_quantity` yazma reddi, kaldırılan onboarding RPC'si, son owner invariantı, admin yetki yükseltme koruması, tenant sınırı, atomik sahiplik devri). Çalıştırma komutu dosyanın başında. Eşzamanlılık senaryosu (iki paralel bağlantı) tek transaction'lık psql testinde birebir simüle edilemez; garanti `FOR UPDATE` + check constraint katmanlarındadır (Edge Case 1).
