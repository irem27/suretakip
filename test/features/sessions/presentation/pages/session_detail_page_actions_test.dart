import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/domain/entities/business_capabilities.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';
import 'package:suretakip/features/payments/presentation/controllers/payments_controller.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/pages/session_detail_page.dart';

import '../../../../helpers/fake_monotonic_clock.dart';

void main() {
  testWidgets('duraklat düğmesi resume/pause aksiyonlarını çağırır', (
    tester,
  ) async {
    final actions = _FakeSessionActions();
    await _pump(tester, _activeState(), actions: actions);

    await tester.tap(find.text('Duraklat'));
    await tester.pumpAndSettle();

    expect(actions.pauseCalls, 1);
  });

  testWidgets('duraklatılmış işlemde Devam Et resume çağırır', (tester) async {
    final actions = _FakeSessionActions();
    await _pump(tester, _pausedState(), actions: actions);

    expect(find.text('DURAKLATILDI'), findsOneWidget);
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();

    expect(actions.resumeCalls, 1);
  });

  testWidgets('durum değiştirme başarısız olursa hata mesajı gösterir', (
    tester,
  ) async {
    final actions = _FakeSessionActions()..shouldSucceed = false;
    await _pump(tester, _activeState(), actions: actions);

    await tester.tap(find.text('Duraklat'));
    await tester.pumpAndSettle();

    expect(find.text('İşlem durumu değiştirilemedi.'), findsOneWidget);
  });

  testWidgets('vazgeç seçilirse iptal işlemi çağrılmaz', (tester) async {
    final actions = _FakeSessionActions();
    await _pump(tester, _activeState(), actions: actions);

    await tester.tap(find.text('İşlemi İptal Et').last);
    await tester.pumpAndSettle();
    expect(find.text('İşlemi iptal et'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(actions.cancelCalls, 0);
  });

  testWidgets('iptal onaylanınca dashboard’a döner ve snackbar gösterir', (
    tester,
  ) async {
    final actions = _FakeSessionActions();
    final router = GoRouter(
      initialLocation: '/sessions/session-1',
      routes: [
        GoRoute(
          name: AppRouteNames.sessionDetail,
          path: '/sessions/:sessionId',
          builder: (context, state) =>
              const SessionDetailPage(sessionId: 'session-1'),
        ),
        GoRoute(
          name: AppRouteNames.dashboard,
          path: '/dashboard',
          builder: (context, state) => const Text('Ana Sayfa'),
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionDetailProvider(
            'session-1',
          ).overrideWith((ref) => _activeState()),
          sessionActionsControllerProvider.overrideWith(() => actions),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('İşlemi İptal Et').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('İptal Et'));
    await tester.pumpAndSettle();

    expect(actions.cancelCalls, 1);
    expect(find.text('Ana Sayfa'), findsOneWidget);
  });

  testWidgets('iptal başarısız olursa hata mesajı gösterir', (tester) async {
    final actions = _FakeSessionActions()..shouldSucceed = false;
    await _pump(tester, _activeState(), actions: actions);

    await tester.tap(find.text('İşlemi İptal Et').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('İptal Et'));
    await tester.pumpAndSettle();

    expect(find.text('İşlem iptal edilemedi.'), findsOneWidget);
  });

  testWidgets(
    'tamamlanan işlemde ödeme paneli ve tamamlanmış işlemi iptal düğmesi görünür',
    (tester) async {
      await _pump(
        tester,
        _completedState(),
        canManagePayments: true,
        withPayments: true,
      );

      expect(find.text('Ödeme'), findsOneWidget);
      expect(find.text('Ödeme Al'), findsOneWidget);
      expect(find.text('Tamamlanan İşlemi İptal Et'), findsOneWidget);
    },
  );

  testWidgets('ödeme özeti yüklenemezse tekrar dene düğmesi görünür', (
    tester,
  ) async {
    await _pump(
      tester,
      _completedState(),
      canManagePayments: true,
      paymentError: true,
    );

    expect(find.text('Ödeme bilgileri yüklenemedi.'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tekrar Dene'));
    await tester.pump();
  });

  testWidgets('eklenen ürünler satır olarak listelenir', (tester) async {
    await _pump(tester, _activeStateWithItems());

    expect(find.text('Su'), findsOneWidget);
    expect(find.text('2 adet'), findsOneWidget);
    expect(find.text('1 satır'), findsOneWidget);
  });

  testWidgets('not eklenmişse not kartı görünür', (tester) async {
    await _pump(tester, _activeStateWithNote());

    expect(find.text('Not'), findsOneWidget);
    expect(find.text('Müşteri özel istek belirtti.'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  SessionDetailState state, {
  _FakeSessionActions? actions,
  bool canManagePayments = false,
  bool withPayments = false,
  bool paymentError = false,
}) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final overrides = <Override>[
    sessionDetailProvider('session-1').overrideWith((ref) => state),
    sessionActionsControllerProvider.overrideWith(
      () => actions ?? _FakeSessionActions(),
    ),
    businessCapabilitiesProvider.overrideWithValue(
      AsyncData(
        BusinessCapabilities(
          canManageCatalog: canManagePayments,
          canManageMembers: canManagePayments,
          canEditBusinessSettings: canManagePayments,
          canCancelCompletedSession: canManagePayments,
        ),
      ),
    ),
  ];
  if (withPayments) {
    overrides.add(
      sessionPaymentControllerProvider.overrideWith(
        () => _FakePaymentController(_summary()),
      ),
    );
  } else if (paymentError) {
    overrides.add(
      sessionPaymentControllerProvider.overrideWith(
        () => _FakeErrorPaymentController(),
      ),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: SessionDetailPage(sessionId: 'session-1')),
    ),
  );
  await tester.pump();
}

SessionPaymentSummary _summary() => SessionPaymentSummary(
  sessionId: 'session-1',
  sessionTotal: Money(minorUnits: 10500, currencyCode: 'TRY'),
  collected: Money(minorUnits: 4000, currencyCode: 'TRY'),
  refunded: Money(minorUnits: 0, currencyCode: 'TRY'),
  netPaid: Money(minorUnits: 4000, currencyCode: 'TRY'),
  remaining: Money(minorUnits: 6500, currencyCode: 'TRY'),
  paymentStatus: SessionPaymentStatus.partiallyPaid,
  currencyCode: 'TRY',
  payments: const [],
);

class _FakePaymentController extends SessionPaymentController {
  _FakePaymentController(this._summary);

  final SessionPaymentSummary _summary;

  @override
  Future<SessionPaymentSummary> build(String sessionId) async => _summary;
}

class _FakeErrorPaymentController extends SessionPaymentController {
  @override
  Future<SessionPaymentSummary> build(String sessionId) async =>
      throw StateError('ödeme hatası');
}

class _FakeSessionActions extends SessionActionsController {
  bool shouldSucceed = true;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int completeCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> build() async {}

  @override
  Future<bool> pause(String sessionId) async {
    pauseCalls++;
    return shouldSucceed;
  }

  @override
  Future<bool> resume(String sessionId) async {
    resumeCalls++;
    return shouldSucceed;
  }

  @override
  Future<bool> complete({
    required String sessionId,
    int discountMinor = 0,
    int taxMinor = 0,
  }) async {
    completeCalls++;
    return shouldSucceed;
  }

  @override
  Future<bool> cancel(String sessionId) async {
    cancelCalls++;
    return shouldSucceed;
  }
}

SessionDetailState _activeState() => SessionDetailState(
  session: _session(status: SessionStatus.active),
  customerName: null,
  items: const [],
  timeEntries: [
    SessionTimeEntry(
      id: 'entry-1',
      businessId: 'business-1',
      sessionId: 'session-1',
      entryType: TimeEntryType.active,
      startedAt: DateTime.utc(2026, 7, 17, 12),
      endedAt: null,
      createdAt: DateTime.utc(2026, 7, 17, 12),
    ),
  ],
  serverAnchor: DateTime.utc(2026, 7, 17, 12, 10),
  clock: FakeMonotonicClock(),
  clockAnchor: Duration.zero,
);

SessionDetailState _pausedState() => SessionDetailState(
  session: _session(status: SessionStatus.paused),
  customerName: null,
  items: const [],
  timeEntries: [
    SessionTimeEntry(
      id: 'entry-1',
      businessId: 'business-1',
      sessionId: 'session-1',
      entryType: TimeEntryType.paused,
      startedAt: DateTime.utc(2026, 7, 17, 12),
      endedAt: null,
      createdAt: DateTime.utc(2026, 7, 17, 12),
    ),
  ],
  serverAnchor: DateTime.utc(2026, 7, 17, 12, 10),
  clock: FakeMonotonicClock(),
  clockAnchor: Duration.zero,
);

SessionDetailState _completedState() => SessionDetailState(
  session: _session(
    status: SessionStatus.completed,
    chargedMinutes: 30,
    serviceSubtotalMinor: 7500,
    productsSubtotalMinor: 3000,
    grandTotalMinor: 10500,
    endedAt: DateTime.utc(2026, 7, 17, 12, 30),
  ),
  customerName: 'Ali',
  items: const [],
  timeEntries: [
    SessionTimeEntry(
      id: 'entry-1',
      businessId: 'business-1',
      sessionId: 'session-1',
      entryType: TimeEntryType.active,
      startedAt: DateTime.utc(2026, 7, 17, 12),
      endedAt: DateTime.utc(2026, 7, 17, 12, 30),
      createdAt: DateTime.utc(2026, 7, 17, 12),
    ),
  ],
  serverAnchor: DateTime.utc(2026, 7, 17, 13),
  clock: FakeMonotonicClock(),
  clockAnchor: Duration.zero,
);

SessionDetailState _activeStateWithItems() => SessionDetailState(
  session: _session(status: SessionStatus.active),
  customerName: 'Ali',
  items: [
    SessionItem(
      id: 'item-1',
      businessId: 'business-1',
      sessionId: 'session-1',
      productId: 'product-1',
      productNameSnapshot: 'Su',
      skuSnapshot: null,
      unitPriceMinorSnapshot: 500,
      currencyCodeSnapshot: 'TRY',
      quantity: 2,
      discountMinor: 0,
      taxMinor: 0,
      lineTotalMinor: 1000,
      createdAt: DateTime.utc(2026, 7, 17, 12),
      updatedAt: DateTime.utc(2026, 7, 17, 12),
    ),
  ],
  timeEntries: [
    SessionTimeEntry(
      id: 'entry-1',
      businessId: 'business-1',
      sessionId: 'session-1',
      entryType: TimeEntryType.active,
      startedAt: DateTime.utc(2026, 7, 17, 12),
      endedAt: null,
      createdAt: DateTime.utc(2026, 7, 17, 12),
    ),
  ],
  serverAnchor: DateTime.utc(2026, 7, 17, 12, 10),
  clock: FakeMonotonicClock(),
  clockAnchor: Duration.zero,
);

SessionDetailState _activeStateWithNote() => SessionDetailState(
  session: _session(
    status: SessionStatus.active,
    notes: 'Müşteri özel istek belirtti.',
  ),
  customerName: 'Ali',
  items: const [],
  timeEntries: [
    SessionTimeEntry(
      id: 'entry-1',
      businessId: 'business-1',
      sessionId: 'session-1',
      entryType: TimeEntryType.active,
      startedAt: DateTime.utc(2026, 7, 17, 12),
      endedAt: null,
      createdAt: DateTime.utc(2026, 7, 17, 12),
    ),
  ],
  serverAnchor: DateTime.utc(2026, 7, 17, 12, 10),
  clock: FakeMonotonicClock(),
  clockAnchor: Duration.zero,
);

Session _session({
  required SessionStatus status,
  int? chargedMinutes,
  int? serviceSubtotalMinor,
  int? productsSubtotalMinor,
  int? grandTotalMinor,
  DateTime? endedAt,
  String? notes,
}) => Session(
  id: 'session-1',
  businessId: 'business-1',
  customerId: null,
  serviceId: 'service-1',
  openedByMemberId: 'member-1',
  closedByMemberId: null,
  status: status,
  startedAt: DateTime.utc(2026, 7, 17, 12),
  endedAt: endedAt,
  chargedMinutes: chargedMinutes,
  serviceNameSnapshot: 'Koltuk',
  pricePerMinuteMinorSnapshot: 250,
  roundingIntervalMinutesSnapshot: 15,
  minimumChargeMinutesSnapshot: 10,
  currencyCodeSnapshot: 'TRY',
  serviceSubtotalMinor: serviceSubtotalMinor,
  productsSubtotalMinor: productsSubtotalMinor,
  discountMinor: 0,
  taxMinor: 0,
  grandTotalMinor: grandTotalMinor,
  notes: notes,
  createdAt: DateTime.utc(2026, 7, 17, 12),
  updatedAt: DateTime.utc(2026, 7, 17, 12),
);
