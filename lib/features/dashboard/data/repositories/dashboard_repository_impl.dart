import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/errors/supabase_error_guard.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:suretakip/features/dashboard/domain/entities/dashboard_metrics.dart';
import 'package:suretakip/features/dashboard/domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(
    this._dataSource, {
    AppLogger logger = const NoopAppLogger(),
  }) : _logger = logger;

  final DashboardRemoteDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<DashboardMetrics> getMetrics({required String businessId}) =>
      _guard(() async {
        final rows = await _dataSource.getMetrics(businessId);
        if (rows.isEmpty) {
          throw const DatabaseException('Dashboard metrikleri alınamadı.');
        }
        final row = rows.first;
        // RPC ayrıca server_now döndürür; dashboard onu kullanmadığı için
        // modele taşınmıyor. Canlı sayaç ayrı server_now() RPC'siyle çalışır.
        return DashboardMetrics(
          activeSessionCount: _int(row['active_session_count']),
          todayCompletedCount: _int(row['today_completed_count']),
          todayRevenue: Money(
            minorUnits: _int(row['today_revenue_minor']),
            currencyCode: row['currency_code'] as String,
          ),
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
    context: 'DashboardRepository',
  );
}
