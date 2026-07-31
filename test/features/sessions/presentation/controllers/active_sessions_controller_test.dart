import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/presentation/controllers/active_sessions_controller.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';

import '../../../../helpers/fake_monotonic_clock.dart';

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

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

  test(
    'açık seans özeti müşteri adını ve kalem tutarını birleştirir',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final local = SessionsLocalDataSource(db);
      await local.startSession(
        StartSessionLocally(
          sessionId: 'session-1',
          timeEntryId: 'entry-1',
          businessId: 'business-1',
          serviceId: 'service-1',
          openedByMemberId: 'member-1',
          serviceName: 'Bilardo',
          pricePerMinuteMinor: 200,
          roundingIntervalMinutes: 5,
          minimumChargeMinutes: 10,
          currencyCode: 'TRY',
          customerId: 'customer-1',
          startedAt: DateTime.utc(2026, 7, 17),
          startedOffline: true,
        ),
      );
      await local.reconcileServerItems(
        sessionId: 'session-1',
        items: [_item()],
      );
      final clock = FakeMonotonicClock();
      addTearDown(clock.stop);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeBusinessProvider.overrideWithValue(_business()),
          activeBusinessScopeProvider.overrideWithValue(_scope),
          monotonicClockFactoryProvider.overrideWithValue(() => clock),
          customersListControllerProvider.overrideWith(
            _FakeCustomersListController.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      // Açık seanslar Drift stream'inden gelir; ilk emisyonu bekleyip canlı
      // tutmak için abone oluyoruz (autoDispose provider bu sırada
      // düşmesin diye).
      final openSub = container.listen(openSessionsProvider, (_, _) {});
      addTearDown(openSub.close);
      await container.read(openSessionsProvider.future);

      final summariesSub = container.listen(
        activeSessionSummariesProvider,
        (_, _) {},
      );
      addTearDown(summariesSub.close);
      // İlk build ürün kalemleri akışının ilk emisyonundan önce oluşabilir;
      // kalemler akışı yayınlanınca provider kendini yeniden kurar. Kararlı
      // (kalemli) sonucu almak için ikinci emisyonu bekliyoruz.
      await container.read(activeSessionSummariesProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final summaries = await container.read(
        activeSessionSummariesProvider.future,
      );

      expect(summaries, hasLength(1));
      final summary = summaries.single;
      expect(summary.customerName, 'Ada Lovelace');
      expect(summary.items, hasLength(1));
      expect(summary.quote.grandTotal.minorUnits, greaterThanOrEqualTo(600));
    },
  );

  test('açık seans yoksa boş liste döner ve müşteriler okunmaz', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeBusinessProvider.overrideWithValue(_business()),
        activeBusinessScopeProvider.overrideWithValue(_scope),
      ],
    );
    addTearDown(container.dispose);

    final summaries = await container.read(
      activeSessionSummariesProvider.future,
    );

    expect(summaries, isEmpty);
  });
}

class _FakeCustomersListController extends CustomersListController {
  @override
  Future<CustomersListState> build(BusinessScope scope) async =>
      CustomersListState(customers: [_customer()], query: '');
}

Customer _customer() => Customer(
  id: 'customer-1',
  businessId: 'business-1',
  name: 'Ada Lovelace',
  phone: null,
  email: null,
  notes: null,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Business _business() => Business(
  id: 'business-1',
  name: 'Test',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

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
