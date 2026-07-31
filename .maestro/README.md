# SüreTakip — Maestro E2E Flow'ları

appId: `com.suretakip.app` · Maestro 2.7.0

## Kurulum
Çalışan bir cihaz/emülatör + kurulu APK gerekir.

```bash
# Emülatör (mevcut AVD var):
emulator -avd suretakip_test &

# Debug build kur (proje kökünden):
flutter install   # veya:
adb install SureTakip-1.0.0+2-release.apk
```

## Kimlik bilgileri (koda gömülü değil)
```bash
export MAESTRO_EMAIL="test@suretakip.com"
export MAESTRO_PASSWORD="Test1234!"
```
> `02`, `05`, `06`, `07` numaralı flow'lar giriş ister — bu hesabın
> kayıtlı ve onboarding'i tamamlanmış olması gerekir.

## Çalıştırma

### iOS Simulator (önerilen — `run.sh`)
iOS'ta Supabase oturumu **Keychain**'de tutulur ve maestro'nun `clearState`'i
(hatta uninstall) bunu SİLMEZ. Tek `maestro test .maestro/` çağrısında ilk akış
giriş yapınca sonraki akışlar giriş-yapılmış açılır ve login ekranı bekleyen
akışlar düşer. Bu yüzden iOS'ta koşucu script kullanın — her akıştan önce
keychain'i sıfırlayıp uygulamayı sonlandırarak her akışı temiz başlatır:

```bash
.maestro/run.sh                          # booted simulator'da tüm akışlar
MAESTRO_DEVICE=<udid> .maestro/run.sh    # belirli cihaz
.maestro/run.sh .maestro/02-login.yaml   # tek akış
```

### Android / tek akış
Android'de `clearState` oturumu temizler; doğrudan maestro yeterli:
```bash
maestro test .maestro/                 # tümü
maestro test .maestro/01-smoke.yaml    # tek flow
maestro test --include-tags=smoke .maestro/   # etikete göre
maestro studio                         # locator'ları görsel keşfet
```

## Flow'lar
| Dosya | Kapsam | Giriş? |
|-------|--------|--------|
| 01-smoke | Açılış + login ekranı | Hayır |
| 02-login | Geçerli giriş → Ana Sayfa | — |
| 03-login-hatali | Yanlış şifre → hata | Hayır |
| 04-kayit | Kayıt formu + validasyon | Hayır |
| 05-navigasyon | 5 alt sekme gezinme | Evet |
| 06-yeni-islem | Yeni işlem/seans başlat (çekirdek) | Evet |
| 07-musteri-ekle | Müşteri ekleme | Evet |

## Not
Locator'lar metin tabanlı (Flutter widget'larında `Key` çoğunlukla DB
alanları için). UI metni değişirse ilgili `tapOn`/`assertVisible`
güncellenmeli. `07` içindeki alan id'leri (`name`) ve buton metinleri
esnek yazıldı (`optional`, regex) — form kesinleşince daraltılabilir.
