import 'package:suretakip/core/value_objects/money.dart';

final class RevenuePeriodSummary {
  const RevenuePeriodSummary({
    required this.finalizedSales,
    required this.collection,
    required this.completedCount,
  });

  final Money finalizedSales;
  final CollectionPeriodSummary collection;
  final int completedCount;

  @Deprecated('Kesinleşen satış için finalizedSales kullanın.')
  Money get revenue => finalizedSales;
}

final class CollectionPeriodSummary {
  const CollectionPeriodSummary({
    required this.netCollected,
    required this.cashCollected,
    required this.cardCollected,
    required this.bankTransferCollected,
    required this.otherCollected,
    required this.refunded,
    required this.outstanding,
  });

  final Money netCollected;
  final Money cashCollected;
  final Money cardCollected;
  final Money bankTransferCollected;
  final Money otherCollected;
  final Money refunded;
  final Money outstanding;
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
