import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/security/local_database_security.dart';
import 'package:suretakip/core/security/secure_key_store.dart';

void main() {
  group('LocalDatabaseSecurity', () {
    test('plaintext veriyi şifreli kopyayla kayıpsız değiştirir', () async {
      final directory = await Directory.systemTemp.createTemp(
        'suretakip_security_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databaseFile = File('${directory.path}/suretakip_offline.sqlite');
      const plaintextPayload = 'offline-customer-row';
      const encryptedPayload = 'encrypted-database-pages';
      await databaseFile.writeAsString(plaintextPayload);
      await File('${databaseFile.path}-wal').writeAsString('wal-data');
      await File('${databaseFile.path}-shm').writeAsString('shm-data');
      final logs = <String>[];
      var validationCount = 0;
      final security = LocalDatabaseSecurity(
        log: logs.add,
        exportPlaintextDatabase: (source, target, key) {
          expect(source.readAsStringSync(), plaintextPayload);
          expect(key, 'database-key');
          target.writeAsStringSync(encryptedPayload);
        },
        validateEncryptedDatabase: (file, key) {
          validationCount++;
          expect(file.readAsStringSync(), encryptedPayload);
          expect(key, 'database-key');
        },
      );

      await security.migratePlaintextDatabase(databaseFile, 'database-key');

      expect(databaseFile.readAsStringSync(), encryptedPayload);
      expect(File('${databaseFile.path}-wal').existsSync(), isFalse);
      expect(File('${databaseFile.path}-shm').existsSync(), isFalse);
      expect(validationCount, 1);
      expect(logs, [LocalDatabaseSecurity.plaintextDatabaseMigratedLog]);
    });

    test(
      'migrasyon hatasında plaintext veriyi ve yan dosyaları korur',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'suretakip_security_failure_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final databaseFile = File('${directory.path}/suretakip_offline.sqlite');
        await databaseFile.writeAsString('plaintext-data');
        final walFile = File('${databaseFile.path}-wal');
        await walFile.writeAsString('pending-wal-data');
        final security = LocalDatabaseSecurity(
          log: (_) {},
          exportPlaintextDatabase: (source, target, key) {
            target.writeAsStringSync('partial-encrypted-data');
            throw StateError('export failed');
          },
          validateEncryptedDatabase: (_, _) {},
        );

        await expectLater(
          security.migratePlaintextDatabase(databaseFile, 'database-key'),
          throwsA(isA<LocalDatabaseSecurityException>()),
        );

        expect(databaseFile.readAsStringSync(), 'plaintext-data');
        expect(walFile.readAsStringSync(), 'pending-wal-data');
        expect(
          File('${databaseFile.path}.encrypted-migration').existsSync(),
          isFalse,
        );
      },
    );

    test('migrasyon logu anahtar, dosya yolu veya PII içermez', () async {
      final directory = await Directory.systemTemp.createTemp(
        'suretakip_security_log_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databaseFile = File('${directory.path}/suretakip_offline.sqlite');
      const sensitivePayload =
          'db-key=super-secret; phone=+90 555 111 22 33; customer=Ayşe';
      await databaseFile.writeAsString(sensitivePayload);
      final logs = <String>[];
      final security = LocalDatabaseSecurity(
        log: logs.add,
        exportPlaintextDatabase: (_, target, _) {
          target.writeAsStringSync('encrypted');
        },
        validateEncryptedDatabase: (_, _) {},
      );

      await security.migratePlaintextDatabase(databaseFile, 'super-secret');

      expect(logs, [LocalDatabaseSecurity.plaintextDatabaseMigratedLog]);
      final allLogs = logs.join('\n');
      expect(allLogs, isNot(contains('super-secret')));
      expect(allLogs, isNot(contains('+90 555 111 22 33')));
      expect(allLogs, isNot(contains('Ayşe')));
      expect(allLogs, isNot(contains(directory.path)));
    });

    test('yanlış şifreyi plaintext sanıp migrasyon yapmaz', () async {
      var exportCalled = false;
      final security = LocalDatabaseSecurity(
        log: (_) {},
        validateEncryptedDatabase: (_, _) {
          throw SqliteException(
            extendedResultCode: SqlError.SQLITE_NOTADB,
            message: 'wrong key',
          );
        },
        canOpenWithoutKey: (_) => false,
        exportPlaintextDatabase: (_, _, _) => exportCalled = true,
      );

      await expectLater(
        security.prepareEncryptedDatabase(File('encrypted.sqlite'), 'wrong'),
        throwsA(isA<LocalDatabaseSecurityException>()),
      );
      expect(exportCalled, isFalse);
    });

    test('Drift açılışı async anahtarı executor öncesinde bekler', () async {
      final directory = await Directory.systemTemp.createTemp(
        'suretakip_security_open_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final events = <String>[];
      final storage = _RecordingSecureStorage(events);
      final security = LocalDatabaseSecurity(
        log: (_) {},
        validateEncryptedDatabase: (file, key) {
          events.add('validate:$key:${file.path}');
        },
      );
      final executor = openEncryptedLocalDatabase(
        keyStore: SecureKeyStore(
          storage: storage,
          randomBytes: (length) =>
              Uint8List.fromList(List<int>.generate(length, (index) => index)),
        ),
        security: security,
        databaseDirectory: () async => directory,
        encryptedDatabaseExecutor: (file, key) {
          events.add('executor:$key:${file.path}');
          return NativeDatabase.memory();
        },
      );
      final db = AppDatabase.forExecutor(executor);
      addTearDown(db.close);

      final row = await db.customSelect('SELECT 1 AS value').getSingle();

      expect(row.read<int>('value'), 1);
      expect(events, hasLength(4));
      expect(events[0], 'read-key');
      expect(events[1], 'write-key');
      expect(events[2], startsWith('validate:'));
      expect(events[3], startsWith('executor:'));
      expect(events[2].split(':')[1], events[3].split(':')[1]);
    });
  });
}

final class _RecordingSecureStorage implements SecureKeyValueStorage {
  _RecordingSecureStorage(this.events);

  final List<String> events;

  @override
  Future<String?> read({required String key}) async {
    events.add('read-key');
    return null;
  }

  @override
  Future<void> write({required String key, required String value}) async {
    events.add('write-key');
  }
}
