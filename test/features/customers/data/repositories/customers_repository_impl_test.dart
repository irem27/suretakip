import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/customers/data/datasources/customers_remote_data_source.dart';
import 'package:suretakip/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';

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

  test(
    'updateCustomer, müşterinin bilinen updatedAt değerini iyimser '
    'eşzamanlılık denetimi olarak veri kaynağına iletir',
    () async {
      final dataSource = _FakeCustomersDataSource();
      final repository = CustomersRepositoryImpl(dataSource);
      final customer = _customer();

      await repository.updateCustomer(customer);

      expect(dataSource.capturedExpectedUpdatedAt, customer.updatedAt);
    },
  );

  test(
    'updateCustomer, kayıt başka bir yerden değiştirildiyse (eşleşen satır '
    'kalmadığında) sessizce üzerine yazmak yerine ConflictException fırlatır',
    () async {
      final dataSource = _FakeCustomersDataSource()..throwStaleConflict = true;
      final repository = CustomersRepositoryImpl(dataSource);

      await expectLater(
        repository.updateCustomer(_customer()),
        throwsA(isA<ConflictException>()),
      );
    },
  );

  test(
    'setCustomerActive, expectedUpdatedAt verildiğinde ve kayıt bu sırada '
    'değiştiyse ConflictException fırlatır',
    () async {
      final dataSource = _FakeCustomersDataSource()..throwStaleConflict = true;
      final repository = CustomersRepositoryImpl(dataSource);

      await expectLater(
        repository.setCustomerActive(
          'customer-1',
          isActive: false,
          expectedUpdatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
        ),
        throwsA(isA<ConflictException>()),
      );
    },
  );

  test(
    'setCustomerActive, expectedUpdatedAt verilmediğinde eşleşen satır yok '
    'hatasını ConflictException\'a çevirmez (sürüm denetimi uygulanmadı)',
    () async {
      final dataSource = _FakeCustomersDataSource()..throwStaleConflict = true;
      final repository = CustomersRepositoryImpl(dataSource);

      await expectLater(
        repository.setCustomerActive('customer-1', isActive: false),
        throwsA(isNot(isA<ConflictException>())),
      );
    },
  );
}

Customer _customer() => Customer(
  id: 'customer-1',
  businessId: 'business-1',
  name: 'Ayşe',
  phone: '555 000 00 00',
  email: null,
  notes: null,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
  updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
);

class _FakeCustomersDataSource implements CustomersRemoteDataSource {
  Map<String, Object?>? updatedValues;
  DateTime? capturedExpectedUpdatedAt;
  bool throwStaleConflict = false;

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
    Map<String, Object?> values, {
    DateTime? expectedUpdatedAt,
  }) async {
    updatedValues = values;
    capturedExpectedUpdatedAt = expectedUpdatedAt;
    if (throwStaleConflict) {
      throw const PostgrestException(
        message: 'JSON object requested, multiple (or no) rows returned',
        code: 'PGRST116',
      );
    }
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
