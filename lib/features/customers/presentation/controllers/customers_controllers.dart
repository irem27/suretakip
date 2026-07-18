import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
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

class CustomersListController extends AsyncNotifier<CustomersListState> {
  var _query = '';

  @override
  Future<CustomersListState> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading<CustomersListState>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  void setQuery(String query) {
    if (_query == query) return;
    _query = query;
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(query: query));
  }

  Future<CustomersListState> _load() async {
    final business = ref.watch(activeBusinessProvider);
    if (business == null) {
      return CustomersListState(customers: const [], query: _query);
    }
    final customers = await ref
        .watch(customersRepositoryProvider)
        .getCustomers(businessId: business.id, includeInactive: true);
    return CustomersListState(customers: customers, query: _query);
  }
}

class CustomerFormController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Customer?> create(CustomerInput input) async {
    Customer? created;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      created = await ref
          .read(customersRepositoryProvider)
          .createCustomer(input);
      ref.invalidate(customersListControllerProvider);
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
      ref.invalidate(customersListControllerProvider);
      ref.invalidate(customerDetailProvider(customer.id));
    });
    return state.hasError ? null : updated;
  }

  Future<bool> setActive(String customerId, {required bool isActive}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(customersRepositoryProvider)
          .setCustomerActive(customerId, isActive: isActive);
      ref.invalidate(customersListControllerProvider);
      ref.invalidate(customerDetailProvider(customerId));
    });
    return !state.hasError;
  }
}

final customersListControllerProvider =
    AsyncNotifierProvider<CustomersListController, CustomersListState>(
      CustomersListController.new,
    );

final customerFormControllerProvider =
    AsyncNotifierProvider<CustomerFormController, void>(
      CustomerFormController.new,
    );

final customerDetailProvider = FutureProvider.autoDispose
    .family<Customer, String>(
      (ref, customerId) =>
          ref.watch(customersRepositoryProvider).getCustomer(customerId),
    );
