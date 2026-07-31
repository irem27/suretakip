import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';
import 'package:suretakip/features/history/presentation/controllers/history_controller.dart';
import 'package:suretakip/features/history/presentation/pages/history_page.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
import 'package:suretakip/features/payments/presentation/widgets/payment_status_badge.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';

void main() {
  test('geçmiş uzak sunucuyu beklemeden yerel işlemi gösterir', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final local = SessionsLocalDataSource(db);
    await local.startSession(
      StartSessionLocally(
        sessionId: 'local-history',
        timeEntryId: 'entry-local',
        businessId: 'business-1',
        serviceId: 'service-1',
        openedByMemberId: 'member-1',
        serviceName: 'Yerel Bilardo',
        pricePerMinuteMinor: 100,
        roundingIntervalMinutes: 1,
        minimumChargeMinutes: 0,
        currencyCode: 'TRY',
        startedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        startedOffline: true,
      ),
    );
    await local.reconcileTerminalState(
      sessionId: 'local-history',
      status: SessionStatus.completed,
      endedAt: DateTime.now().toUtc(),
    );
    final remote = _FakeSessionsRepository()
      ..serverNowCompleter = Completer<DateTime>();

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeBusinessProvider.overrideWithValue(_business()),
        sessionsRepositoryProvider.overrideWithValue(remote),
        customersRepositoryProvider.overrideWithValue(
          _FakeCustomersRepository(),
        ),
        servicesRepositoryProvider.overrideWithValue(_FakeServicesRepository()),
        paymentsRepositoryProvider.overrideWithValue(
          _FakePaymentsRepository(const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    const scope = (businessId: 'business-1', generation: 0);
    final localState = await container
        .read(historyControllerProvider(scope).future)
        .timeout(const Duration(milliseconds: 100));
    expect(localState.sessions.single.id, 'local-history');

    remote.serverNowCompleter!.complete(DateTime.now().toUtc());
  });

  testWidgets('boş geçmiş kullanıcıyı filtreleri değiştirmeye yönlendirir', (
    tester,
  ) async {
    // Test sırasından bağımsız olarak standart widget-test görünümüyle başla.
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    final db = await _openMemoryDatabase();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
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
    await _pumpLocalFirstFrame(tester);

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
      final db = await _openMemoryDatabase();
      addTearDown(db.close);
      final payments = _FakePaymentsRepository([
        _paymentStatus('session-unpaid', SessionPaymentStatus.unpaid),
        _paymentStatus('session-partial', SessionPaymentStatus.partiallyPaid),
        _paymentStatus('session-paid', SessionPaymentStatus.paid),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
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
      await _pumpLocalFirstFrame(tester);

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

Future<AppDatabase> _openMemoryDatabase() async {
  final database = AppDatabase.forExecutor(NativeDatabase.memory());
  await database.customSelect('SELECT 1').get();
  return database;
}

Future<void> _pumpLocalFirstFrame(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
}

class _FakeSessionsRepository implements SessionsRepository {
  _FakeSessionsRepository({this.sessions = const []});

  final List<Session> sessions;
  Completer<DateTime>? serverNowCompleter;

  @override
  Future<DateTime> serverNow() async =>
      serverNowCompleter?.future ?? DateTime.utc(2026, 7, 18, 10);

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
