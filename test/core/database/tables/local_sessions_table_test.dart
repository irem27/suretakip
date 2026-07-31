import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('LocalSessions tablosu', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('tüm kolonlar doldurulduğunda kalıcı saklanır', () async {
      final startedAt = DateTime.utc(2026, 7, 22, 9);
      final endedAt = DateTime.utc(2026, 7, 22, 10);
      final createdAtLocal = DateTime.utc(2026, 7, 22, 9);
      final updatedAtLocal = DateTime.utc(2026, 7, 22, 10);

      await db
          .into(db.localSessions)
          .insert(
            LocalSessionsCompanion.insert(
              id: 'session-1',
              businessId: 'business-1',
              customerId: const Value('customer-1'),
              serviceId: 'service-1',
              openedByMemberId: 'member-1',
              closedByMemberId: const Value('member-2'),
              status: 'completed',
              startedAt: startedAt,
              endedAt: Value(endedAt),
              serviceNameSnapshot: 'Yıkama',
              pricePerMinuteMinorSnapshot: 100,
              roundingIntervalMinutesSnapshot: 5,
              minimumChargeMinutesSnapshot: 15,
              currencyCodeSnapshot: 'TRY',
              notes: const Value('not'),
              syncStatus: 'synced',
              serverVersion: const Value(3),
              startedOffline: const Value(true),
              createdAtLocal: createdAtLocal,
              updatedAtLocal: updatedAtLocal,
              isDeleted: const Value(true),
            ),
          );

      final row = (await db.select(db.localSessions).get()).single;
      expect(row.id, 'session-1');
      expect(row.businessId, 'business-1');
      expect(row.customerId, 'customer-1');
      expect(row.serviceId, 'service-1');
      expect(row.openedByMemberId, 'member-1');
      expect(row.closedByMemberId, 'member-2');
      expect(row.status, 'completed');
      expect(row.startedAt.toUtc(), startedAt);
      expect(row.endedAt?.toUtc(), endedAt);
      expect(row.serviceNameSnapshot, 'Yıkama');
      expect(row.pricePerMinuteMinorSnapshot, 100);
      expect(row.roundingIntervalMinutesSnapshot, 5);
      expect(row.minimumChargeMinutesSnapshot, 15);
      expect(row.currencyCodeSnapshot, 'TRY');
      expect(row.notes, 'not');
      expect(row.syncStatus, 'synced');
      expect(row.serverVersion, 3);
      expect(row.startedOffline, isTrue);
      expect(row.createdAtLocal.toUtc(), createdAtLocal);
      expect(row.updatedAtLocal.toUtc(), updatedAtLocal);
      expect(row.isDeleted, isTrue);
    });

    test('opsiyonel kolonlar null ve varsayılan değerlerle çalışır', () async {
      final startedAt = DateTime.utc(2026, 7, 22, 9);
      final createdAtLocal = DateTime.utc(2026, 7, 22, 9);
      final updatedAtLocal = DateTime.utc(2026, 7, 22, 9);

      await db
          .into(db.localSessions)
          .insert(
            LocalSessionsCompanion.insert(
              id: 'session-2',
              businessId: 'business-1',
              serviceId: 'service-1',
              openedByMemberId: 'member-1',
              status: 'draft',
              startedAt: startedAt,
              serviceNameSnapshot: 'Yıkama',
              pricePerMinuteMinorSnapshot: 100,
              roundingIntervalMinutesSnapshot: 5,
              minimumChargeMinutesSnapshot: 15,
              currencyCodeSnapshot: 'TRY',
              syncStatus: 'local_only',
              createdAtLocal: createdAtLocal,
              updatedAtLocal: updatedAtLocal,
            ),
          );

      final row = (await db.select(db.localSessions).get()).single;
      expect(row.customerId, isNull);
      expect(row.closedByMemberId, isNull);
      expect(row.endedAt, isNull);
      expect(row.notes, isNull);
      expect(row.serverVersion, isNull);
      expect(row.startedOffline, isFalse);
      expect(row.isDeleted, isFalse);
    });
  });
}
