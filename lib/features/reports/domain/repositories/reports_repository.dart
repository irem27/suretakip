import 'package:suretakip/features/reports/domain/entities/report_models.dart';

abstract interface class ReportsRepository {
  Future<ReportOverview> getOverview({
    required String businessId,
    required String currencyCode,
    required String timezone,
  });
}
