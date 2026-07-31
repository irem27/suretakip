# Gözlemlenebilirlik ve logger entegrasyonu

Uygulama hata raporlamasını `AppLogger` arayüzünün arkasında tutar. Debug
çalıştırmaları `ConsoleAppLogger`, varsayılan/release çalıştırmaları ise
`NoopAppLogger` kullanır. Bu aşamada Sentry, Crashlytics veya başka bir
crash-reporting paketi eklenmemiştir.

İleride bir satıcı seçildiğinde çağrı noktaları değiştirilmez:

1. `AppLogger` uygulayan tek bir adaptör yazılır (örneğin
   `SentryAppLogger`).
2. Adaptörün `error`, `warn` ve `info` çağrıları satıcının SDK'sına yönlendirilir.
3. `main` içindeki kök `ProviderContainer`, bu adaptörle oluşturulur.
4. Staging ve production için DSN/proje bilgileri ayrı env/secret yönetiminde
   tutulur; repoya yazılmaz.

`main.dart` içindeki bağlama şu kalıpta yapılır:

```dart
final container = ProviderContainer(
  overrides: [
    appLoggerProvider.overrideWithValue(SentryAppLogger()),
  ],
);
final logger = container.read(appLoggerProvider);

FlutterError.onError = (details) {
  logger.error(
    details.exception,
    stackTrace: details.stack,
    context: details.context?.toDescription(),
  );
};
PlatformDispatcher.instance.onError = (error, stackTrace) {
  logger.error(
    error,
    stackTrace: stackTrace,
    context: 'Yakalanmamış platform hatası',
  );
  return true;
};

await SupabaseInitializer.initialize();
runApp(UncontrolledProviderScope(container: container, child: const App()));
```

Global Flutter/platform hata yakalayıcıları ve uygulama provider'ları böylece
aynı `AppLogger` örneğini kullanır. Ayrı bir `ProviderScope` oluşturmak veya
yalnızca widget ağacında override etmek global yakalayıcıları bu örnekten
ayırır.

Yeni adaptör, ortak maskeleme katmanını atlamamalıdır. JWT/token, e-posta,
telefon, parola ve ham Postgres ayrıntıları ne olay mesajına ne de ek bağlama
gönderilmelidir. Satıcı panelindeki veri saklama süresi, erişimler ve kullanıcı
onayı da SDK etkinleştirilmeden önce gizlilik politikasıyla birlikte
kararlaştırılmalıdır.
