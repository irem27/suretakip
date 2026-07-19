import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';
import 'package:suretakip/features/history/presentation/controllers/history_controller.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
import 'package:suretakip/features/payments/presentation/controllers/payments_controller.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';

void main() {
  test(
    'geçmiş controller sunucu zamanı ve işletme timezoneuyla filtreler',
    () async {
      final sessions = _FakeSessionsRepository();
      final payments = _FakePaymentsRepository();
      final container = ProviderContainer(
        overrides: [
          activeBusinessProvider.overrideWithValue(_business()),
          sessionsRepositoryProvider.overrideWithValue(sessions),
          customersRepositoryProvider.overrideWithValue(
            _FakeCustomersRepository(),
          ),
          servicesRepositoryProvider.overrideWithValue(
            _FakeServicesRepository(),
          ),
          paymentsRepositoryProvider.overrideWithValue(payments),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(
        historyControllerProvider(_scope).future,
      );

      expect(state.sessions, hasLength(1));
      expect(
        state.paymentStatuses['session-1'],
        SessionPaymentStatus.partiallyPaid,
      );
      expect(payments.batchCallCount, 1);
      expect(payments.requestedSessionIds, ['session-1']);
      expect(sessions.businessId, 'business-1');
      expect(sessions.filter?.endedAtOrAfter, DateTime.utc(2026, 6, 30, 21));
      expect(sessions.filter?.endedBefore, DateTime.utc(2026, 7, 18, 21));
      expect(sessions.filter?.statuses, [
        SessionStatus.completed,
        SessionStatus.cancelled,
      ]);
    },
  );
}

class _FakePaymentsRepository implements PaymentsRepository {
  int batchCallCount = 0;
  List<String>? requestedSessionIds;

  @override
  Future<List<SessionPaymentStatusSummary>> getSessionsPaymentStatus(
    List<String> sessionIds,
  ) async {
    batchCallCount += 1;
    requestedSessionIds = sessionIds;
    final total = Money(minorUnits: 6000, currencyCode: 'TRY');
    return [
      SessionPaymentStatusSummary(
        sessionId: 'session-1',
        sessionTotal: total,
        collected: Money(minorUnits: 2000, currencyCode: 'TRY'),
        refunded: Money.zero('TRY'),
        netPaid: Money(minorUnits: 2000, currencyCode: 'TRY'),
        remaining: Money(minorUnits: 4000, currencyCode: 'TRY'),
        paymentStatus: SessionPaymentStatus.partiallyPaid,
        currencyCode: 'TRY',
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

class _FakeSessionsRepository implements SessionsRepository {
  String? businessId;
  SessionHistoryFilter? filter;

  @override
  Future<DateTime> serverNow() async => DateTime.utc(2026, 7, 18, 12);

  @override
  Future<List<Session>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) async {
    this.businessId = businessId;
    this.filter = filter;
    return [_session()];
  }

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

Session _session() => Session(
  id: 'session-1',
  businessId: 'business-1',
  customerId: null,
  serviceId: 'service-1',
  openedByMemberId: 'member-1',
  closedByMemberId: 'member-1',
  status: SessionStatus.completed,
  startedAt: DateTime.utc(2026, 7, 18, 8),
  endedAt: DateTime.utc(2026, 7, 18, 9),
  chargedMinutes: 60,
  serviceNameSnapshot: 'Bilardo',
  pricePerMinuteMinorSnapshot: 100,
  roundingIntervalMinutesSnapshot: 1,
  minimumChargeMinutesSnapshot: 0,
  currencyCodeSnapshot: 'TRY',
  serviceSubtotalMinor: 6000,
  productsSubtotalMinor: 0,
  discountMinor: 0,
  taxMinor: 0,
  grandTotalMinor: 6000,
  notes: null,
  createdAt: DateTime.utc(2026, 7, 18, 8),
  updatedAt: DateTime.utc(2026, 7, 18, 9),
);
