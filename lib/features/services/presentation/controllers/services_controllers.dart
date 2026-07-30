import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/entities/service_input.dart';

enum ServiceStatusFilter { all, active, inactive }

final class ServicesListState {
  const ServicesListState({required this.services, required this.filter});

  final List<Service> services;
  final ServiceStatusFilter filter;

  List<Service> get visibleServices => switch (filter) {
    ServiceStatusFilter.all => services,
    ServiceStatusFilter.active =>
      services.where((service) => service.isActive).toList(growable: false),
    ServiceStatusFilter.inactive =>
      services.where((service) => !service.isActive).toList(growable: false),
  };

  ServicesListState copyWith({
    List<Service>? services,
    ServiceStatusFilter? filter,
  }) => ServicesListState(
    services: services ?? this.services,
    filter: filter ?? this.filter,
  );
}

class ServicesListController
    extends AutoDisposeFamilyAsyncNotifier<ServicesListState, BusinessScope> {
  var _filter = ServiceStatusFilter.all;
  late BusinessScope _scope;

  @override
  Future<ServicesListState> build(BusinessScope scope) {
    _scope = scope;
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<ServicesListState>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<void> setFilter(ServiceStatusFilter filter) async {
    if (_filter == filter && state.hasValue) return;
    _filter = filter;
    state = const AsyncLoading<ServicesListState>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<ServicesListState> _load() async {
    final businessId = _scope.businessId;
    if (businessId == null) {
      return ServicesListState(services: const [], filter: _filter);
    }
    final services = await ref
        .watch(servicesRepositoryProvider)
        .getServices(
          businessId: businessId,
          includeInactive: _filter != ServiceStatusFilter.active,
        );
    return ServicesListState(services: services, filter: _filter);
  }
}

class ServiceFormController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Service?> create(ServiceInput input) async {
    Service? created;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      created = await ref.read(servicesRepositoryProvider).createService(input);
      ref.invalidate(
        servicesListControllerProvider(ref.read(activeBusinessScopeProvider)),
      );
    });
    return state.hasError ? null : created;
  }

  Future<Service?> updateService(Service service) async {
    Service? updated;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      updated = await ref
          .read(servicesRepositoryProvider)
          .updateService(service);
      ref.invalidate(
        servicesListControllerProvider(ref.read(activeBusinessScopeProvider)),
      );
      ref.invalidate(serviceDetailProvider(service.id));
    });
    return state.hasError ? null : updated;
  }

  /// Aktif/pasif toggle — yalnızca durum kolonlarını yazar (kısmi güncelleme).
  ///
  /// İşlemdeki hizmet id'si `serviceUpdatingIdProvider`'a yazılır ki liste
  /// yalnızca o kartın anahtarını kilitlesin (tüm liste değil).
  Future<bool> setActive(String serviceId, {required bool isActive}) async {
    ref.read(serviceUpdatingIdProvider.notifier).state = serviceId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(servicesRepositoryProvider)
          .setServiceActive(serviceId, isActive: isActive);
      ref.invalidate(
        servicesListControllerProvider(ref.read(activeBusinessScopeProvider)),
      );
      ref.invalidate(serviceDetailProvider(serviceId));
    });
    // AsyncValue.guard rethrow etmez; başarı/hata fark etmeksizin id temizlenir.
    ref.read(serviceUpdatingIdProvider.notifier).state = null;
    return !state.hasError;
  }
}

/// setActive sırasında güncellenen hizmetin id'si; yalnızca ilgili kartın
/// anahtarını devre dışı bırakmak için liste tarafından okunur.
final serviceUpdatingIdProvider = StateProvider<String?>((ref) => null);

final servicesListControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ServicesListController, ServicesListState, BusinessScope>(
      ServicesListController.new,
    );

final serviceFormControllerProvider =
    AsyncNotifierProvider<ServiceFormController, void>(
      ServiceFormController.new,
    );

final serviceDetailProvider = FutureProvider.autoDispose
    .family<Service, String>(
      (ref, serviceId) =>
          ref.watch(servicesRepositoryProvider).getService(serviceId),
    );
