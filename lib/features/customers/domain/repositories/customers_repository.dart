import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';

abstract interface class CustomersRepository {
  Future<List<Customer>> getCustomers({
    required String businessId,
    bool includeInactive = false,
  });

  Future<Customer> getCustomer(String customerId);

  Future<Customer> createCustomer(CustomerInput input);

  Future<Customer> updateCustomer(Customer customer);

  Future<Customer> setCustomerActive(
    String customerId, {
    required bool isActive,
  });
}
