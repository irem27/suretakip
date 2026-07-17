import 'package:suretakip/features/customers/domain/entities/customer.dart';

abstract interface class CustomersRepository {
  Future<List<Customer>> getCustomers({
    required String businessId,
    bool includeInactive = false,
  });

  Future<Customer> getCustomer(String customerId);

  Future<Customer> createCustomer(Customer customer);

  Future<Customer> updateCustomer(Customer customer);
}
