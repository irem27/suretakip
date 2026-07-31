import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('LocalServices tablosu', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('tüm kolonlar doldurulduğunda kalıcı saklanır', () async {
      final archivedAt = DateTime.utc(2026, 7, 22, 9);
      final createdAt = DateTime.utc(2026, 7, 20);
      final updatedAt = DateTime.utc(2026, 7, 21);
      final deletedAt = DateTime.utc(2026, 7, 22, 10);

      await db
          .into(db.localServices)
          .insert(
            LocalServicesCompanion.insert(
              id: 'service-1',
              businessId: 'business-1',
              name: 'Yıkama',
              pricePerMinuteMinor: 50,
              roundingIntervalMinutes: 5,
              minimumChargeMinutes: 15,
              currencyCode: 'TRY',
              isActive: const Value(false),
              archivedAt: Value(archivedAt),
              createdAt: createdAt,
              updatedAt: updatedAt,
              syncStatus: const Value('rejected'),
              serverVersion: const Value(7),
              isDeleted: const Value(true),
              deletedAt: Value(deletedAt),
              lastSyncError: const Value('SCHEMA_ERROR'),
            ),
          );

      final row = (await db.select(db.localServices).get()).single;
      expect(row.id, 'service-1');
      expect(row.businessId, 'business-1');
      expect(row.name, 'Yıkama');
      expect(row.pricePerMinuteMinor, 50);
      expect(row.roundingIntervalMinutes, 5);
      expect(row.minimumChargeMinutes, 15);
      expect(row.currencyCode, 'TRY');
      expect(row.isActive, isFalse);
      expect(row.archivedAt?.toUtc(), archivedAt);
      expect(row.createdAt.toUtc(), createdAt);
      expect(row.updatedAt.toUtc(), updatedAt);
      expect(row.syncStatus, 'rejected');
      expect(row.serverVersion, 7);
      expect(row.isDeleted, isTrue);
      expect(row.deletedAt?.toUtc(), deletedAt);
      expect(row.lastSyncError, 'SCHEMA_ERROR');
    });

    test('opsiyonel kolonlar null ve varsayılan değerlerle çalışır', () async {
      final createdAt = DateTime.utc(2026, 7, 20);
      final updatedAt = DateTime.utc(2026, 7, 20);

      await db
          .into(db.localServices)
          .insert(
            LocalServicesCompanion.insert(
              id: 'service-2',
              businessId: 'business-1',
              name: 'Kesim',
              pricePerMinuteMinor: 40,
              roundingIntervalMinutes: 1,
              minimumChargeMinutes: 10,
              currencyCode: 'TRY',
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );

      final row = (await db.select(db.localServices).get()).single;
      expect(row.isActive, isTrue);
      expect(row.archivedAt, isNull);
      expect(row.syncStatus, 'synced');
      expect(row.serverVersion, isNull);
      expect(row.isDeleted, isFalse);
      expect(row.deletedAt, isNull);
      expect(row.lastSyncError, isNull);
    });
  });
}
