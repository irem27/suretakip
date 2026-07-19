import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/errors/supabase_error_guard.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:suretakip/features/reports/domain/entities/report_models.dart';
import 'package:suretakip/features/reports/domain/repositories/reports_repository.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  const ReportsRepositoryImpl(
    this._dataSource, {
    AppLogger logger = const NoopAppLogger(),
  }) : _logger = logger;

  final ReportsRemoteDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<ReportOverview> getOverview({
    required String businessId,
    required String currencyCode,
    required String timezone,
  }) => _guard(() async {
    const period = 'month';
    const limit = AppConstants.reportRankingLimit;
    // Tüm aggregate işi DB'de; 4 RPC paralel çağrılır, client toplama yapmaz.
    final (
      summaryRows,
      collectionRows,
      serviceRows,
      productRows,
      customerRows,
    ) = await (
      _dataSource.revenueSummary(businessId),
      _dataSource.collectionSummary(businessId),
      _dataSource.topServices(
        businessId: businessId,
        period: period,
        limit: limit,
      ),
      _dataSource.topProducts(
        businessId: businessId,
        period: period,
        limit: limit,
      ),
      _dataSource.topCustomers(
        businessId: businessId,
        period: period,
        limit: limit,
      ),
    ).wait;

    final byPeriod = {
      for (final row in summaryRows) row['period'] as String: row,
    };
    final collectionsByPeriod = {
      for (final row in collectionRows) row['period'] as String: row,
    };

    Money money(Object? value) =>
        Money(minorUnits: _int(value), currencyCode: currencyCode);

    RevenuePeriodSummary summaryOf(String key) {
      final row = byPeriod[key];
      final collection = collectionsByPeriod[key];
      return RevenuePeriodSummary(
        finalizedSales: money(
          collection?['finalized_sales_minor'] ?? row?['grand_total_minor'],
        ),
        collection: CollectionPeriodSummary(
          netCollected: money(collection?['net_collected_minor']),
          cashCollected: money(collection?['cash_collected_minor']),
          cardCollected: money(collection?['card_collected_minor']),
          bankTransferCollected: money(
            collection?['bank_transfer_collected_minor'],
          ),
          otherCollected: money(collection?['other_collected_minor']),
          refunded: money(collection?['refunded_minor']),
          outstanding: money(collection?['outstanding_minor']),
        ),
        completedCount: _int(row?['completed_count']),
      );
    }

    final monthRow = byPeriod['month'];

    return ReportOverview(
      today: summaryOf('day'),
      week: summaryOf('week'),
      month: summaryOf('month'),
      monthServiceRevenue: Money(
        minorUnits: _int(monthRow?['service_total_minor']),
        currencyCode: currencyCode,
      ),
      monthProductRevenue: Money(
        minorUnits: _int(monthRow?['products_total_minor']),
        currencyCode: currencyCode,
      ),
      topServices: serviceRows
          .map(
            (row) => NamedMoneyRanking(
              name: row['service_name'] as String? ?? '—',
              count: _int(row['completed_count']),
              amount: Money(
                minorUnits: _int(row['service_revenue_minor']),
                currencyCode: currencyCode,
              ),
            ),
          )
          .toList(growable: false),
      topProducts: productRows
          .map(
            (row) => NamedMoneyRanking(
              name: row['product_name'] as String? ?? '—',
              count: _int(row['sold_quantity']),
              amount: Money(
                minorUnits: _int(row['product_revenue_minor']),
                currencyCode: currencyCode,
              ),
            ),
          )
          .toList(growable: false),
      topCustomers: customerRows
          .map(
            (row) => NamedMoneyRanking(
              name: row['customer_name'] as String? ?? 'Bilinmeyen müşteri',
              count: _int(row['completed_count']),
              amount: Money(
                minorUnits: _int(row['spending_minor']),
                currencyCode: currencyCode,
              ),
            ),
          )
          .toList(growable: false),
      // Sunucu tarafı aggregate: kesme ve para-birimi dışı sayım yok.
      excludedCurrencySessionCount: 0,
      isTruncated: false,
    );
  });

  int _int(Object? value) => switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text) ?? 0,
    _ => 0,
  };

  Future<T> _guard<T>(Future<T> Function() operation) => SupabaseErrorGuard.run(
    operation,
    logger: _logger,
    context: 'ReportsRepository',
  );
}
