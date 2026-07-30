import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';
import 'package:suretakip/features/history/presentation/controllers/history_controller.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
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
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      final sessions = _FakeSessionsRepository();
      final payments = _FakePaymentsRepository();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
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

      final provider = historyControllerProvider(_scope);
      await container.read(provider.future);
      await container.read(provider.notifier).refresh();
      final state = container.read(provider).requireValue;

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

  test(
    'filtre uçan istek sırasında değişirse eski sonuç yeni state\'i ezmez',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      final sessions = _SlowFirstCustomerSessionsRepository();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeBusinessProvider.overrideWithValue(_business()),
          sessionsRepositoryProvider.overrideWithValue(sessions),
          customersRepositoryProvider.overrideWithValue(
            _FakeCustomersRepository(),
          ),
          servicesRepositoryProvider.overrideWithValue(
            _FakeServicesRepository(),
          ),
          paymentsRepositoryProvider.overrideWithValue(_FakePaymentsRepository()),
        ],
      );
      addTearDown(container.dispose);

      final provider = historyControllerProvider(_scope);
      // autoDispose ile testler arasındaki beklemelerde sağlayıcının erken
      // kapatılıp yeniden inşa edilmesini önlemek için canlı tut.
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      // 'a' seçilince sunucu isteği 'a' için başlar ve tamamlanana kadar bekler.
      await notifier.setCustomer('customer-a');
      await pumpEventQueue();
      // 'a' isteği uçarken filtre 'b'ye değişir.
      await notifier.setCustomer('customer-b');
      await pumpEventQueue();
      // Şimdi 'a' isteğinin sunucu yanıtını serbest bırak; bu, sonucu atıp
      // güncel filtre ('b') için yeniden yenileme tetiklemeli.
      sessions.completeSlowRequest();
      await pumpEventQueue(times: 200);

      final state = container.read(provider).requireValue;
      expect(state.customerId, 'customer-b');
      expect(sessions.lastRequestedCustomerId, 'customer-b');
    },
  );

  test('elle yenile ağ-dışı hatayı yutmaz ve durumu hataya çevirir', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    final sessions = _AlwaysFailingSessionsRepository();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeBusinessProvider.overrideWithValue(_business()),
        sessionsRepositoryProvider.overrideWithValue(sessions),
        customersRepositoryProvider.overrideWithValue(
          _FakeCustomersRepository(),
        ),
        servicesRepositoryProvider.overrideWithValue(
          _FakeServicesRepository(),
        ),
        paymentsRepositoryProvider.overrideWithValue(_FakePaymentsRepository()),
      ],
    );
    addTearDown(container.dispose);

    final provider = historyControllerProvider(_scope);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    final notifier = container.read(provider.notifier);

    await expectLater(notifier.refresh(), throwsA(isA<AuthenticationException>()));

    final state = container.read(provider);
    expect(state.hasError, isTrue);
  });
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

/// İlk 'customer-a' isteğini bir Completer serbest bırakana kadar bekletir,
/// diğer tüm isteklere hemen yanıt verir. Filtre-yarışı testinde kullanılır.
class _SlowFirstCustomerSessionsRepository implements SessionsRepository {
  String? lastRequestedCustomerId;
  var _slowRequestStarted = false;
  final _slowRequestCompleter = Completer<void>();

  void completeSlowRequest() {
    if (!_slowRequestCompleter.isCompleted) _slowRequestCompleter.complete();
  }

  @override
  Future<DateTime> serverNow() async => DateTime.utc(2026, 7, 18, 12);

  @override
  Future<List<Session>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) async {
    lastRequestedCustomerId = filter.customerId;
    if (filter.customerId == 'customer-a' && !_slowRequestStarted) {
      _slowRequestStarted = true;
      await _slowRequestCompleter.future;
    }
    return [_session()];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Her çağrı ağ-dışı bir hata (kimlik doğrulama) fırlatır. Elle-yenile
/// hata-yüzeyleme testinde kullanılır; arka plan (otomatik) yenilemenin bu
/// hatayı yuttuğu, elle yenilemenin ise yüzeye çıkardığı doğrulanır.
class _AlwaysFailingSessionsRepository implements SessionsRepository {
  @override
  Future<DateTime> serverNow() async => DateTime.utc(2026, 7, 18, 12);

  @override
  Future<List<Session>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) async {
    throw const AuthenticationException('Oturum süresi doldu');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
