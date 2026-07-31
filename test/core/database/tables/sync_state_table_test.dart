import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('SyncState tablosu', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('tüm kolonlar doldurulduğunda kalıcı saklanır', () async {
      final updatedAt = DateTime.utc(2026, 7, 22, 9);

      await db
          .into(db.syncState)
          .insert(
            SyncStateCompanion.insert(
              key: 'delta_cursor',
              value: const Value('cursor-abc'),
              updatedAt: updatedAt,
            ),
          );

      final row = (await db.select(db.syncState).get()).single;
      expect(row.key, 'delta_cursor');
      expect(row.value, 'cursor-abc');
      expect(row.updatedAt.toUtc(), updatedAt);
    });

    test('value null olabilir', () async {
      final updatedAt = DateTime.utc(2026, 7, 22, 9);

      await db
          .into(db.syncState)
          .insert(
            SyncStateCompanion.insert(key: 'device_id', updatedAt: updatedAt),
          );

      final row = (await db.select(db.syncState).get()).single;
      expect(row.value, isNull);
    });
  });
}
