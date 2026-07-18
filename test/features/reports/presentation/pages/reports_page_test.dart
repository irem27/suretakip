import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/theme/app_theme.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/reports/domain/entities/report_models.dart';
import 'package:suretakip/features/reports/domain/repositories/reports_repository.dart';
import 'package:suretakip/features/reports/presentation/pages/reports_page.dart';

void main() {
  testWidgets('rapor metrikleri semantik etiketlidir ve 2.0x yazıda taşmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBusinessProvider.overrideWithValue(_business()),
          reportsRepositoryProvider.overrideWithValue(_FakeReportsRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ReportsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel(RegExp(r'Bugün: .*125,00, 2 tamamlanan işlem\.')),
      findsOneWidget,
    );
  });
}

class _FakeReportsRepository implements ReportsRepository {
  @override
  Future<ReportOverview> getOverview({
    required String businessId,
    required String currencyCode,
    required String timezone,
  }) async => ReportOverview(
    today: _period(12500, 2),
    week: _period(30000, 5),
    month: _period(90000, 10),
    monthServiceRevenue: Money(minorUnits: 70000, currencyCode: 'TRY'),
    monthProductRevenue: Money(minorUnits: 20000, currencyCode: 'TRY'),
    topServices: const [],
    topProducts: const [],
    topCustomers: const [],
    excludedCurrencySessionCount: 0,
    isTruncated: false,
  );
}

RevenuePeriodSummary _period(int amount, int count) => RevenuePeriodSummary(
  revenue: Money(minorUnits: amount, currencyCode: 'TRY'),
  completedCount: count,
);

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
