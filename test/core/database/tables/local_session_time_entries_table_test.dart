import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('LocalSessionTimeEntries tablosu', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('tüm kolonlar doldurulduğunda kalıcı saklanır', () async {
      final startedAt = DateTime.utc(2026, 7, 22, 9);
      final endedAt = DateTime.utc(2026, 7, 22, 10);
      final createdAtLocal = DateTime.utc(2026, 7, 22, 9);

      await db
          .into(db.localSessionTimeEntries)
          .insert(
            LocalSessionTimeEntriesCompanion.insert(
              id: 'entry-1',
              businessId: 'business-1',
              sessionId: 'session-1',
              entryType: 'active',
              startedAt: startedAt,
              endedAt: Value(endedAt),
              createdAtLocal: createdAtLocal,
              syncStatus: 'synced',
            ),
          );

      final row = (await db.select(db.localSessionTimeEntries).get()).single;
      expect(row.id, 'entry-1');
      expect(row.businessId, 'business-1');
      expect(row.sessionId, 'session-1');
      expect(row.entryType, 'active');
      expect(row.startedAt.toUtc(), startedAt);
      expect(row.endedAt?.toUtc(), endedAt);
      expect(row.createdAtLocal.toUtc(), createdAtLocal);
      expect(row.syncStatus, 'synced');
    });

    test('endedAt null olabilir (aktif aralık)', () async {
      final startedAt = DateTime.utc(2026, 7, 22, 9);
      final createdAtLocal = DateTime.utc(2026, 7, 22, 9);

      await db
          .into(db.localSessionTimeEntries)
          .insert(
            LocalSessionTimeEntriesCompanion.insert(
              id: 'entry-2',
              businessId: 'business-1',
              sessionId: 'session-1',
              entryType: 'paused',
              startedAt: startedAt,
              createdAtLocal: createdAtLocal,
              syncStatus: 'pending',
            ),
          );

      final row = (await db.select(db.localSessionTimeEntries).get()).single;
      expect(row.endedAt, isNull);
      expect(row.entryType, 'paused');
    });
  });
}
