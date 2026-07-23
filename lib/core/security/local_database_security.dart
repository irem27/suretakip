import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:suretakip/core/security/secure_key_store.dart';

typedef DatabaseSecurityLog = void Function(String message);
typedef PlaintextDatabaseExport =
    void Function(File source, File target, String databaseKey);
typedef EncryptedDatabaseValidation =
    void Function(File databaseFile, String databaseKey);
typedef PlaintextDatabaseCheck = bool Function(File databaseFile);
typedef EncryptedDatabaseExecutor =
    QueryExecutor Function(File databaseFile, String databaseKey);

final class LocalDatabaseSecurityException implements Exception {
  const LocalDatabaseSecurityException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class LocalDatabaseSecurity {
  LocalDatabaseSecurity({
    DatabaseSecurityLog? log,
    PlaintextDatabaseExport? exportPlaintextDatabase,
    EncryptedDatabaseValidation? validateEncryptedDatabase,
    PlaintextDatabaseCheck? canOpenWithoutKey,
  }) : _log = log ?? debugPrint,
       _exportPlaintextDatabase =
           exportPlaintextDatabase ?? _exportPlaintextDatabaseWithSqlCipher,
       _validateEncryptedDatabase =
           validateEncryptedDatabase ?? _validateEncryptedDatabaseWithSqlCipher,
       _canOpenWithoutKey = canOpenWithoutKey ?? _canOpenDatabaseWithoutKey;

  static const plaintextDatabaseMigratedLog =
      'Şifresiz yerel veritabanı şifreli biçime güvenle taşındı.';

  final DatabaseSecurityLog _log;
  final PlaintextDatabaseExport _exportPlaintextDatabase;
  final EncryptedDatabaseValidation _validateEncryptedDatabase;
  final PlaintextDatabaseCheck _canOpenWithoutKey;

  Future<void> prepareEncryptedDatabase(
    File databaseFile,
    String databaseKey,
  ) async {
    try {
      _validateEncryptedDatabase(databaseFile, databaseKey);
    } on SqliteException catch (error) {
      final isPlaintextDatabase =
          error.resultCode == SqlError.SQLITE_NOTADB &&
          _canOpenWithoutKey(databaseFile);
      if (!isPlaintextDatabase) {
        throw const LocalDatabaseSecurityException(
          'Yerel veritabanı güvenli biçimde açılamadı.',
        );
      }

      await migratePlaintextDatabase(databaseFile, databaseKey);
    }
  }

  Future<void> migratePlaintextDatabase(
    File databaseFile,
    String databaseKey,
  ) async {
    final encryptedFile = File('${databaseFile.path}.encrypted-migration');
    await _deleteDatabaseArtifacts(encryptedFile);

    try {
      _exportPlaintextDatabase(databaseFile, encryptedFile, databaseKey);
      _validateEncryptedDatabase(encryptedFile, databaseKey);

      await _deleteDatabaseSidecars(databaseFile);
      await encryptedFile.rename(databaseFile.path);
      await _deleteDatabaseSidecars(encryptedFile);
    } on Object {
      await _deleteDatabaseArtifacts(encryptedFile);
      throw const LocalDatabaseSecurityException(
        'Şifresiz yerel veritabanı güvenli biçime taşınamadı.',
      );
    }

    _log(plaintextDatabaseMigratedLog);
  }
}

QueryExecutor openEncryptedLocalDatabase({
  SecureKeyStore? keyStore,
  LocalDatabaseSecurity? security,
  Future<Directory> Function()? databaseDirectory,
  EncryptedDatabaseExecutor? encryptedDatabaseExecutor,
}) {
  final resolvedKeyStore = keyStore ?? SecureKeyStore();
  final resolvedSecurity = security ?? LocalDatabaseSecurity();
  final resolveDirectory =
      databaseDirectory ?? getApplicationDocumentsDirectory;
  final createExecutor =
      encryptedDatabaseExecutor ?? _createEncryptedDatabaseExecutor;

  return LazyDatabase(() async {
    final databaseKey = await resolvedKeyStore.readOrCreateDatabaseKey();
    final directory = await resolveDirectory();
    final databaseFile = File.fromUri(
      directory.uri.resolve('suretakip_offline.sqlite'),
    );

    await resolvedSecurity.prepareEncryptedDatabase(databaseFile, databaseKey);
    return createExecutor(databaseFile, databaseKey);
  });
}

QueryExecutor _createEncryptedDatabaseExecutor(
  File databaseFile,
  String databaseKey,
) {
  return NativeDatabase.createInBackground(
    databaseFile,
    setup: (database) => _applyDatabaseKey(database, databaseKey),
  );
}

void _validateEncryptedDatabaseWithSqlCipher(
  File databaseFile,
  String databaseKey,
) {
  final database = sqlite3.open(databaseFile.path);
  try {
    _assertSqlCipherIsAvailable(database);
    _applyDatabaseKey(database, databaseKey);
    database.select('SELECT count(*) FROM sqlite_master;');
  } finally {
    database.close();
  }
}

bool _canOpenDatabaseWithoutKey(File databaseFile) {
  final database = sqlite3.open(databaseFile.path);
  try {
    _assertSqlCipherIsAvailable(database);
    database.select('SELECT count(*) FROM sqlite_master;');
    return true;
  } on SqliteException {
    return false;
  } finally {
    database.close();
  }
}

void _exportPlaintextDatabaseWithSqlCipher(
  File sourceFile,
  File encryptedFile,
  String databaseKey,
) {
  final database = sqlite3.open(sourceFile.path);
  var encryptedDatabaseAttached = false;

  try {
    _assertSqlCipherIsAvailable(database);
    database.select('PRAGMA wal_checkpoint(TRUNCATE);');
    _assertDatabaseIntegrity(database);

    final userVersion = database.userVersion;
    final autoVacuum = _readIntPragma(database, 'auto_vacuum');
    final applicationId = _readIntPragma(database, 'application_id');
    database.execute(
      'ATTACH DATABASE ${_sqlString(encryptedFile.path)} '
      'AS encrypted KEY ${_sqlString(databaseKey)};',
    );
    encryptedDatabaseAttached = true;
    database.execute('PRAGMA encrypted.auto_vacuum = $autoVacuum;');
    database.select("SELECT sqlcipher_export('encrypted');");
    database.execute('PRAGMA encrypted.user_version = $userVersion;');
    database.execute('PRAGMA encrypted.application_id = $applicationId;');
    database.execute('DETACH DATABASE encrypted;');
    encryptedDatabaseAttached = false;
  } finally {
    if (encryptedDatabaseAttached) {
      try {
        database.execute('DETACH DATABASE encrypted;');
      } on Object {
        // Asıl migrasyon hatasını koru; geçici dosya üst katmanda temizlenir.
      }
    }
    database.close();
  }
}

void _assertDatabaseIntegrity(Database database) {
  final result = database.select('PRAGMA integrity_check;');
  if (result.length != 1 || result.first.columnAt(0) != 'ok') {
    throw const LocalDatabaseSecurityException(
      'Şifresiz yerel veritabanı bütünlük kontrolünü geçemedi.',
    );
  }
}

int _readIntPragma(Database database, String pragmaName) {
  final result = database.select('PRAGMA $pragmaName;');
  final value = result.firstOrNull?.columnAt(0);
  if (value is int) {
    return value;
  }
  throw const LocalDatabaseSecurityException(
    'Yerel veritabanı ayarları okunamadı.',
  );
}

void _assertSqlCipherIsAvailable(Database database) {
  final cipherVersion = database.select('PRAGMA cipher_version;');
  if (cipherVersion.isEmpty ||
      cipherVersion.first.values.every((value) => '$value'.isEmpty)) {
    throw const LocalDatabaseSecurityException(
      'SQLCipher yerel kitaplığı kullanılamıyor.',
    );
  }
}

void _applyDatabaseKey(Database database, String databaseKey) {
  try {
    database.execute('PRAGMA key = ${_sqlString(databaseKey)};');
  } on Object {
    throw const LocalDatabaseSecurityException(
      'Yerel veritabanı anahtarı uygulanamadı.',
    );
  }
}

String _sqlString(String value) => "'${value.replaceAll("'", "''")}'";

Future<void> _deleteDatabaseSidecars(File databaseFile) async {
  for (final suffix in const ['-wal', '-shm', '-journal']) {
    final artifact = File('${databaseFile.path}$suffix');
    if (await artifact.exists()) {
      await artifact.delete();
    }
  }
}

Future<void> _deleteDatabaseArtifacts(File databaseFile) async {
  await _deleteDatabaseSidecars(databaseFile);
  if (await databaseFile.exists()) {
    await databaseFile.delete();
  }
}
