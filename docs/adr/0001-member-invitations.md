# ADR 0001 — Üye daveti akışı

- **Durum:** Önerildi (uygulanmadı — ürün kararı ve dış bağımlılık bekliyor)
- **Tarih:** 2026-07-18
- **Bağlam:** P1-7, güvenlik sıkılaştırması sonrası

## Bağlam

2026-07-18 sıkılaştırmasıyla üyelik mutasyonlarının tamamı sunucu tarafı
RPC'lere taşındı (`20260718090200_membership_rpcs.sql`). Yetki kontrolü,
admin yetki-yükseltme koruması ve "son aktif owner" invariantı artık
sunucuda ve kilit altında uygulanıyor.

Ancak `add_business_member(p_business_id, p_user_id, p_role)` hâlâ **ham
kullanıcı UUID'si** alıyor. Bu, bir kullanıcı arayüzü için uygun değildir:
işletme sahibi, davet etmek istediği kişinin `auth.users.id` değerini
bilmez. Pratikte bilinen tek tanımlayıcı **e-posta adresidir**.

## Sorun: e-posta ile davet, auth enumeration açar

En doğrudan çözüm — "e-posta gir, kullanıcıyı bul, ekle" — bir güvenlik
açığı yaratır:

```
POST add_business_member_by_email('deneme@ornek.com')
  -> "user_not_found"      => bu e-posta sistemde KAYITLI DEĞİL
  -> "member_added"        => bu e-posta sistemde KAYITLI
```

Yanıtlar arasındaki bu fark, saldırganın herhangi bir e-posta adresinin
SüreTakip'te hesabı olup olmadığını öğrenmesini sağlar (auth enumeration).
Bu bilgi kimlik avı ve credential-stuffing saldırılarını besler. Uygulamanın
mevcut giriş/şifre-sıfırlama akışları bu sızıntıyı zaten yapmıyor; davet
akışıyla geri getirmek bir gerileme olur.

## Karar (önerilen)

**Davet kaydı modeli.** Kullanıcıyı aramak yerine, davetin kendisini bir
nesne olarak saklarız:

1. Yeni tablo `business_invitations`:
   - `id`, `business_id`, `email` (normalize/lowercase), `role`,
   - `token_hash` — token'ın **kendisi değil**, SHA-256 özeti saklanır
     (DB sızıntısında token'lar kullanılamaz),
   - `expires_at`, `accepted_at`, `revoked_at`, `created_by_member_id`.
2. `create_business_invitation(business_id, email, role)` RPC'si:
   - owner/admin yetkisi ister; admin `owner` rolüne davet edemez
     (mevcut `assert_can_manage_member` kural setiyle aynı),
   - kullanıcının var olup olmadığına **bakmaz** → enumeration yok,
   - her zaman aynı başarılı yanıtı döner.
3. Token e-postayla gönderilir (uygulama üzerinden değil).
4. `accept_business_invitation(token)` RPC'si:
   - token'ı hash'leyip eşleştirir,
   - süresi geçmiş / kullanılmış / iptal edilmiş daveti reddeder,
   - **çağıranın oturum açmış e-postası davetin e-postasıyla eşleşmeli**
     (tenant-bound: token çalınsa bile başkası kullanamaz),
   - üyeliği oluşturur ve `accepted_at`'i işaretler (tek kullanımlık).

Token özellikleri: **tek kullanımlık, süreli (öneri: 7 gün), tenant-bound.**

## Neden şimdi uygulanmadı

Bu akışın çalışması için **uygulama dışı bir bağımlılık** gerekir: davet
e-postasını gönderecek bir kanal (Supabase Edge Function + e-posta sağlayıcı,
ya da Supabase Auth'un davet altyapısı). Bu, aşağıdaki ürün kararlarını
gerektirir ve mühendislik kararı olarak tek başına verilemez:

1. **E-posta sağlayıcı ve gönderen kimliği** — hangi servis, hangi domain,
   SPF/DKIM kimin elinde?
2. **Hesabı olmayan davetli** — davet linki önce kayıt ekranına mı düşsün,
   yoksa davet yalnızca mevcut kullanıcılara mı açık olsun?
3. **Davet ömrü ve yeniden gönderim** — 7 gün varsayımı doğrulanmalı; iptal
   ve yeniden gönderim UI'da nasıl sunulacak?
4. **Maliyet/kota** — e-posta hacmi ve sağlayıcı ücretlendirmesi.

## Ara durum (bugün geçerli olan)

- Sunucu tarafı üyelik RPC'leri **hazır ve testli** (51 senaryoluk paket).
- Üyelik yönetimi **ekranları henüz yok**; mevcut üyelerin rolü/aktifliği
  şimdilik yalnız programatik olarak yönetilebilir.
- İlk owner `complete_onboarding` ile oluşur, yani hiçbir işletme sahipsiz
  veya hizmetsiz kalamaz — bu ara durum güvenli.

## Sonuçlar

- **Artı:** enumeration yüzeyi hiç açılmaz; token sızıntısı tek başına
  yetmez (e-posta eşleşmesi + süre + tek kullanım).
- **Eksi:** davet akışı e-posta altyapısına bağımlı hale gelir; sağlayıcı
  kesintisi davetleri durdurur (üyelik yönetiminin geri kalanını etkilemez).
- **Alternatif (reddedildi):** işletme başına paylaşılabilir katılım linki —
  tek kullanımlık ve kişiye bağlı olmadığı için sızdığında sınırsız
  katılıma açık; tenant güvenliği için kabul edilemez.
