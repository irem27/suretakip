# Yayın kontrol listesi

Bu liste her staging kabulü ve production yayını için kopyalanıp doldurulur.
Tarih, sürüm ve sorumlu kişi yayın kaydına eklenir.

## Kullanıcı aksiyonu bekliyor

- [ ] Production Android/iOS imzalama anahtarı ve erişim sorumlusu belirlendi;
      anahtar yedekleme ve kurtarma yöntemi doğrulandı.
- [ ] Production'dan ayrı staging Supabase projesi açıldı ve erişimleri
      sınırlandırıldı.
- [ ] Gizlilik politikası; toplanan veriler, saklama süresi, destek/iletişim ve
      varsa hata raporlama sağlayıcısını kapsayacak şekilde onaylandı.
- [ ] Pilot işletme staging kabul senaryolarını tamamladı ve yazılı yayın onayı
      verdi.

## CI ve sürüm adayı

- [ ] `dart format --set-exit-if-changed .`, `flutter analyze --fatal-infos` ve
      `flutter test --coverage` başarılı.
- [ ] CI migration reset ve RLS testleri dahil tamamen yeşil; kapsam kapısı
      düşürülmedi.
- [ ] Sürüm numarası/build numarası ve değişiklik özeti doğrulandı.
- [ ] Release adayı `.env.staging` ile üretildi; env dosyaları ve secret'lar
      pakete/repoya eklenmedi.

## Migration release prosedürü

- [ ] Daha önce deploy edilen migration dosyaları değiştirilmedi; düzeltmeler
      yeni, ileri yönlü migration olarak yazıldı.
- [ ] Yerelde `supabase db reset` ve RLS senaryo testleri temiz tamamlandı.
- [ ] Staging bağlantısı doğrulandı; `supabase db push --linked --dry-run` ile
      uygulanacak migration listesi incelendi, ardından staging'e uygulandı.
- [ ] Staging şema/RLS/RPC smoke testleri ve veri uyumluluğu doğrulandı.
- [ ] Production yedeği ve geri dönüş için ters/düzeltici migration hazır;
      production dry-run çıktısı iki kişi tarafından incelendi.
- [ ] Onaylanan migration'lar production'a uygulandı ve aynı smoke testleri
      tekrarlandı.

## Staging kabulü

- [ ] Owner/admin/staff temel akışları gerçek cihazlarda doğrulandı.
- [ ] Ağ yok, zaman aşımı ve tekrar deneme durumları kabul edildi.
- [ ] Kritik işlemler, raporlar ve tenant izolasyonu staging verisiyle
      doğrulandı.
- [ ] Pilot kabulündeki bulgular kapatıldı veya açık risk olarak onaylandı.

## Offline-first güvenlik kapısı (Faz D)

> Offline mod son kullanıcıya "güvenli" diye açılmadan önce bu bölüm tamamen
> yeşil olmalıdır (bkz. `offline-first-contract.md`, `ADR 0003`).

- [ ] Yerel Drift/SQLite veritabanı SQLCipher ile şifreli; DB anahtarı kodda
      sabit değil, secure storage/Keystore/Keychain'de tutuluyor.
- [ ] SQLCipher anahtarı ile `device_master_key` ayrı; anahtar log/backup/
      istemci yanıtında görünmüyor.
- [ ] Android `allowBackup=false` + hassas ekranlarda `FLAG_SECURE`;
      iOS file protection + arka plan privacy overlay.
- [ ] Loglarda token, DB anahtarı, PIN veya müşteri PII'si yok.
- [ ] Anahtar kaybı/kurtarma ve şifreli DB migration senaryosu test edildi.

## Offline-first işlevsel kabul

- [ ] Uçak modunda oluşturulan müşteri/seans, uygulama ve cihaz yeniden
      başlatılsa da kaybolmuyor; süre zaman damgasından doğru devam ediyor.
- [ ] İnternet gelince otomatik senkron (push + delta) çalışıyor; aynı işlem
      tekrar gönderilse de sunucuda tek kayıt oluşuyor.
- [ ] Snapshot/delta hiçbir non-ok yanıtta yerel önbelleği silmiyor.
- [ ] Ortak cihazda çapraz kullanıcı/işletme gönderimi olmuyor (account-scoped
      outbox claim); logout bekleyen kaydı koruyor.
- [ ] Offline SQL paketi (create_customer + session + delta pgTAP) ve Flutter
      offline testleri CI'da yeşil.

## Secret ve erişim güvenliği

- [ ] Supabase anahtarları ve CI/store erişimleri en az ayrıcalıkla sınırlandı.
- [ ] Paylaşılmış, sızmış veya süresi dolmuş secret'lar döndürüldü; eski
      değerler iptal edildi.
- [ ] `.env.staging` ve `.env.production` git geçmişinde ve build çıktılarında
      bulunmuyor.

## Paket ve mağaza

- [ ] Release paketi production imzalama anahtarıyla imzalandı ve imza
      doğrulandı.
- [ ] Uygulama adı, bundle/application ID, ikon, splash ve izin açıklamaları
      production değerlerinde.
- [ ] Açıklama, ekran görüntüleri, kategori, destek adresi, gizlilik politikası
      bağlantısı ve sürüm notları güncel.
- [ ] Store kapalı test/iç dağıtım paketi production adayıyla aynı kaynaktan
      üretildi ve smoke test edildi.

## Yayın ve geri alma planı

- [ ] Aşamalı yayın yüzdesi, izlenecek hata/iş metriği, sorumlu kişi ve durdurma
      eşikleri yazılı.
- [ ] Son bilinen iyi uygulama sürümü ve veritabanı yedeği erişilebilir.
- [ ] Şema geri dönüşü için veri kaybettirmeyen ters/düzeltici migration ve
      uygulama uyumluluk sırası prova edildi.
- [ ] Store rollback'in önceki binary'yi doğrudan geri getirmeyebileceği dikkate
      alındı; gerekirse daha yüksek build numaralı son bilinen iyi sürümü yeniden
      yayınlama adımları hazır.
- [ ] Yayın sonrası smoke testleri tamamlandı; sorun halinde aşamalı yayın
      durdurma ve rollback sorumlusu hazır.
