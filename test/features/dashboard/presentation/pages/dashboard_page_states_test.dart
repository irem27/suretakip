import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/auth/presentation/controllers/auth_controllers.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/dashboard/domain/entities/dashboard_metrics.dart';
import 'package:suretakip/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:suretakip/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';

void main() {
  testWidgets('çıkış yapılırken buton yükleniyor göstergesi gösterir', (
    tester,
  ) async {
    final signOut = _FakeSignOutController()..hold = true;
    await _pump(tester, signOutController: signOut);

    signOut.setLoading();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final signOutButton = find.ancestor(
      of: find.byType(CircularProgressIndicator),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(signOutButton).onPressed, isNull);
  });

  testWidgets('çıkış hatası domain mesajıyla snackbar gösterir', (
    tester,
  ) async {
    final signOut = _FakeSignOutController();
    await _pump(tester, signOutController: signOut);

    signOut.fail(const AuthenticationException('Oturum geçersiz.'));
    await tester.pump();

    expect(find.text('Oturum geçersiz.'), findsOneWidget);
  });

  testWidgets('çıkış hatası genel mesajla snackbar gösterir', (tester) async {
    final signOut = _FakeSignOutController();
    await _pump(tester, signOutController: signOut);

    signOut.fail(StateError('bilinmeyen'));
    await tester.pump();

    expect(
      find.text('Çıkış yapılamadı. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
  });

  testWidgets('ana sayfa metrikleri yüklenirken ilerleme çubuğu gösterir', (
    tester,
  ) async {
    final dashboard = _FakeDashboardController()..hold = true;
    await _pump(tester, dashboardController: dashboard);

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('ana sayfa metrikleri hatası tekrar dene ile yenilenir', (
    tester,
  ) async {
    final dashboard = _FakeDashboardController()
      ..failure = const DatabaseException('Veritabanı hatası.');
    await _pump(tester, dashboardController: dashboard);

    expect(find.text('Ana sayfa metrikleri yüklenemedi.'), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, 'Tekrar Dene');
    await tester.tap(retry);
    await tester.pump();

    expect(dashboard.refreshCount, 1);
  });

  testWidgets('açık işlemler yüklenirken kart içinde döner gösterir', (
    tester,
  ) async {
    await _pump(
      tester,
      openSessionsStream: const Stream<List<Session>>.empty(),
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('açık işlemler hatası tekrar dene ile yenilenir', (tester) async {
    final sessions = _FakeSessionsListController();
    await _pump(
      tester,
      sessionsController: sessions,
      openSessionsStream: Stream<List<Session>>.error(
        const DatabaseException('Veritabanı hatası.'),
      ),
    );

    expect(find.text('Aktif işlemler yüklenemedi.'), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, 'Tekrar Dene');
    await tester.ensureVisible(retry);
    await tester.pump();
    await tester.tap(retry);
    await tester.pump();

    expect(sessions.refreshCount, 1);
  });

  testWidgets('son tamamlanan işlemler listelenir ve detaya gider', (
    tester,
  ) async {
    final router = _router();
    final container = _container(
      sessionsController: _FakeSessionsListController()
        ..sessions = [
          _session('session-1', status: SessionStatus.completed),
          _session('session-2', status: SessionStatus.active),
        ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('session-1'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('session-1'), findsOneWidget);
    expect(find.text('session-2'), findsNothing);

    await tester.tap(find.text('session-1'));
    await tester.pumpAndSettle();

    expect(find.text('session-detail-session-1'), findsOneWidget);
  });

  testWidgets('tanımlar kartına dokunulunca tanımlar ekranına gider', (
    tester,
  ) async {
    final router = _router();
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tanımlar').last,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tanımlar').last);
    await tester.pumpAndSettle();

    expect(find.text('definitions-hedef'), findsOneWidget);
  });

  testWidgets('geçmiş ve raporlar kartları doğru ekranlara gider', (
    tester,
  ) async {
    for (final target in ['İşlem Geçmişi', 'Raporlar']) {
      final router = _router();
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text(target),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(target));
      await tester.pumpAndSettle();

      expect(
        find.text(
          target == 'İşlem Geçmişi' ? 'history-hedef' : 'reports-hedef',
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('yeni işlem başlat butonu işlem başlatma ekranına gider', (
    tester,
  ) async {
    final router = _router();
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Yeni İşlem Başlat'));
    await tester.pumpAndSettle();

    expect(find.text('session-start-hedef'), findsOneWidget);
  });
}

ProviderContainer _container({
  _FakeSignOutController? signOutController,
  _FakeDashboardController? dashboardController,
  _FakeSessionsListController? sessionsController,
  Stream<List<Session>>? openSessionsStream,
}) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWithValue(
      AppDatabase.forExecutor(NativeDatabase.memory()),
    ),
    currentUserProvider.overrideWithValue(null),
    userBusinessesProvider.overrideWith((ref) async => [_business()]),
    activeBusinessProvider.overrideWithValue(_business()),
    openSessionsProvider.overrideWith(
      (ref) => openSessionsStream ?? Stream.value(const <Session>[]),
    ),
    signOutControllerProvider.overrideWith(
      () => signOutController ?? _FakeSignOutController(),
    ),
    dashboardControllerProvider.overrideWith(
      () => dashboardController ?? _FakeDashboardController(),
    ),
    sessionsListControllerProvider.overrideWith(
      () => sessionsController ?? _FakeSessionsListController(),
    ),
  ],
);

GoRouter _router() => GoRouter(
  initialLocation: AppRoutes.dashboard,
  routes: [
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (_, _) => const DashboardPage(),
    ),
    GoRoute(
      name: AppRouteNames.history,
      path: AppRoutes.history,
      builder: (_, _) => const Scaffold(body: Text('history-hedef')),
    ),
    GoRoute(
      name: AppRouteNames.reports,
      path: AppRoutes.reports,
      builder: (_, _) => const Scaffold(body: Text('reports-hedef')),
    ),
    GoRoute(
      name: AppRouteNames.definitions,
      path: AppRoutes.definitions,
      builder: (_, _) => const Scaffold(body: Text('definitions-hedef')),
    ),
    GoRoute(
      name: AppRouteNames.sessionStart,
      path: AppRoutes.sessionStart,
      builder: (_, _) => const Scaffold(body: Text('session-start-hedef')),
    ),
    GoRoute(
      name: AppRouteNames.sessionDetail,
      path: AppRoutes.sessionDetail,
      builder: (context, state) => Scaffold(
        body: Text('session-detail-${state.pathParameters['sessionId']}'),
      ),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  _FakeSignOutController? signOutController,
  _FakeDashboardController? dashboardController,
  _FakeSessionsListController? sessionsController,
  Stream<List<Session>>? openSessionsStream,
}) async {
  final container = _container(
    signOutController: signOutController,
    dashboardController: dashboardController,
    sessionsController: sessionsController,
    openSessionsStream: openSessionsStream,
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DashboardPage()),
    ),
  );
  await tester.pump();
}

class _FakeSignOutController extends SignOutController {
  bool hold = false;

  @override
  Future<void> build() async {}

  void setLoading() => state = const AsyncLoading();

  void fail(Object error) =>
      state = AsyncError<void>(error, StackTrace.current);
}

class _FakeDashboardController extends DashboardController {
  bool hold = false;
  Object? failure;
  int refreshCount = 0;

  @override
  Future<DashboardMetrics?> build(BusinessScope scope) async {
    if (hold) return Completer<DashboardMetrics?>().future;
    if (failure != null) throw failure!;
    return DashboardMetrics(
      activeSessionCount: 0,
      todayCompletedCount: 0,
      todayRevenue: Money.zero('TRY'),
    );
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

class _FakeSessionsListController extends SessionsListController {
  bool hold = false;
  Object? failure;
  List<Session> sessions = const [];
  int refreshCount = 0;

  @override
  Future<List<Session>> build(BusinessScope scope) async {
    if (hold) return Completer<List<Session>>().future;
    if (failure != null) throw failure!;
    return sessions;
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
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

Session _session(String id, {required SessionStatus status}) => Session(
  id: id,
  businessId: 'business-1',
  customerId: null,
  serviceId: 'service-1',
  openedByMemberId: 'member-1',
  closedByMemberId: 'member-1',
  status: status,
  startedAt: DateTime.utc(2026, 7, 18, 8),
  endedAt: status == SessionStatus.completed
      ? DateTime.utc(2026, 7, 18, 9)
      : null,
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
  grandTotalMinor: status == SessionStatus.completed ? 6000 : null,
  notes: null,
  createdAt: DateTime.utc(2026, 7, 18, 8),
  updatedAt: DateTime.utc(2026, 7, 18, 9),
);
