import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';
import 'package:suretakip/features/history/presentation/pages/history_page.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
import 'package:suretakip/features/payments/presentation/controllers/payments_controller.dart';
import 'package:suretakip/features/payments/presentation/widgets/payment_status_badge.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';

void main() {
  testWidgets('boş geçmiş kullanıcıyı filtreleri değiştirmeye yönlendirir', (
    tester,
  ) async {
    // Test sırasından bağımsız olarak standart widget-test görünümüyle başla.
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBusinessProvider.overrideWithValue(_business()),
          sessionsRepositoryProvider.overrideWithValue(
            _FakeSessionsRepository(),
          ),
          customersRepositoryProvider.overrideWithValue(
            _FakeCustomersRepository(),
          ),
          servicesRepositoryProvider.overrideWithValue(
            _FakeServicesRepository(),
          ),
          paymentsRepositoryProvider.overrideWithValue(
            _FakePaymentsRepository(const []),
          ),
        ],
        child: const MaterialApp(home: HistoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Tarih aralığını veya filtreleri değiştirerek'),
      findsOneWidget,
    );
    expect(find.byTooltip('Geçmişi yenile'), findsOneWidget);
  });

  testWidgets(
    'toplu sonuçtaki üç ödeme rozetini gösterir, eksik seansı rozetsiz bırakır',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final payments = _FakePaymentsRepository([
        _paymentStatus('session-unpaid', SessionPaymentStatus.unpaid),
        _paymentStatus('session-partial', SessionPaymentStatus.partiallyPaid),
        _paymentStatus('session-paid', SessionPaymentStatus.paid),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeBusinessProvider.overrideWithValue(_business()),
            sessionsRepositoryProvider.overrideWithValue(
              _FakeSessionsRepository(
                sessions: [
                  _session('session-unpaid'),
                  _session('session-partial'),
                  _session('session-paid'),
                  _session('session-not-visible'),
                ],
              ),
            ),
            customersRepositoryProvider.overrideWithValue(
              _FakeCustomersRepository(),
            ),
            servicesRepositoryProvider.overrideWithValue(
              _FakeServicesRepository(),
            ),
            paymentsRepositoryProvider.overrideWithValue(payments),
          ],
          child: const MaterialApp(home: HistoryPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ödenmedi'), findsOneWidget);
      expect(find.text('Kısmi ödendi'), findsOneWidget);
      expect(find.text('Ödendi'), findsOneWidget);
      expect(find.byType(PaymentStatusBadge), findsNWidgets(3));
      final missingSession = find.textContaining('session-not-visible');
      await tester.scrollUntilVisible(missingSession, 300);
      final missingSessionCard = find
          .ancestor(of: missingSession, matching: find.byType(Card))
          .first;
      expect(missingSession, findsOneWidget);
      expect(
        find.descendant(
          of: missingSessionCard,
          matching: find.byType(PaymentStatusBadge),
        ),
        findsNothing,
      );
      expect(payments.batchCallCount, 1);
      expect(payments.requestedSessionIds, [
        'session-unpaid',
        'session-partial',
        'session-paid',
        'session-not-visible',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeSessionsRepository implements SessionsRepository {
  _FakeSessionsRepository({this.sessions = const []});

  final List<Session> sessions;

  @override
  Future<DateTime> serverNow() async => DateTime.utc(2026, 7, 18, 10);

  @override
  Future<List<Session>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) async => sessions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePaymentsRepository implements PaymentsRepository {
  _FakePaymentsRepository(this.statuses);

  final List<SessionPaymentStatusSummary> statuses;
  int batchCallCount = 0;
  List<String>? requestedSessionIds;

  @override
  Future<List<SessionPaymentStatusSummary>> getSessionsPaymentStatus(
    List<String> sessionIds,
  ) async {
    batchCallCount += 1;
    requestedSessionIds = sessionIds;
    return statuses;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCustomersRepository implements CustomersRepository {
  @override
  Future<List<Customer>> getCustomers({
    required String businessId,
    bool includeInactive = false,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeServicesRepository implements ServicesRepository {
  @override
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async => [];

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

SessionPaymentStatusSummary _paymentStatus(
  String sessionId,
  SessionPaymentStatus status,
) => SessionPaymentStatusSummary(
  sessionId: sessionId,
  sessionTotal: Money(minorUnits: 6000, currencyCode: 'TRY'),
  collected: Money.zero('TRY'),
  refunded: Money.zero('TRY'),
  netPaid: Money.zero('TRY'),
  remaining: Money(minorUnits: 6000, currencyCode: 'TRY'),
  paymentStatus: status,
  currencyCode: 'TRY',
);

Session _session(String id) => Session(
  id: id,
  businessId: 'business-1',
  customerId: null,
  serviceId: 'service-1',
  openedByMemberId: 'member-1',
  closedByMemberId: 'member-1',
  status: SessionStatus.completed,
  startedAt: DateTime.utc(2026, 7, 18, 8),
  endedAt: DateTime.utc(2026, 7, 18, 9),
  chargedMinutes: 60,
  serviceNameSnapshot: id,
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
