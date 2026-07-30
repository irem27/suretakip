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

  test('null sayısal metrikler (boş toplam) güvenli sıfıra eşlenir', () async {
    // null meşrudur (ör. hiç seans yokken SUM null döner) → 0.
    const repository = DashboardRepositoryImpl(
      _FakeDashboardDataSource(nullNumerics: true),
    );

    final metrics = await repository.getMetrics(businessId: 'business-1');

    expect(metrics.activeSessionCount, 0);
    expect(metrics.todayCompletedCount, 0);
    expect(metrics.todayRevenue.minorUnits, 0);
  });

  test('ayrıştırılamayan sayısal alan sessizce 0 yerine hata fırlatır', () {
    // Bozuk/ayrıştırılamayan değer sessizce 0 gösterilip yanlış finansal
    // değer üretmemeli; SupabaseErrorGuard'ın yakalayabilmesi için throw eder.
    const repository = DashboardRepositoryImpl(
      _FakeDashboardDataSource(invalidNumeric: true),
    );

    expect(
      repository.getMetrics(businessId: 'business-1'),
      throwsA(anything),
    );
  });
}

class _FakeDashboardDataSource implements DashboardRemoteDataSource {
  const _FakeDashboardDataSource({
    this.nullNumerics = false,
    this.invalidNumeric = false,
  });

  final bool nullNumerics;
  final bool invalidNumeric;

  @override
  Future<List<Map<String, dynamic>>> getMetrics(String businessId) async => [
    {
      'server_now': '2026-07-18T10:00:00Z',
      'active_session_count': nullNumerics ? null : '3',
      'today_completed_count': invalidNumeric
          ? 'geçersiz'
          : nullNumerics
          ? null
          : 4,
      'today_revenue_minor': nullNumerics ? null : 12500,
      'currency_code': 'TRY',
    },
  ];
}
