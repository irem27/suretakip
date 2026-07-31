import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('LocalCustomers tablosu', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('tüm kolonlar doldurulduğunda kalıcı saklanır', () async {
      final createdAtLocal = DateTime.utc(2026, 7, 20);
      final updatedAtLocal = DateTime.utc(2026, 7, 21);
      final createdAtServer = DateTime.utc(2026, 7, 20, 1);
      final updatedAtServer = DateTime.utc(2026, 7, 21, 1);
      final deletedAt = DateTime.utc(2026, 7, 22);

      await db
          .into(db.localCustomers)
          .insert(
            LocalCustomersCompanion.insert(
              id: 'customer-1',
              businessId: 'business-1',
              name: 'Ali Veli',
              phone: const Value('5551112233'),
              email: const Value('ali@example.com'),
              notes: const Value('VIP'),
              isActive: const Value(false),
              syncStatus: 'conflicted',
              serverVersion: const Value(4),
              createdAtLocal: createdAtLocal,
              updatedAtLocal: updatedAtLocal,
              createdAtServer: Value(createdAtServer),
              updatedAtServer: Value(updatedAtServer),
              isDeleted: const Value(true),
              deletedAt: Value(deletedAt),
              lastSyncError: const Value('VERSION_CONFLICT'),
            ),
          );

      final row = (await db.select(db.localCustomers).get()).single;
      expect(row.id, 'customer-1');
      expect(row.businessId, 'business-1');
      expect(row.name, 'Ali Veli');
      expect(row.phone, '5551112233');
      expect(row.email, 'ali@example.com');
      expect(row.notes, 'VIP');
      expect(row.isActive, isFalse);
      expect(row.syncStatus, 'conflicted');
      expect(row.serverVersion, 4);
      expect(row.createdAtLocal.toUtc(), createdAtLocal);
      expect(row.updatedAtLocal.toUtc(), updatedAtLocal);
      expect(row.createdAtServer?.toUtc(), createdAtServer);
      expect(row.updatedAtServer?.toUtc(), updatedAtServer);
      expect(row.isDeleted, isTrue);
      expect(row.deletedAt?.toUtc(), deletedAt);
      expect(row.lastSyncError, 'VERSION_CONFLICT');
    });

    test('opsiyonel kolonlar null ve varsayılan değerlerle çalışır', () async {
      final createdAtLocal = DateTime.utc(2026, 7, 20);
      final updatedAtLocal = DateTime.utc(2026, 7, 20);

      await db
          .into(db.localCustomers)
          .insert(
            LocalCustomersCompanion.insert(
              id: 'customer-2',
              businessId: 'business-1',
              name: 'Ayşe',
              syncStatus: 'local_only',
              createdAtLocal: createdAtLocal,
              updatedAtLocal: updatedAtLocal,
            ),
          );

      final row = (await db.select(db.localCustomers).get()).single;
      expect(row.phone, isNull);
      expect(row.email, isNull);
      expect(row.notes, isNull);
      expect(row.isActive, isTrue);
      expect(row.serverVersion, isNull);
      expect(row.createdAtServer, isNull);
      expect(row.updatedAtServer, isNull);
      expect(row.isDeleted, isFalse);
      expect(row.deletedAt, isNull);
      expect(row.lastSyncError, isNull);
    });
  });
}
