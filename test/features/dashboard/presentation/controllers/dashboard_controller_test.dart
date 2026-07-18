import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/dashboard/domain/entities/dashboard_metrics.dart';
import 'package:suretakip/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:suretakip/features/dashboard/presentation/controllers/dashboard_controller.dart';

void main() {
  test('controller aktif işletme kimliğiyle metrikleri yükler', () async {
    final repository = _FakeDashboardRepository();
    final container = ProviderContainer(
      overrides: [
        activeBusinessProvider.overrideWithValue(_business()),
        dashboardRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final metrics = await container.read(
      dashboardControllerProvider(_businessScope).future,
    );

    expect(metrics, isNotNull);
    expect(repository.businessId, 'business-1');
    expect(metrics!.activeSessionCount, 2);
    expect(metrics.todayRevenue, Money(minorUnits: 12500, currencyCode: 'TRY'));
  });

  test('aktif işletme yoksa repository çağrılmaz', () async {
    final repository = _FakeDashboardRepository();
    final container = ProviderContainer(
      overrides: [
        activeBusinessProvider.overrideWithValue(null),
        dashboardRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final metrics = await container.read(
      dashboardControllerProvider(_emptyScope).future,
    );

    expect(metrics, isNull);
    expect(repository.businessId, isNull);
  });
}

const BusinessScope _businessScope = (businessId: 'business-1', generation: 0);
const BusinessScope _emptyScope = (businessId: null, generation: 0);

class _FakeDashboardRepository implements DashboardRepository {
  String? businessId;

  @override
  Future<DashboardMetrics> getMetrics({required String businessId}) async {
    this.businessId = businessId;
    return DashboardMetrics(
      activeSessionCount: 2,
      todayCompletedCount: 3,
      todayRevenue: Money(minorUnits: 12500, currencyCode: 'TRY'),
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
