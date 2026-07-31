import 'dart:async';

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
  group('ReportsPage', () {
    testWidgets('yüklenirken ilerleme göstergesi gösterir', (tester) async {
      final repository = _FakeReportsRepository()..completer = Completer();
      await _pump(tester, repository);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hata durumunda tekrar dene gösterir', (tester) async {
      final repository = _FakeReportsRepository()..completer = Completer();
      await _pump(tester, repository);
      repository.completer!.completeError(StateError('sunucu hatası'));
      await tester.pumpAndSettle();

      expect(find.text('Raporlar yüklenemedi.'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsOneWidget);
    });

    testWidgets('aktif işletme yoksa bilgi mesajı gösterir', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeBusinessProvider.overrideWithValue(null),
            reportsRepositoryProvider.overrideWithValue(
              _FakeReportsRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ReportsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Raporlanacak aktif işletme bulunamadı.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'farklı para birimi ve kısmi veri uyarıları ile sıralama listeleri gösterir',
      (tester) async {
        final repository = _FakeReportsRepository(
          overview: _overview(
            excludedCurrencySessionCount: 3,
            isTruncated: true,
            topServices: [
              NamedMoneyRanking(
                name: 'Bilardo',
                count: 5,
                amount: Money(minorUnits: 5000, currencyCode: 'TRY'),
              ),
            ],
          ),
        );
        await _pump(tester, repository);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -4000));
        await tester.pumpAndSettle();

        expect(find.textContaining('farklı para biriminde'), findsOneWidget);
        expect(
          find.textContaining('Rapor veri sınırına ulaştı'),
          findsOneWidget,
        );
        expect(find.text('Bilardo'), findsOneWidget);
      },
    );

    testWidgets('yenile butonu raporu yeniden yükler', (tester) async {
      final repository = _FakeReportsRepository();
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();

      expect(repository.callCount, 2);
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeReportsRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeBusinessProvider.overrideWithValue(_business()),
        reportsRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const ReportsPage()),
    ),
  );
}

ReportOverview _overview({
  int excludedCurrencySessionCount = 0,
  bool isTruncated = false,
  List<NamedMoneyRanking> topServices = const [],
}) => ReportOverview(
  today: _period(1000, 1),
  week: _period(2000, 2),
  month: _period(3000, 3),
  monthServiceRevenue: Money(minorUnits: 2000, currencyCode: 'TRY'),
  monthProductRevenue: Money(minorUnits: 1000, currencyCode: 'TRY'),
  topServices: topServices,
  topProducts: const [],
  topCustomers: const [],
  excludedCurrencySessionCount: excludedCurrencySessionCount,
  isTruncated: isTruncated,
);

RevenuePeriodSummary _period(int amount, int count) => RevenuePeriodSummary(
  finalizedSales: Money(minorUnits: amount, currencyCode: 'TRY'),
  collection: _collection(amount),
  completedCount: count,
);

CollectionPeriodSummary _collection(int amount) {
  final zero = Money.zero('TRY');
  return CollectionPeriodSummary(
    netCollected: Money(minorUnits: amount, currencyCode: 'TRY'),
    cashCollected: Money(minorUnits: amount, currencyCode: 'TRY'),
    cardCollected: zero,
    bankTransferCollected: zero,
    otherCollected: zero,
    refunded: zero,
    outstanding: zero,
  );
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

class _FakeReportsRepository implements ReportsRepository {
  _FakeReportsRepository({ReportOverview? overview})
    : overview = overview ?? _overview();

  final ReportOverview overview;
  Completer<ReportOverview>? completer;
  var callCount = 0;

  @override
  Future<ReportOverview> getOverview({
    required String businessId,
    required String currencyCode,
    required String timezone,
  }) {
    callCount++;
    return completer?.future ?? Future.value(overview);
  }
}
