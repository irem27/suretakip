import 'package:suretakip/core/value_objects/money.dart';

final class RevenuePeriodSummary {
  const RevenuePeriodSummary({
    required this.revenue,
    required this.completedCount,
  });

  final Money revenue;
  final int completedCount;
}

final class NamedMoneyRanking {
  const NamedMoneyRanking({
    required this.name,
    required this.count,
    required this.amount,
  });

  final String name;
  final int count;
  final Money amount;
}

final class ReportOverview {
  const ReportOverview({
    required this.today,
    required this.week,
    required this.month,
    required this.monthServiceRevenue,
    required this.monthProductRevenue,
    required this.topServices,
    required this.topProducts,
    required this.topCustomers,
    required this.excludedCurrencySessionCount,
    required this.isTruncated,
  });

  final RevenuePeriodSummary today;
  final RevenuePeriodSummary week;
  final RevenuePeriodSummary month;
  final Money monthServiceRevenue;
  final Money monthProductRevenue;
  final List<NamedMoneyRanking> topServices;
  final List<NamedMoneyRanking> topProducts;
  final List<NamedMoneyRanking> topCustomers;
  final int excludedCurrencySessionCount;
  final bool isTruncated;
}
