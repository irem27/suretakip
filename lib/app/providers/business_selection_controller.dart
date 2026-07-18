import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:suretakip/features/history/presentation/controllers/history_controller.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/reports/presentation/controllers/reports_controller.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';

class BusinessSelectionController extends Notifier<void> {
  @override
  void build() {}

  void selectBusiness(String businessId) {
    final previousBusinessId = ref.read(activeBusinessProvider)?.id;
    ref.read(selectedBusinessIdProvider.notifier).selectBusiness(businessId);
    final nextBusinessId = ref.read(activeBusinessProvider)?.id;
    if (previousBusinessId == nextBusinessId) return;

    // Yeni nesil, tüm veri provider'larına yeni bir family anahtarı verir.
    // Böylece önceki işletmenin AsyncValue.previous verisi yeni bağlamda
    // hiçbir an okunamaz; aynı işletme içindeki normal refresh davranışı ise
    // kendi family örneğinde korunur.
    ref.read(businessScopeGenerationProvider.notifier).advance();

    // Eski family örneklerini ve detay/form cache'lerini de geçersiz kıl.
    // Devam eden eski isteklerin sonuçları Riverpod tarafından yok sayılır.
    ref
      ..invalidate(currentMemberProvider)
      ..invalidate(businessCapabilitiesProvider)
      ..invalidate(servicesListControllerProvider)
      ..invalidate(serviceFormControllerProvider)
      ..invalidate(serviceDetailProvider)
      ..invalidate(productsListControllerProvider)
      ..invalidate(productFormControllerProvider)
      ..invalidate(productDetailProvider)
      ..invalidate(customersListControllerProvider)
      ..invalidate(customerFormControllerProvider)
      ..invalidate(customerDetailProvider)
      ..invalidate(sessionsListControllerProvider)
      ..invalidate(startSessionControllerProvider)
      ..invalidate(sessionActionsControllerProvider)
      ..invalidate(sessionDetailProvider)
      ..invalidate(openSessionsProvider)
      ..invalidate(dashboardControllerProvider)
      ..invalidate(historyControllerProvider)
      ..invalidate(reportsControllerProvider);
  }
}

final businessSelectionControllerProvider =
    NotifierProvider<BusinessSelectionController, void>(
      BusinessSelectionController.new,
    );
