import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/features/customers/data/local/local_customer_mappers.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';

final class CustomersListState {
  const CustomersListState({required this.customers, required this.query});

  final List<Customer> customers;
  final String query;

  List<Customer> get visibleCustomers {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return customers;
    return customers
        .where(
          (customer) =>
              customer.name.toLowerCase().contains(normalized) ||
              (customer.phone?.toLowerCase().contains(normalized) ?? false) ||
              (customer.email?.toLowerCase().contains(normalized) ?? false),
        )
        .toList(growable: false);
  }

  CustomersListState copyWith({List<Customer>? customers, String? query}) =>
      CustomersListState(
        customers: customers ?? this.customers,
        query: query ?? this.query,
      );
}

/// Müşteri listesi artık Drift stream'inden gelir (offline-first). İlk oluşumda
/// [offlineCustomersRepositoryProvider] sunucudan mini bootstrap pull tetikler.
final customersDriftStreamProvider = StreamProvider.autoDispose
    .family<List<Customer>, String>(
      (ref, businessId) => ref
          .watch(offlineCustomersRepositoryProvider)
          .watchCustomersDomain(businessId: businessId, includeInactive: true),
    );

/// Her müşterinin senkronizasyon durumu (id → SyncStatus). Liste rozetleri
/// "bu cihaza kaydedildi / senkronize edildi / çakışma" ayrımını gösterir.
final customerSyncStatusesProvider = StreamProvider.autoDispose
    .family<Map<String, SyncStatus>, String>(
      (ref, businessId) => ref
          .watch(offlineCustomersRepositoryProvider)
          .watchCustomers(businessId: businessId, includeInactive: true)
          .map(
            (rows) => {
              for (final row in rows)
                row.id: SyncStatus.fromWire(row.syncStatus),
            },
          ),
    );

class CustomersListController
    extends AutoDisposeFamilyAsyncNotifier<CustomersListState, BusinessScope> {
  var _query = '';

  @override
  Future<CustomersListState> build(BusinessScope scope) async {
    final businessId = scope.businessId;
    if (businessId == null) {
      return CustomersListState(customers: const [], query: _query);
    }
    final streamProvider = customersDriftStreamProvider(businessId);
    final customers = ref.watch(streamProvider);
    return switch (customers) {
      AsyncData(:final value) => CustomersListState(
        customers: value,
        query: _query,
      ),
      AsyncError(:final error, :final stackTrace) => Error.throwWithStackTrace(
        error,
        stackTrace,
      ),
      _ => CustomersListState(
        customers: await ref.watch(streamProvider.future),
        query: _query,
      ),
    };
  }

  Future<void> refresh() async {
    final businessId = arg.businessId;
    if (businessId != null) {
      await ref
          .read(offlineCustomersRepositoryProvider)
          .pullFromServer(businessId);
    }
  }

  void setQuery(String query) {
    if (_query == query) return;
    _query = query;
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(query: query));
  }
}

class CustomerFormController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Yeni müşteriyi offline-first oluşturur: yerel yazım + outbox, sonra push.
  /// İnternet yoksa kayıt cihazda kalır ve listede "bekliyor" olarak görünür.
  Future<Customer?> create(CustomerInput input) async {
    final scope = ref.read(activeBusinessScopeProvider);
    final member = await ref.read(currentMemberProvider(scope).future);
    if (member == null) {
      // Üyelik henüz senkron olmamış olabilir; sessiz null yerine hata durumu
      // üret ki form kullanıcıya geri bildirim verebilsin.
      state = AsyncError(
        const ValidationException(
          'Üyelik bilgisi henüz hazır değil. Lütfen tekrar deneyin.',
        ),
        StackTrace.current,
      );
      return null;
    }

    Customer? created;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final row = await ref
          .read(offlineCustomersRepositoryProvider)
          .createCustomer(input, actorUserId: member.userId);
      created = mapLocalCustomerToDomain(row);
    });
    return state.hasError ? null : created;
  }

  Future<Customer?> updateCustomer(Customer customer) async {
    Customer? updated;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      updated = await ref
          .read(customersRepositoryProvider)
          .updateCustomer(customer);
      await _refreshLocal(customer.businessId, customer.id);
    });
    return state.hasError ? null : updated;
  }

  Future<bool> setActive(String customerId, {required bool isActive}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updated = await ref
          .read(customersRepositoryProvider)
          .setCustomerActive(customerId, isActive: isActive);
      await _refreshLocal(updated.businessId, customerId);
    });
    return !state.hasError;
  }

  /// Online güncelleme/aktiflik değişiminden sonra Drift kopyasını tazeler.
  Future<void> _refreshLocal(String businessId, String customerId) async {
    await ref
        .read(offlineCustomersRepositoryProvider)
        .pullFromServer(businessId);
    ref.invalidate(customerDetailProvider(customerId));
  }
}

final customersListControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CustomersListController, CustomersListState, BusinessScope>(
      CustomersListController.new,
    );

final customerFormControllerProvider =
    AsyncNotifierProvider<CustomerFormController, void>(
      CustomerFormController.new,
    );

/// Müşteri detayını Drift'ten okur (offline çalışır); yoksa online'a düşer.
final customerDetailProvider = FutureProvider.autoDispose
    .family<Customer, String>((ref, customerId) async {
      final local = await ref
          .watch(offlineCustomersRepositoryProvider)
          .getCustomer(customerId);
      if (local != null) return local;
      return ref.watch(customersRepositoryProvider).getCustomer(customerId);
    });
