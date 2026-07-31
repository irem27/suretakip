import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/security/secure_key_store.dart';

void main() {
  group('SecureKeyStore', () {
    test('ilk açılışta 32 byte anahtar üretip base64 olarak saklar', () async {
      final storage = _FakeSecureStorage();
      var generationCount = 0;
      final keyStore = SecureKeyStore(
        storage: storage,
        randomBytes: (length) {
          generationCount++;
          return Uint8List.fromList(List<int>.generate(length, (i) => i));
        },
      );

      final key = await keyStore.readOrCreateDatabaseKey();

      expect(
        base64Decode(key),
        Uint8List.fromList(List<int>.generate(32, (i) => i)),
      );
      expect(storage.values[SecureKeyStore.databaseKeyName], key);
      expect(storage.writeCount, 1);
      expect(generationCount, 1);
    });

    test(
      'sonraki açılışta saklanan anahtarı okur ve yenisini üretmez',
      () async {
        final storage = _FakeSecureStorage();
        var generationCount = 0;
        final firstLaunchStore = SecureKeyStore(
          storage: storage,
          randomBytes: (length) {
            generationCount++;
            return Uint8List.fromList(List<int>.filled(length, 7));
          },
        );
        final firstLaunchKey = await firstLaunchStore.readOrCreateDatabaseKey();
        final secondLaunchStore = SecureKeyStore(
          storage: storage,
          randomBytes: (length) {
            generationCount++;
            return Uint8List(length);
          },
        );

        final secondLaunchKey = await secondLaunchStore
            .readOrCreateDatabaseKey();

        expect(secondLaunchKey, firstLaunchKey);
        expect(storage.writeCount, 1);
        expect(generationCount, 1);
      },
    );

    test('geçersiz saklanmış anahtarı değiştirmez', () async {
      final storage = _FakeSecureStorage(
        initialValues: {SecureKeyStore.databaseKeyName: 'gecersiz-anahtar'},
      );
      final keyStore = SecureKeyStore(
        storage: storage,
        randomBytes: Uint8List.new,
      );

      await expectLater(
        keyStore.readOrCreateDatabaseKey(),
        throwsA(isA<SecureKeyStoreException>()),
      );
      expect(storage.writeCount, 0);
    });

    test('eşzamanlı isteklerde anahtarı yalnız bir kez üretir', () async {
      final storage = _FakeSecureStorage();
      var generationCount = 0;
      final keyStore = SecureKeyStore(
        storage: storage,
        randomBytes: (length) {
          generationCount++;
          return Uint8List.fromList(List<int>.filled(length, 9));
        },
      );

      final keys = await Future.wait([
        keyStore.readOrCreateDatabaseKey(),
        keyStore.readOrCreateDatabaseKey(),
        keyStore.readOrCreateDatabaseKey(),
      ]);

      expect(keys.toSet(), hasLength(1));
      expect(storage.readCount, 1);
      expect(storage.writeCount, 1);
      expect(generationCount, 1);
    });

    test('güvenli depo hatasını ayrıntı sızdırmadan sarar', () async {
      final storage = _FakeSecureStorage(
        readError: StateError('platform-token=çok-gizli'),
      );
      final keyStore = SecureKeyStore(storage: storage);

      await expectLater(
        keyStore.readOrCreateDatabaseKey(),
        throwsA(
          isA<SecureKeyStoreException>().having(
            (error) => error.toString(),
            'mesaj',
            isNot(contains('çok-gizli')),
          ),
        ),
      );
      expect(storage.writeCount, 0);
    });
  });
}

final class _FakeSecureStorage implements SecureKeyValueStorage {
  _FakeSecureStorage({Map<String, String>? initialValues, this.readError})
    : values = {...?initialValues};

  final Map<String, String> values;
  final Object? readError;
  int readCount = 0;
  int writeCount = 0;

  @override
  Future<String?> read({required String key}) async {
    readCount++;
    final error = readError;
    if (error != null) {
      throw error;
    }
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writeCount++;
    values[key] = value;
  }
}
