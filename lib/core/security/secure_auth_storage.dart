import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase oturum belirteçlerini (access/refresh token, PKCE verifier)
/// cihazın Keystore/Keychain alanında şifreli tutmak için ortak yapılandırma.
///
/// Varsayılan `SharedPreferencesLocalStorage`/`SharedPreferencesGotrueAsyncStorage`
/// belirteçleri düz metin olarak `SharedPreferences`/`NSUserDefaults` içinde
/// saklar. Bu adaptörler bunları `flutter_secure_storage` üzerinden şifreler.
///
/// Belirteç değerleri kasıtlı olarak loglanmaz ve hata metinlerine eklenmez.
const FlutterSecureStorage _secureAuthStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false, migrateWithBackup: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  ),
);

/// Supabase oturumunu (access + refresh token) güvenli depolamada tutar.
final class SecureSupabaseLocalStorage extends LocalStorage {
  const SecureSupabaseLocalStorage({
    FlutterSecureStorage storage = _secureAuthStorage,
    this.persistSessionKey = _defaultPersistSessionKey,
  }) : _storage = storage;

  static const _defaultPersistSessionKey =
      'suretakip.supabase.persist_session.v1';

  final FlutterSecureStorage _storage;
  final String persistSessionKey;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: persistSessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: persistSessionKey);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: persistSessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: persistSessionKey, value: persistSessionString);
}

/// PKCE code verifier gibi geçici gotrue anahtarlarını güvenli depolamada tutar.
final class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  const SecureGotrueAsyncStorage({
    FlutterSecureStorage storage = _secureAuthStorage,
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) => _storage.read(key: key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> removeItem({required String key}) => _storage.delete(key: key);
}
