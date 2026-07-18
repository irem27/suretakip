import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/dashboard/domain/entities/dashboard_metrics.dart';

class DashboardController
    extends AutoDisposeFamilyAsyncNotifier<DashboardMetrics?, BusinessScope> {
  @override
  Future<DashboardMetrics?> build(BusinessScope scope) =>
      _load(scope.businessId);

  Future<void> refresh() async {
    state = const AsyncLoading<DashboardMetrics?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(arg.businessId));
  }

  Future<DashboardMetrics?> _load(String? businessId) async {
    if (businessId == null) return null;
    return ref
        .watch(dashboardRepositoryProvider)
        .getMetrics(businessId: businessId);
  }
}

final dashboardControllerProvider = AsyncNotifierProvider.autoDispose
    .family<DashboardController, DashboardMetrics?, BusinessScope>(
      DashboardController.new,
    );
