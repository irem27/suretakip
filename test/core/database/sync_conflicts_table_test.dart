import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  test('sync conflict Section 13 alanlarıyla kalıcı saklanır', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final createdAt = DateTime.utc(2026, 7, 22, 12);

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
}
