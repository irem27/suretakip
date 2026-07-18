import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:suretakip/features/reports/data/repositories/reports_repository_impl.dart';

void main() {
  test('rapor RPC satırlarını dönem/sıralama modeline doğru eşler', () async {
    final dataSource = _FakeReportsDataSource();
    final repository = ReportsRepositoryImpl(dataSource);

    final overview = await repository.getOverview(
      businessId: 'business-1',
      currencyCode: 'TRY',
      timezone: 'Europe/Istanbul',
    );

    expect(overview.today.revenue.minorUnits, 15500);
    expect(overview.today.completedCount, 2);
    expect(overview.week.revenue.minorUnits, 40000);
    expect(overview.month.revenue.minorUnits, 120000);
    expect(overview.monthServiceRevenue.minorUnits, 90000);
    expect(overview.monthProductRevenue.minorUnits, 30000);
    expect(overview.topServices.single.name, 'Koltuk');
    expect(overview.topServices.single.count, 2);
    expect(overview.topServices.single.amount.minorUnits, 12500);
    expect(overview.topProducts.single.name, 'Kola');
    expect(overview.topProducts.single.count, 1);
    expect(overview.topCustomers.single.name, 'Ali');
    expect(overview.topCustomers.single.amount.minorUnits, 10500);
    // Sunucu tarafı aggregate: kesme/para birimi dışı sayım olmamalı.
    expect(overview.isTruncated, isFalse);
    expect(overview.excludedCurrencySessionCount, 0);
  });

  test('aylık dönem eksikse sıfırlarla güvenli döner', () async {
    final dataSource = _FakeReportsDataSource(summaryRows: const []);
    final repository = ReportsRepositoryImpl(dataSource);

    final overview = await repository.getOverview(
      businessId: 'business-1',
      currencyCode: 'TRY',
      timezone: 'Europe/Istanbul',
    );

    expect(overview.today.revenue.minorUnits, 0);
    expect(overview.month.completedCount, 0);
    expect(overview.monthServiceRevenue.currencyCode, 'TRY');
  });
}

class _FakeReportsDataSource implements ReportsRemoteDataSource {
  _FakeReportsDataSource({List<Map<String, dynamic>>? summaryRows})
    : summaryRows = summaryRows ?? _defaultSummary;

  final List<Map<String, dynamic>> summaryRows;

  static const _defaultSummary = <Map<String, dynamic>>[
    {
      'period': 'day',
      'completed_count': 2,
      'service_total_minor': 12500,
      'products_total_minor': 3000,
      'grand_total_minor': 15500,
      'currency_code': 'TRY',
    },
    {
      'period': 'week',
      'completed_count': 5,
      'service_total_minor': 32000,
      'products_total_minor': 8000,
      'grand_total_minor': 40000,
      'currency_code': 'TRY',
    },
    {
      'period': 'month',
      'completed_count': 20,
      'service_total_minor': 90000,
      'products_total_minor': 30000,
      'grand_total_minor': 120000,
      'currency_code': 'TRY',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> revenueSummary(String businessId) async =>
      summaryRows;

  @override
  Future<List<Map<String, dynamic>>> topServices({
    required String businessId,
    required String period,
    required int limit,
  }) async => [
    {
      'service_id': 'service-1',
      'service_name': 'Koltuk',
      'completed_count': 2,
      'service_revenue_minor': 12500,
      'currency_code': 'TRY',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> topProducts({
    required String businessId,
    required String period,
    required int limit,
  }) async => [
    {
      'product_id': 'product-1',
      'product_name': 'Kola',
      'sold_quantity': 1,
      'product_revenue_minor': 3000,
      'currency_code': 'TRY',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> topCustomers({
    required String businessId,
    required String period,
    required int limit,
  }) async => [
    {
      'customer_id': 'customer-1',
      'customer_name': 'Ali',
      'completed_count': 1,
      'spending_minor': 10500,
      'currency_code': 'TRY',
    },
  ];
}
