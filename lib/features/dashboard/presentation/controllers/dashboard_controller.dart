import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/dashboard/domain/entities/dashboard_metrics.dart';

class DashboardController extends AsyncNotifier<DashboardMetrics?> {
  @override
  Future<DashboardMetrics?> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading<DashboardMetrics?>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<DashboardMetrics?> _load() async {
    final business = ref.watch(activeBusinessProvider);
    if (business == null) return null;
    return ref
        .watch(dashboardRepositoryProvider)
        .getMetrics(businessId: business.id);
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardMetrics?>(
      DashboardController.new,
    );
