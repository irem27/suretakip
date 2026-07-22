import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/theme/app_theme.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/dashboard/domain/entities/dashboard_metrics.dart';
import 'package:suretakip/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:suretakip/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';
import 'package:suretakip/features/sessions/presentation/controllers/active_sessions_controller.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/widgets/active_sessions_sheet.dart';

void main() {
  testWidgets('dashboard metrikleri ve ikon aksiyonları erişilebilirdir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          userBusinessesProvider.overrideWith((ref) async => [_business()]),
          activeBusinessProvider.overrideWithValue(_business()),
          openSessionsProvider.overrideWith(
            (ref) => Stream.value(const <Session>[]),
          ),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(),
          ),
          sessionsRepositoryProvider.overrideWithValue(
            _FakeSessionsRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Aktif İşlem: 2. Detayları gör'),
      findsOneWidget,
    );
    expect(find.byTooltip('Çıkış yap'), findsOneWidget);
    expect(find.byTooltip('Aktif işlemleri yenile'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('Çıkış yap')).height,
      greaterThanOrEqualTo(48),
    );
    // Boş durum kartı metrik kartlarının altında; görünür alana kaydırılır.
    await tester.scrollUntilVisible(
      find.textContaining('İlk işleminizi başlatabilirsiniz'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('İlk işleminizi başlatabilirsiniz'),
      findsOneWidget,
    );
  });

  testWidgets('aktif işlem metriğine dokununca canlı döküm açılır', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          userBusinessesProvider.overrideWith((ref) async => [_business()]),
          activeBusinessProvider.overrideWithValue(_business()),
          openSessionsProvider.overrideWith(
            (ref) => Stream.value(const <Session>[]),
          ),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(),
          ),
          sessionsRepositoryProvider.overrideWithValue(
            _FakeSessionsRepository(),
          ),
          activeSessionSummariesProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Aktif İşlem: 2. Detayları gör'));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveSessionsSheet), findsOneWidget);
    expect(find.text('Aktif İşlemler'), findsWidgets);
  });

  testWidgets('aktif işlem sıfırken metrik kartı aksiyon sunmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          userBusinessesProvider.overrideWith((ref) async => [_business()]),
          activeBusinessProvider.overrideWithValue(_business()),
          openSessionsProvider.overrideWith(
            (ref) => Stream.value(const <Session>[]),
          ),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(activeSessionCount: 0),
          ),
          sessionsRepositoryProvider.overrideWithValue(
            _FakeSessionsRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Açılacak bir döküm yokken kart salt okunur kalmalı, "Detayları gör"
    // çağrısıyla kullanıcıyı boş bir panele göndermemeli.
    expect(find.bySemanticsLabel('Aktif İşlem: 0'), findsOneWidget);
    expect(find.text('Detayları gör'), findsNothing);
  });

  testWidgets('iki işletmede switcher seçimi ve verileri birlikte değiştirir', (
    tester,
  ) async {
    final dashboardRepository = _FakeDashboardRepository();
    final sessionsRepository = _FakeSessionsRepository();
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        userBusinessesProvider.overrideWith(
          (ref) async => [
            _business(),
            _business(id: 'business-2', name: 'İkinci İşletme'),
          ],
        ),
        dashboardRepositoryProvider.overrideWithValue(dashboardRepository),
        sessionsRepositoryProvider.overrideWithValue(sessionsRepository),
        openSessionsProvider.overrideWith(
          (ref) => Stream.value(const <Session>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final switcher = find.byKey(const ValueKey('business-switcher-business-1'));
    expect(switcher, findsOneWidget);
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    await tester.tap(find.text('İkinci İşletme').last);
    await tester.pumpAndSettle();

    expect(container.read(selectedBusinessIdProvider), 'business-2');
    expect(container.read(activeBusinessProvider)?.id, 'business-2');
    expect(dashboardRepository.requestedBusinessIds.last, 'business-2');
    expect(sessionsRepository.requestedBusinessIds.last, 'business-2');
  });
}

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository({this.activeSessionCount = 2});

  final int activeSessionCount;
  final List<String> requestedBusinessIds = [];

  @override
  Future<DashboardMetrics> getMetrics({required String businessId}) async {
    requestedBusinessIds.add(businessId);
    return DashboardMetrics(
      activeSessionCount: activeSessionCount,
      todayCompletedCount: 3,
      todayRevenue: Money(minorUnits: 12500, currencyCode: 'TRY'),
    );
  }
}

class _FakeSessionsRepository implements SessionsRepository {
  final List<String> requestedBusinessIds = [];

  @override
  Future<List<Session>> getSessions({
    required String businessId,
    String? customerId,
  }) async {
    requestedBusinessIds.add(businessId);
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Business _business({String id = 'business-1', String name = 'Test'}) =>
    Business(
      id: id,
      name: name,
      currencyCode: 'TRY',
      timezone: 'Europe/Istanbul',
      isActive: true,
      archivedAt: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
