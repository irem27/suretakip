import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/reports/domain/entities/report_models.dart';

class ReportsController
    extends AutoDisposeFamilyAsyncNotifier<ReportOverview?, BusinessScope> {
  @override
  Future<ReportOverview?> build(BusinessScope scope) => _load(scope.businessId);

  Future<void> refresh() async {
    state = const AsyncLoading<ReportOverview?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(arg.businessId));
  }

  Future<ReportOverview?> _load(String? businessId) async {
    final business = ref.watch(activeBusinessProvider);
    if (businessId == null || business == null || business.id != businessId) {
      return null;
    }
    return ref
        .watch(reportsRepositoryProvider)
        .getOverview(
          businessId: business.id,
          currencyCode: business.currencyCode,
          timezone: business.timezone,
        );
  }
}

final reportsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ReportsController, ReportOverview?, BusinessScope>(
      ReportsController.new,
    );
