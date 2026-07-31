import 'package:suretakip/features/dashboard/domain/entities/dashboard_metrics.dart';

abstract interface class DashboardRepository {
  Future<DashboardMetrics> getMetrics({required String businessId});
}
