import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/reports/domain/entities/report_models.dart';

class ReportsController extends AsyncNotifier<ReportOverview?> {
  @override
  Future<ReportOverview?> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading<ReportOverview?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<ReportOverview?> _load() async {
    final business = ref.watch(activeBusinessProvider);
    if (business == null) return null;
    return ref
        .watch(reportsRepositoryProvider)
        .getOverview(
          businessId: business.id,
          currencyCode: business.currencyCode,
          timezone: business.timezone,
        );
  }
}

final reportsControllerProvider =
    AsyncNotifierProvider<ReportsController, ReportOverview?>(
      ReportsController.new,
    );
