import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';

abstract interface class CustomersRepository {
  Future<List<Customer>> getCustomers({
    required String businessId,
    bool includeInactive = false,
  });

  Future<Customer> getCustomer(String customerId);

  Future<Customer> createCustomer(CustomerInput input);

  /// [customer.updatedAt] alınırken beklenen değerdir; kayıt bu andan sonra
  /// başka bir yerden değiştirildiyse güncelleme sessizce üzerine yazmak
  /// yerine ConflictException fırlatır (iyimser eşzamanlılık denetimi).
  Future<Customer> updateCustomer(Customer customer);

  /// [expectedUpdatedAt] verilirse iyimser eşzamanlılık denetimi uygulanır:
  /// kayıt bu andan sonra başka bir yerden değiştirildiyse güncelleme
  /// sessizce üzerine yazmak yerine ConflictException fırlatır.
  Future<Customer> setCustomerActive(
    String customerId, {
    required bool isActive,
    DateTime? expectedUpdatedAt,
  });
}
