import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';

void main() {
  group('LocalSessionItems tablosu', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forExecutor(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    test('tüm kolonlar doldurulduğunda kalıcı saklanır', () async {
      final createdAtServer = DateTime.utc(2026, 7, 20);
      final updatedAtServer = DateTime.utc(2026, 7, 21);

      await db
          .into(db.localSessionItems)
          .insert(
            LocalSessionItemsCompanion.insert(
              id: 'item-1',
              businessId: 'business-1',
              sessionId: 'session-1',
              productId: const Value('product-1'),
              productNameSnapshot: 'Şampuan',
              skuSnapshot: const Value('SKU-1'),
              unitPriceMinorSnapshot: 1000,
              currencyCodeSnapshot: 'TRY',
              quantity: 2,
              discountMinor: 100,
              taxMinor: 50,
              lineTotalMinor: 1950,
              createdAtServer: createdAtServer,
              updatedAtServer: updatedAtServer,
            ),
          );

      final row = (await db.select(db.localSessionItems).get()).single;
      expect(row.id, 'item-1');
      expect(row.businessId, 'business-1');
      expect(row.sessionId, 'session-1');
      expect(row.productId, 'product-1');
      expect(row.productNameSnapshot, 'Şampuan');
      expect(row.skuSnapshot, 'SKU-1');
      expect(row.unitPriceMinorSnapshot, 1000);
      expect(row.currencyCodeSnapshot, 'TRY');
      expect(row.quantity, 2);
      expect(row.discountMinor, 100);
      expect(row.taxMinor, 50);
      expect(row.lineTotalMinor, 1950);
      expect(row.createdAtServer.toUtc(), createdAtServer);
      expect(row.updatedAtServer.toUtc(), updatedAtServer);
    });

    test('opsiyonel productId ve skuSnapshot null olabilir', () async {
      final createdAtServer = DateTime.utc(2026, 7, 20);
      final updatedAtServer = DateTime.utc(2026, 7, 20);

      await db
          .into(db.localSessionItems)
          .insert(
            LocalSessionItemsCompanion.insert(
              id: 'item-2',
              businessId: 'business-1',
              sessionId: 'session-1',
              productNameSnapshot: 'Elle giriş',
              unitPriceMinorSnapshot: 500,
              currencyCodeSnapshot: 'TRY',
              quantity: 1,
              discountMinor: 0,
              taxMinor: 0,
              lineTotalMinor: 500,
              createdAtServer: createdAtServer,
              updatedAtServer: updatedAtServer,
            ),
          );

      final row = (await db.select(db.localSessionItems).get()).single;
      expect(row.productId, isNull);
      expect(row.skuSnapshot, isNull);
    });
  });
}
