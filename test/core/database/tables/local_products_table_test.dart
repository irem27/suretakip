import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('LocalProducts tablosu', () {
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
          .into(db.localProducts)
          .insert(
            LocalProductsCompanion.insert(
              id: 'product-1',
              businessId: 'business-1',
              name: 'Şampuan',
              sku: const Value('SKU-1'),
              unitPriceMinor: 1000,
              currencyCode: 'TRY',
              trackStock: const Value(true),
              stockQuantity: const Value(5),
              isActive: const Value(false),
              archivedAt: Value(archivedAt),
              createdAt: createdAt,
              updatedAt: updatedAt,
              syncStatus: const Value('pending'),
              serverVersion: const Value(2),
              isDeleted: const Value(true),
              deletedAt: Value(deletedAt),
              lastSyncError: const Value('NETWORK_ERROR'),
            ),
          );

      final row = (await db.select(db.localProducts).get()).single;
      expect(row.id, 'product-1');
      expect(row.businessId, 'business-1');
      expect(row.name, 'Şampuan');
      expect(row.sku, 'SKU-1');
      expect(row.unitPriceMinor, 1000);
      expect(row.currencyCode, 'TRY');
      expect(row.trackStock, isTrue);
      expect(row.stockQuantity, 5);
      expect(row.isActive, isFalse);
      expect(row.archivedAt?.toUtc(), archivedAt);
      expect(row.createdAt.toUtc(), createdAt);
      expect(row.updatedAt.toUtc(), updatedAt);
      expect(row.syncStatus, 'pending');
      expect(row.serverVersion, 2);
      expect(row.isDeleted, isTrue);
      expect(row.deletedAt?.toUtc(), deletedAt);
      expect(row.lastSyncError, 'NETWORK_ERROR');
    });

    test('opsiyonel kolonlar null ve varsayılan değerlerle çalışır', () async {
      final createdAt = DateTime.utc(2026, 7, 20);
      final updatedAt = DateTime.utc(2026, 7, 21);

      await db
          .into(db.localProducts)
          .insert(
            LocalProductsCompanion.insert(
              id: 'product-2',
              businessId: 'business-1',
              name: 'Sabun',
              unitPriceMinor: 500,
              currencyCode: 'TRY',
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );

      final row = (await db.select(db.localProducts).get()).single;
      expect(row.sku, isNull);
      expect(row.trackStock, isFalse);
      expect(row.stockQuantity, 0);
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
