import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/features/customers/data/datasources/customers_remote_data_source.dart';
import 'package:suretakip/features/customers/data/repositories/customers_repository_impl.dart';

void main() {
  test('müşteri satırını domain modeline doğru eşler', () async {
    final repository = CustomersRepositoryImpl(_FakeCustomersDataSource());

    final customer = (await repository.getCustomers(
      businessId: 'business-1',
      includeInactive: true,
    )).single;

    expect(customer.name, 'Ayşe');
    expect(customer.phone, '555 000 00 00');
    expect(customer.isActive, isTrue);
  });

  test(
    'setCustomerActive yalnız durum ve arşiv kolonlarını gönderir',
    () async {
      final dataSource = _FakeCustomersDataSource();
      final repository = CustomersRepositoryImpl(dataSource);

      await repository.setCustomerActive('customer-1', isActive: false);

      expect(dataSource.updatedValues?.keys.toSet(), {
        'id',
        'is_active',
        'archived_at',
      });
      expect(dataSource.updatedValues?['archived_at'], isNotNull);
    },
  );
}

class _FakeCustomersDataSource implements CustomersRemoteDataSource {
  Map<String, Object?>? updatedValues;

  @override
  Future<List<Map<String, dynamic>>> getCustomers({
    required String businessId,
    required bool includeInactive,
  }) async => [_row];

  @override
  Future<Map<String, dynamic>> getCustomer(String id) async => _row;

  @override
  Future<Map<String, dynamic>> createCustomer(
    Map<String, Object?> values,
  ) async => _row;

  @override
  Future<Map<String, dynamic>> updateCustomer(
    Map<String, Object?> values,
  ) async {
    updatedValues = values;
    return {..._row, ...values};
  }
}

final _row = <String, dynamic>{
  'id': 'customer-1',
  'business_id': 'business-1',
  'name': 'Ayşe',
  'phone': '555 000 00 00',
  'email': null,
  'notes': null,
  'is_active': true,
  'archived_at': null,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};
