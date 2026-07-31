import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('SyncConflicts tablosu', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('tüm kolonlar doldurulduğunda kalıcı saklanır', () async {
      final createdAt = DateTime.utc(2026, 7, 22, 12);
      final resolvedAt = DateTime.utc(2026, 7, 22, 13);

      await db
          .into(db.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              id: 'conflict-1',
              businessId: 'business-1',
              aggregateType: 'customer',
              aggregateId: 'customer-1',
              operationId: 'operation-1',
              conflictCode: 'VERSION_CONFLICT',
              localPayload: '{"name":"Yerel"}',
              serverSnapshot: const Value('{"name":"Sunucu"}'),
              recommendedAction: const Value('resolvedWithServer'),
              status: const Value('resolvedWithServer'),
              createdAt: createdAt,
              resolvedAt: Value(resolvedAt),
              resolvedBy: const Value('manager-1'),
            ),
          );

      final row = (await db.select(db.syncConflicts).get()).single;
      expect(row.id, 'conflict-1');
      expect(row.businessId, 'business-1');
      expect(row.aggregateType, 'customer');
      expect(row.aggregateId, 'customer-1');
      expect(row.operationId, 'operation-1');
      expect(row.conflictCode, 'VERSION_CONFLICT');
      expect(row.localPayload, '{"name":"Yerel"}');
      expect(row.serverSnapshot, '{"name":"Sunucu"}');
      expect(row.recommendedAction, 'resolvedWithServer');
      expect(row.status, 'resolvedWithServer');
      expect(row.createdAt.toUtc(), createdAt);
      expect(row.resolvedAt?.toUtc(), resolvedAt);
      expect(row.resolvedBy, 'manager-1');
    });

    test('sync conflict Section 13 alanlarıyla kalıcı saklanır', () async {
      final createdAt = DateTime.utc(2026, 7, 22, 12);

      await db
          .into(db.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              id: 'conflict-2',
              businessId: 'business-1',
              aggregateType: 'customer',
              aggregateId: 'customer-1',
              operationId: 'operation-1',
              conflictCode: 'VERSION_CONFLICT',
              localPayload: '{"name":"Yerel"}',
              createdAt: createdAt,
            ),
          );

      final row = (await db.select(db.syncConflicts).get()).single;
      expect(row.businessId, 'business-1');
      expect(row.localPayload, '{"name":"Yerel"}');
      expect(row.status, 'open');
      expect(row.serverSnapshot, isNull);
      expect(row.recommendedAction, isNull);
      expect(row.resolvedAt, isNull);
      expect(row.resolvedBy, isNull);
    });
  });
}
