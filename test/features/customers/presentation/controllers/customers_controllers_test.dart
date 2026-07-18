import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';

void main() {
  test('liste controller müşterileri yükler', () async {
    final repository = _FakeCustomersRepository(customers: [_customer()]);
    final container = _container(repository);
    addTearDown(container.dispose);

    final state = await container.read(
      customersListControllerProvider(_scope).future,
    );

    expect(state.customers, hasLength(1));
    expect(repository.businessId, 'business-1');
    expect(repository.includeInactive, isTrue);
  });

  test('arama adı telefon ve e-posta üzerinde client-side çalışır', () async {
    final repository = _FakeCustomersRepository(
      customers: [
        _customer(),
        _customer(
          id: 'customer-2',
          name: 'Banu Korkmaz',
          phone: '05321234567',
          email: 'banu@example.com',
        ),
      ],
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final provider = customersListControllerProvider(_scope);
    final subscription = container.listen(
      provider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(provider.future);

    container.read(provider.notifier).setQuery('example');

    final state = container.read(provider).requireValue;
    expect(state.visibleCustomers.single.id, 'customer-2');
  });

  test('form controller CustomerInput ile müşteri oluşturur', () async {
    final repository = _FakeCustomersRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    const input = CustomerInput(
      businessId: 'business-1',
      name: 'Can Yılmaz',
      phone: '5551234567',
      email: 'can@example.com',
    );

    final created = await container
        .read(customerFormControllerProvider.notifier)
        .create(input);

    expect(created?.id, 'customer-1');
    expect(repository.createdInput, same(input));
  });

  test('setActive yalnız id ve durumu iletir', () async {
    final repository = _FakeCustomersRepository(customers: [_customer()]);
    final container = _container(repository);
    addTearDown(container.dispose);

    final ok = await container
        .read(customerFormControllerProvider.notifier)
        .setActive('customer-1', isActive: false);

    expect(ok, isTrue);
    expect(repository.toggledId, 'customer-1');
    expect(repository.toggledActive, isFalse);
    expect(repository.updatedCustomer, isNull);
  });
}

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

ProviderContainer _container(_FakeCustomersRepository repository) =>
    ProviderContainer(
      overrides: [
        customersRepositoryProvider.overrideWithValue(repository),
        activeBusinessProvider.overrideWithValue(_business()),
      ],
    );

Business _business() => Business(
  id: 'business-1',
  name: 'Test İşletmesi',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Customer _customer({
  String id = 'customer-1',
  String name = 'Ahmet Erdemir',
  String? phone,
  String? email,
}) => Customer(
  id: id,
  businessId: 'business-1',
  name: name,
  phone: phone,
  email: email,
  notes: null,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _FakeCustomersRepository implements CustomersRepository {
  _FakeCustomersRepository({List<Customer>? customers})
    : customers = customers ?? [_customer()];

  final List<Customer> customers;
  String? businessId;
  bool? includeInactive;
  CustomerInput? createdInput;
  Customer? updatedCustomer;
  String? toggledId;
  bool? toggledActive;

  @override
  Future<Customer> createCustomer(CustomerInput input) async {
    createdInput = input;
    return _customer().copyWith(
      name: input.name,
      phone: input.phone,
      email: input.email,
      notes: input.notes,
    );
  }

  @override
  Future<Customer> getCustomer(String customerId) async =>
      customers.firstWhere((customer) => customer.id == customerId);

  @override
  Future<List<Customer>> getCustomers({
    required String businessId,
    bool includeInactive = false,
  }) async {
    this.businessId = businessId;
    this.includeInactive = includeInactive;
    return customers;
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    updatedCustomer = customer;
    return customer;
  }

  @override
  Future<Customer> setCustomerActive(
    String customerId, {
    required bool isActive,
  }) async {
    toggledId = customerId;
    toggledActive = isActive;
    return customers
        .firstWhere((customer) => customer.id == customerId)
        .copyWith(isActive: isActive);
  }
}
