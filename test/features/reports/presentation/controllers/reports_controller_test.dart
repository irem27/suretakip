import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/reports/domain/entities/report_models.dart';
import 'package:suretakip/features/reports/domain/repositories/reports_repository.dart';
import 'package:suretakip/features/reports/presentation/controllers/reports_controller.dart';

void main() {
  test(
    'controller aktif işletme kimliği, para birimi ve timezone ile yükler',
    () async {
      final repository = _FakeReportsRepository();
      final container = ProviderContainer(
        overrides: [
          activeBusinessProvider.overrideWithValue(_business()),
          reportsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final report = await container.read(
        reportsControllerProvider(_scope).future,
      );

      expect(report, isNotNull);
      expect(repository.businessId, 'business-1');
      expect(repository.currencyCode, 'TRY');
      expect(repository.timezone, 'Europe/Istanbul');
    },
  );
}

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

class _FakeReportsRepository implements ReportsRepository {
  String? businessId;
  String? currencyCode;
  String? timezone;

  @override
  Future<ReportOverview> getOverview({
    required String businessId,
    required String currencyCode,
    required String timezone,
  }) async {
    this.businessId = businessId;
    this.currencyCode = currencyCode;
    this.timezone = timezone;
    final zero = Money.zero(currencyCode);
    final collection = CollectionPeriodSummary(
      netCollected: zero,
      cashCollected: zero,
      cardCollected: zero,
      bankTransferCollected: zero,
      otherCollected: zero,
      refunded: zero,
      outstanding: zero,
    );
    final period = RevenuePeriodSummary(
      finalizedSales: zero,
      collection: collection,
      completedCount: 0,
    );
    return ReportOverview(
      today: period,
      week: period,
      month: period,
      monthServiceRevenue: zero,
      monthProductRevenue: zero,
      topServices: const [],
      topProducts: const [],
      topCustomers: const [],
      excludedCurrencySessionCount: 0,
      isTruncated: false,
    );
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
