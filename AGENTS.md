# SüreTakip Proje Talimatları

## Teknoloji ve mimari

- Flutter/Dart, Material 3, Riverpod, GoRouter, Supabase ve Drift kullanılır.
- Yapı feature-first'tür: `presentation -> domain -> data` bağımlılık yönünü koru.
- UI doğrudan Supabase mutation yapmaz; repository/RPC sınırını kullanır.
- Para kayan noktalı değil, en küçük birim cinsinden `int/bigint` tutulur.
- Tenant yetkisinin son sözü istemci filtresi değil RLS/RPC'dir.

## Offline-first kuralları

- Kural kaynağı: `docs/offline-first-contract.md`.
- Domain kaydı ve outbox operasyonu aynı Drift transaction'inda yazılır.
- `operation_id` ve `idempotency_key` oluştuktan sonra değiştirilmez.
- Auth/ağ hatasında pending veri silinmez.
- `processing` kayıtları lease + fencing token ile kurtarılır; claim atomik
  olmalı ve süresiz takılı kayıt bırakılmamalıdır.
- Append-only finans/stok kayıtları silinmez veya soft-delete edilmez; ters kayıt kullanılır.
- Mevcut roller `owner/admin/staff`; yeni rol veya `branch_id` ancak şema/ADR kararıyla eklenir.

## Kod stili

- `lib/` içinde package import kullan.
- Null assertion (`!`) yerine guard/pattern tercih et.
- Widgetları küçük sınıflara ayır ve mümkün olan yerde `const` kullan.
- Async sonrası `BuildContext` kullanmadan önce `mounted` kontrol et.
- Hata/log içine token, PIN, anahtar veya kişisel veri koyma.
- Kullanıcıya gösterilen metinler Türkçe ve eyleme dönük olmalıdır.

## Test ve doğrulama

- Yeni davranışta önce başarısız test yaz (RED), minimum kodla geçir (GREEN), sonra temizle.
- Kaynak yapısını `test/` altında aynala; dış bağımlılıklarda fake tercih et.
- Zorunlu kontroller:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

- Migration/RPC değişikliğinde `supabase db reset` ve ilgili `supabase/tests/` senaryolarını da çalıştır.
- Kullanıcının çalışma ağacındaki ilgisiz veya tamamlanmamış değişikliklerini geri alma.
