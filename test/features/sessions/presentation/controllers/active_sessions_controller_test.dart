import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/presentation/controllers/active_sessions_controller.dart';

void main() {
  test(
    'aktif seans ürünlerini finansal özete dahil etmek için yükler',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final local = SessionsLocalDataSource(db);
      await local.reconcileServerItems(
        sessionId: 'session-1',
        items: [_item()],
      );

      final items = await watchSessionItemsForActiveSummaries(
        local: local,
        sessionIds: const ['session-1'],
      ).first;

      expect(items['session-1'], hasLength(1));
      expect(items['session-1']!.single.lineTotalMinor, 600);
    },
  );

  test('yerel ürün cache boşsa seans görünümünü bozmaz', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final items = await watchSessionItemsForActiveSummaries(
      local: SessionsLocalDataSource(db),
      sessionIds: const ['session-1'],
    ).first;

    expect(items, isEmpty);
  });
}

SessionItem _item() => SessionItem(
  id: 'item-1',
  businessId: 'biz-1',
  sessionId: 'session-1',
  productId: 'product-1',
  productNameSnapshot: 'Su',
  skuSnapshot: null,
  unitPriceMinorSnapshot: 300,
  currencyCodeSnapshot: 'TRY',
  quantity: 2,
  discountMinor: 0,
  taxMinor: 0,
  lineTotalMinor: 600,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
