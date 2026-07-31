import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';
import 'package:suretakip/features/history/presentation/controllers/history_controller.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

void main() {
  test('aktif işletme yoksa boş durum döner', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeBusinessProvider.overrideWithValue(null),
        sessionsRepositoryProvider.overrideWithValue(_FakeSessionsRepository()),
        customersRepositoryProvider.overrideWithValue(
          _FakeCustomersRepository(),
        ),
        servicesRepositoryProvider.overrideWithValue(_FakeServicesRepository()),
        paymentsRepositoryProvider.overrideWithValue(_FakePaymentsRepository()),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(
      historyControllerProvider(_scope).future,
    );

    expect(state.sessions, isEmpty);
    expect(state.customers, isEmpty);
    expect(state.services, isEmpty);
  });

  test('setDates/setService/setStatus filtre state\'i günceller', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final sessions = _FakeSessionsRepository();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeBusinessProvider.overrideWithValue(_business()),
        sessionsRepositoryProvider.overrideWithValue(sessions),
        customersRepositoryProvider.overrideWithValue(
          _FakeCustomersRepository(),
        ),
        servicesRepositoryProvider.overrideWithValue(_FakeServicesRepository()),
        paymentsRepositoryProvider.overrideWithValue(_FakePaymentsRepository()),
      ],
    );
    addTearDown(container.dispose);
    final provider = historyControllerProvider(_scope);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    final notifier = container.read(provider.notifier);

    await notifier.setDates(DateTime(2026, 7, 1), DateTime(2026, 7, 18));
    await notifier.setService('service-9');
    await notifier.setStatus(HistoryStatusFilter.completed);

    final state = container.read(provider).requireValue;
    expect(state.serviceId, 'service-9');
    expect(state.status, HistoryStatusFilter.completed);
    expect(state.firstDate, DateTime(2026, 7, 1));
    expect(state.lastDate, DateTime(2026, 7, 18));
  });

  test('customerName tanımsız ve misafir müşteriyi ayırt eder', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeBusinessProvider.overrideWithValue(_business()),
        sessionsRepositoryProvider.overrideWithValue(_FakeSessionsRepository()),
        customersRepositoryProvider.overrideWithValue(
          _FakeCustomersRepository(),
        ),
        servicesRepositoryProvider.overrideWithValue(_FakeServicesRepository()),
        paymentsRepositoryProvider.overrideWithValue(_FakePaymentsRepository()),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(
      historyControllerProvider(_scope).future,
    );

    expect(state.customerName(null), 'Misafir Müşteri');
    expect(state.customerName('bilinmeyen-id'), 'Bilinmeyen Müşteri');
  });
}

class _FakePaymentsRepository implements PaymentsRepository {
  @override
  Future<List<SessionPaymentStatusSummary>> getSessionsPaymentStatus(
    List<String> sessionIds,
  ) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionsRepository implements SessionsRepository {
  @override
  Future<DateTime> serverNow() async => DateTime.utc(2026, 7, 18, 12);

  @override
  Future<List<Session>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCustomersRepository implements CustomersRepository {
  @override
  Future<List<Customer>> getCustomers({
    required String businessId,
    bool includeInactive = false,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeServicesRepository implements ServicesRepository {
  @override
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
