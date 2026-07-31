import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef SecureRandomBytes = Uint8List Function(int length);

abstract interface class SecureKeyValueStorage {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});
}

final class FlutterSecureKeyValueStorage implements SecureKeyValueStorage {
  const FlutterSecureKeyValueStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false, migrateWithBackup: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
      ),
    ),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);
}

final class SecureKeyStoreException implements Exception {
  const SecureKeyStoreException();

  @override
  String toString() => 'Yerel veritabanı anahtarı okunamadı.';
}

/// Yerel veritabanı anahtarını cihazın Keystore/Keychain alanında tutar.
///
/// Anahtar değeri kasıtlı olarak loglanmaz ve hata metinlerine eklenmez.
final class SecureKeyStore {
  SecureKeyStore({
    SecureKeyValueStorage storage = const FlutterSecureKeyValueStorage(),
    SecureRandomBytes randomBytes = _secureRandomBytes,
  }) : _storage = storage,
       _randomBytes = randomBytes;

  static const databaseKeyName = 'suretakip.local_database.master_key.v1';
  static const _databaseKeyLength = 32;

  final SecureKeyValueStorage _storage;
  final SecureRandomBytes _randomBytes;
  Future<String>? _pendingKey;

  Future<String> readOrCreateDatabaseKey() {
    final pendingKey = _pendingKey;
    if (pendingKey != null) {
      return pendingKey;
    }

    final created = _readOrCreateDatabaseKey();
    _pendingKey = created;
    return created;
  }

  Future<String> _readOrCreateDatabaseKey() async {
    try {
      final storedKey = await _storage.read(key: databaseKeyName);
      if (storedKey != null) {
        if (!_isValidDatabaseKey(storedKey)) {
          throw const SecureKeyStoreException();
        }
        return storedKey;
      }

      final bytes = _randomBytes(_databaseKeyLength);
      if (bytes.length != _databaseKeyLength) {
        throw const SecureKeyStoreException();
      }

      final generatedKey = base64Encode(bytes);
      await _storage.write(key: databaseKeyName, value: generatedKey);
      return generatedKey;
    } on SecureKeyStoreException {
      rethrow;
    } on Object {
      throw const SecureKeyStoreException();
    }
  }

  static bool _isValidDatabaseKey(String value) {
    try {
      final decoded = base64Decode(value);
      return decoded.length == _databaseKeyLength &&
          base64Encode(decoded) == value;
    } on FormatException {
      return false;
    }
  }
}

Uint8List _secureRandomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}
