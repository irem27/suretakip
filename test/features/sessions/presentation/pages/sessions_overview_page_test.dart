import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/pages/sessions_overview_page.dart';

void main() {
  testWidgets('yükleme sırasında ilerleme göstergesi görünür', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          openSessionsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MaterialApp(home: SessionsOverviewPage()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('hata durumunda Türkçe mesaj ve tekrar dene görünür', (
    tester,
  ) async {
    final sessions = _FakeSessionsListController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(sessions: sessions),
          openSessionsProvider.overrideWith(
            (ref) => Stream.error(StateError('boom')),
          ),
        ],
        child: const MaterialApp(home: SessionsOverviewPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aktif işlemler yüklenemedi.'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tekrar Dene'));
    await tester.pump();

    expect(sessions.refreshCount, 1);
  });

  testWidgets('açık işlem yoksa boş durum mesajı görünür', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          openSessionsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: SessionsOverviewPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Şu anda devam eden işlem yok.'), findsOneWidget);
  });

  testWidgets('açık işlemler müşteri adı ve saat bilgisiyle listelenir', (
    tester,
  ) async {
    final session = _session();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          openSessionsProvider.overrideWith((ref) => Stream.value([session])),
        ],
        child: const MaterialApp(home: SessionsOverviewPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
  });

  testWidgets('misafir işlem müşteri adı yoksa Misafir müşteri gösterir', (
    tester,
  ) async {
    final session = _session(customerId: null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          openSessionsProvider.overrideWith((ref) => Stream.value([session])),
        ],
        child: const MaterialApp(home: SessionsOverviewPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Misafir müşteri'), findsOneWidget);
  });

  testWidgets('yenile düğmesi listeyi yeniler', (tester) async {
    final sessions = _FakeSessionsListController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(sessions: sessions),
          openSessionsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: SessionsOverviewPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aktif işlemleri yenile'));
    await tester.pump();

    expect(sessions.refreshCount, 1);
  });

  testWidgets('yeni işlem başlat düğmesi başlatma sayfasına yönlendirir', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/sessions',
      routes: [
        GoRoute(
          path: '/sessions',
          builder: (context, state) => const SessionsOverviewPage(),
        ),
        GoRoute(
          path: '/sessions/new',
          name: AppRouteNames.sessionStart,
          builder: (context, state) => const Text('Yeni İşlem Sayfası'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          openSessionsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yeni İşlem Başlat'));
    await tester.pumpAndSettle();

    expect(find.text('Yeni İşlem Sayfası'), findsOneWidget);
  });

  testWidgets('açık işlem satırı detay sayfasına yönlendirir', (tester) async {
    final router = GoRouter(
      initialLocation: '/sessions',
      routes: [
        GoRoute(
          path: '/sessions',
          builder: (context, state) => const SessionsOverviewPage(),
        ),
        GoRoute(
          path: '/sessions/:sessionId',
          name: AppRouteNames.sessionDetail,
          builder: (context, state) =>
              Text('Detay ${state.pathParameters['sessionId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._baseOverrides(),
          openSessionsProvider.overrideWith(
            (ref) => Stream.value([_session()]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ayşe Yılmaz'));
    await tester.pumpAndSettle();

    expect(find.text('Detay session-1'), findsOneWidget);
  });
}

List<Override> _baseOverrides({_FakeSessionsListController? sessions}) => [
  activeBusinessProvider.overrideWithValue(_business()),
  activeBusinessScopeProvider.overrideWithValue((
    businessId: 'business-1',
    generation: 0,
  )),
  customersListControllerProvider.overrideWith(
    () => _FakeCustomersListController(),
  ),
  sessionsListControllerProvider.overrideWith(
    () => sessions ?? _FakeSessionsListController(),
  ),
];

Business _business() => Business(
  id: 'business-1',
  name: 'Test İşletmesi',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _FakeCustomersListController extends CustomersListController {
  @override
  Future<CustomersListState> build(BusinessScope scope) async =>
      CustomersListState(customers: [_customer()], query: '');
}

class _FakeSessionsListController extends SessionsListController {
  int refreshCount = 0;

  @override
  Future<List<Session>> build(BusinessScope scope) async => const [];

  @override
  Future<void> refresh() async => refreshCount++;
}

Customer _customer() => Customer(
  id: 'customer-1',
  businessId: 'business-1',
  name: 'Ayşe Yılmaz',
  phone: null,
  email: null,
  notes: null,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Session _session({String? customerId = 'customer-1'}) => Session(
  id: 'session-1',
  businessId: 'business-1',
  customerId: customerId,
  serviceId: 'service-1',
  openedByMemberId: 'member-1',
  closedByMemberId: null,
  status: SessionStatus.active,
  startedAt: DateTime.utc(2026, 7, 31, 9),
  endedAt: null,
  chargedMinutes: null,
  serviceNameSnapshot: 'Bilardo Masası',
  pricePerMinuteMinorSnapshot: 200,
  roundingIntervalMinutesSnapshot: 1,
  minimumChargeMinutesSnapshot: 0,
  currencyCodeSnapshot: 'TRY',
  serviceSubtotalMinor: null,
  productsSubtotalMinor: null,
  discountMinor: 0,
  taxMinor: 0,
  grandTotalMinor: null,
  notes: null,
  createdAt: DateTime.utc(2026, 7, 31, 9),
  updatedAt: DateTime.utc(2026, 7, 31, 9),
);
