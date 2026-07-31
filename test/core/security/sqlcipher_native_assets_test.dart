import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:suretakip/core/security/local_database_security.dart';

void main() {
  test('pubspec sqlite3 3.x SQLCipher native-assets hookunu kullanır', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, isNot(contains('sqlcipher_flutter_libs:')));
    expect(
      RegExp(r'^\s*sqlite3:\s*\^3\.', multiLine: true).hasMatch(pubspec),
      isTrue,
    );
    expect(pubspec, contains('hooks:'));
    expect(pubspec, contains('user_defines:'));
    expect(pubspec, contains('source: sqlcipher'));
  });

  test('native asset SQLCipher ile şifreli dosya üretir', () async {
    final directory = await Directory.systemTemp.createTemp(
      'suretakip_sqlcipher_native_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final databaseFile = File('${directory.path}/encrypted.sqlite');
    const databaseKey = 'integration-test-database-key';
    const secretValue = 'offline-secret-customer';

    final database = sqlite3.open(databaseFile.path);
    try {
      final cipherVersion = database.select('PRAGMA cipher_version;');
      expect(cipherVersion, isNotEmpty);
      expect(
        cipherVersion.first.values.any((value) => '$value'.isNotEmpty),
        isTrue,
      );
      database.execute("PRAGMA key = '$databaseKey';");
      database.execute('CREATE TABLE secrets (value TEXT NOT NULL);');
      database.execute('INSERT INTO secrets VALUES (?);', [secretValue]);
    } finally {
      database.close();
    }

    expect(
      utf8.decode(databaseFile.readAsBytesSync(), allowMalformed: true),
      isNot(contains(secretValue)),
    );

    final withoutKey = sqlite3.open(databaseFile.path);
    try {
      expect(
        () => withoutKey.select('SELECT * FROM secrets;'),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      withoutKey.close();
    }

    final withKey = sqlite3.open(databaseFile.path);
    try {
      withKey.execute("PRAGMA key = '$databaseKey';");
      expect(
        withKey.select('SELECT value FROM secrets;').single['value'],
        secretValue,
      );
    } finally {
      withKey.close();
    }
  });

  test(
    'gerçek plaintext veritabanını veri kaybetmeden SQLCiphera taşır',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'suretakip_sqlcipher_migration_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databaseFile = File('${directory.path}/legacy.sqlite');
      const databaseKey = 'migration-integration-key';
      const legacyValue = 'legacy-offline-row';

      final plaintext = sqlite3.open(databaseFile.path);
      try {
        plaintext.execute('CREATE TABLE legacy_data (value TEXT NOT NULL);');
        plaintext.execute('INSERT INTO legacy_data VALUES (?);', [legacyValue]);
        plaintext.userVersion = 5;
      } finally {
        plaintext.close();
      }

      final logs = <String>[];
      await LocalDatabaseSecurity(
        log: logs.add,
      ).prepareEncryptedDatabase(databaseFile, databaseKey);

      expect(logs, [LocalDatabaseSecurity.plaintextDatabaseMigratedLog]);

      final withoutKey = sqlite3.open(databaseFile.path);
      try {
        expect(
          () => withoutKey.select('SELECT * FROM legacy_data;'),
          throwsA(isA<SqliteException>()),
        );
      } finally {
        withoutKey.close();
      }

      final encrypted = sqlite3.open(databaseFile.path);
      try {
        encrypted.execute("PRAGMA key = '$databaseKey';");
        expect(
          encrypted.select('SELECT value FROM legacy_data;').single['value'],
          legacyValue,
        );
        expect(encrypted.userVersion, 5);
      } finally {
        encrypted.close();
      }
    },
  );
}
