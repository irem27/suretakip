import 'package:suretakip/core/value_objects/money.dart';

final class DashboardMetrics {
  const DashboardMetrics({
    required this.activeSessionCount,
    required this.todayCompletedCount,
    required this.todayRevenue,
  });

  final int activeSessionCount;
  final int todayCompletedCount;
  final Money todayRevenue;
}
