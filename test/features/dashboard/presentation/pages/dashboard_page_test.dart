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

void main() {
  testWidgets('dashboard metrikleri ve ikon aksiyonları erişilebilirdir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          activeBusinessProvider.overrideWithValue(_business()),
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

    expect(find.bySemanticsLabel('Aktif İşlem: 2'), findsOneWidget);
    expect(find.byTooltip('Çıkış yap'), findsOneWidget);
    expect(find.byTooltip('Aktif işlemleri yenile'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('Çıkış yap')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      find.textContaining('İlk işleminizi başlatabilirsiniz'),
      findsOneWidget,
    );
  });
}

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardMetrics> getMetrics({required String businessId}) async =>
      DashboardMetrics(
        serverNow: DateTime.utc(2026, 7, 18, 10),
        activeSessionCount: 2,
        todayCompletedCount: 3,
        todayRevenue: Money(minorUnits: 12500, currencyCode: 'TRY'),
      );
}

class _FakeSessionsRepository implements SessionsRepository {
  @override
  Future<List<Session>> getSessions({
    required String businessId,
    String? customerId,
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
