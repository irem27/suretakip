import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:suretakip/features/dashboard/data/repositories/dashboard_repository_impl.dart';

void main() {
  test('dashboard RPC satırını metriklere doğru eşler', () async {
    const repository = DashboardRepositoryImpl(_FakeDashboardDataSource());

    final metrics = await repository.getMetrics(businessId: 'business-1');

    expect(metrics.activeSessionCount, 3);
    expect(metrics.todayCompletedCount, 4);
    expect(metrics.todayRevenue.minorUnits, 12500);
    expect(metrics.todayRevenue.currencyCode, 'TRY');
  });

  test('eksik sayısal metrikler güvenli sıfıra eşlenir', () async {
    const repository = DashboardRepositoryImpl(
      _FakeDashboardDataSource(safeZero: true),
    );

    final metrics = await repository.getMetrics(businessId: 'business-1');

    expect(metrics.activeSessionCount, 0);
    expect(metrics.todayCompletedCount, 0);
    expect(metrics.todayRevenue.minorUnits, 0);
  });
}

class _FakeDashboardDataSource implements DashboardRemoteDataSource {
  const _FakeDashboardDataSource({this.safeZero = false});

  final bool safeZero;

  @override
  Future<List<Map<String, dynamic>>> getMetrics(String businessId) async => [
    {
      'server_now': '2026-07-18T10:00:00Z',
      'active_session_count': safeZero ? null : '3',
      'today_completed_count': safeZero ? 'geçersiz' : 4,
      'today_revenue_minor': safeZero ? null : 12500,
      'currency_code': 'TRY',
    },
  ];
}
