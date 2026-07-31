import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('SyncOutbox tablosu', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('tüm kolonlar doldurulduğunda kalıcı saklanır', () async {
      final createdAt = DateTime.utc(2026, 7, 22, 10);
      final nextAttemptAt = DateTime.utc(2026, 7, 22, 11);
      final lastAttemptAt = DateTime.utc(2026, 7, 22, 10, 30);
      final syncedAt = DateTime.utc(2026, 7, 22, 12);

      await db
          .into(db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: 'outbox-1',
              operationId: 'operation-1',
              businessId: 'business-1',
              originalActorUserId: 'user-1',
              submittedByUserId: const Value('user-2'),
              deviceId: 'device-1',
              aggregateType: 'customer',
              aggregateId: 'customer-1',
              operationType: 'insert',
              sequenceNumber: 1,
              dependsOnOperationId: const Value('operation-0'),
              payloadJson: '{"name":"Ali"}',
              payloadVersion: const Value(2),
              idempotencyKey: 'idem-1',
              expectedServerVersion: const Value(5),
              status: 'pending',
              priority: const Value(3),
              attemptCount: const Value(1),
              nextAttemptAt: Value(nextAttemptAt),
              lastAttemptAt: Value(lastAttemptAt),
              processingToken: const Value('token-1'),
              lastErrorCode: const Value('TIMEOUT'),
              lastErrorMessage: const Value('zaman aşımı'),
              createdAt: createdAt,
              syncedAt: Value(syncedAt),
            ),
          );

      final row = (await db.select(db.syncOutbox).get()).single;
      expect(row.id, 'outbox-1');
      expect(row.operationId, 'operation-1');
      expect(row.businessId, 'business-1');
      expect(row.originalActorUserId, 'user-1');
      expect(row.submittedByUserId, 'user-2');
      expect(row.deviceId, 'device-1');
      expect(row.aggregateType, 'customer');
      expect(row.aggregateId, 'customer-1');
      expect(row.operationType, 'insert');
      expect(row.sequenceNumber, 1);
      expect(row.dependsOnOperationId, 'operation-0');
      expect(row.payloadJson, '{"name":"Ali"}');
      expect(row.payloadVersion, 2);
      expect(row.idempotencyKey, 'idem-1');
      expect(row.expectedServerVersion, 5);
      expect(row.status, 'pending');
      expect(row.priority, 3);
      expect(row.attemptCount, 1);
      expect(row.nextAttemptAt?.toUtc(), nextAttemptAt);
      expect(row.lastAttemptAt?.toUtc(), lastAttemptAt);
      expect(row.processingToken, 'token-1');
      expect(row.lastErrorCode, 'TIMEOUT');
      expect(row.lastErrorMessage, 'zaman aşımı');
      expect(row.createdAt.toUtc(), createdAt);
      expect(row.syncedAt?.toUtc(), syncedAt);
    });

    test('opsiyonel kolonlar null ve varsayılan değerlerle çalışır', () async {
      final createdAt = DateTime.utc(2026, 7, 22, 10);

      await db
          .into(db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              id: 'outbox-2',
              operationId: 'operation-2',
              businessId: 'business-1',
              originalActorUserId: 'user-1',
              deviceId: 'device-1',
              aggregateType: 'customer',
              aggregateId: 'customer-2',
              operationType: 'update',
              sequenceNumber: 2,
              payloadJson: '{}',
              idempotencyKey: 'idem-2',
              status: 'processing',
              createdAt: createdAt,
            ),
          );

      final row = (await db.select(db.syncOutbox).get()).single;
      expect(row.submittedByUserId, isNull);
      expect(row.dependsOnOperationId, isNull);
      expect(row.payloadVersion, 1);
      expect(row.expectedServerVersion, isNull);
      expect(row.priority, 0);
      expect(row.attemptCount, 0);
      expect(row.nextAttemptAt, isNull);
      expect(row.lastAttemptAt, isNull);
      expect(row.processingToken, isNull);
      expect(row.lastErrorCode, isNull);
      expect(row.lastErrorMessage, isNull);
      expect(row.syncedAt, isNull);
    });
  });
}
