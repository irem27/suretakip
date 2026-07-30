import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/errors/supabase_error_guard.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/features/customers/data/datasources/customers_remote_data_source.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';

/// Supabase `.single()` sorgusunda hiç satır dönmediğinde (eşleşen kayıt
/// kalmadığında) PostgREST'in fırlattığı hata kodu.
const _noRowsMatchedCode = 'PGRST116';

class CustomersRepositoryImpl implements CustomersRepository {
  const CustomersRepositoryImpl(
    this._dataSource, {
    AppLogger logger = const NoopAppLogger(),
  }) : _logger = logger;

  final CustomersRemoteDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<List<Customer>> getCustomers({
    required String businessId,
    bool includeInactive = false,
  }) => _guard(() async {
    final rows = await _dataSource.getCustomers(
      businessId: businessId,
      includeInactive: includeInactive,
    );
    return rows.map(_fromJson).toList(growable: false);
  });

  @override
  Future<Customer> getCustomer(String customerId) =>
      _guard(() async => _fromJson(await _dataSource.getCustomer(customerId)));

  @override
  Future<Customer> createCustomer(CustomerInput input) => _guard(
    () async => _fromJson(
      await _dataSource.createCustomer({
        'business_id': input.businessId,
        'name': input.name,
        'phone': input.phone,
        'email': input.email,
        'notes': input.notes,
      }),
    ),
  );

  @override
  Future<Customer> updateCustomer(Customer customer) => _guard(() async {
    try {
      return _fromJson(
        await _dataSource.updateCustomer(
          _values(customer),
          expectedUpdatedAt: customer.updatedAt,
        ),
      );
    } on PostgrestException catch (error) {
      throw _asConflictIfStale(error, hasVersionCheck: true);
    }
  });

  @override
  Future<Customer> setCustomerActive(
    String customerId, {
    required bool isActive,
    DateTime? expectedUpdatedAt,
  }) => _guard(() async {
    try {
      return _fromJson(
        await _dataSource.updateCustomer(
          {
            'id': customerId,
            'is_active': isActive,
            'archived_at': isActive
                ? null
                : DateTime.now().toUtc().toIso8601String(),
          },
          expectedUpdatedAt: expectedUpdatedAt,
        ),
      );
    } on PostgrestException catch (error) {
      throw _asConflictIfStale(
        error,
        hasVersionCheck: expectedUpdatedAt != null,
      );
    }
  });

  /// [hasVersionCheck] true iken "eşleşen satır yok" hatası, sorguya eklenen
  /// `updated_at` filtresinin başarısız olduğu (kayıt bu sırada başka bir
  /// yerden değiştirildiği) anlamına gelir; bu durumda sessiz üzerine yazma
  /// yerine ConflictException fırlatılır. Aksi halde hata olduğu gibi geri
  /// döndürülür ve `_guard` normal Postgres hata eşlemesini uygular.
  Object _asConflictIfStale(
    PostgrestException error, {
    required bool hasVersionCheck,
  }) {
    if (hasVersionCheck && error.code == _noRowsMatchedCode) {
      return const ConflictException(
        'Bu müşteri kaydı, siz düzenlerken başka bir yerden güncellendi. '
        'Lütfen sayfayı yenileyip tekrar deneyin.',
      );
    }
    return error;
  }

  Map<String, Object?> _values(Customer value) => {
    'id': value.id,
    'name': value.name,
    'phone': value.phone,
    'email': value.email,
    'notes': value.notes,
  };

  Customer _fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    notes: json['notes'] as String?,
    isActive: json['is_active'] as bool,
    archivedAt: json['archived_at'] == null
        ? null
        : DateTime.parse(json['archived_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Future<T> _guard<T>(Future<T> Function() operation) => SupabaseErrorGuard.run(
    operation,
    logger: _logger,
    context: 'CustomersRepository',
  );
}
