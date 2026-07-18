import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/data/datasources/businesses_remote_data_source.dart';
import 'package:suretakip/features/businesses/data/repositories/businesses_repository_impl.dart';
import 'package:suretakip/features/businesses/domain/entities/onboarding_input.dart';

void main() {
  test('işletme satırlarını domain modeline doğru eşler', () async {
    final repository = BusinessesRepositoryImpl(_FakeBusinessesDataSource());

    final business = (await repository.getBusinesses()).single;

    expect(business.id, 'business-1');
    expect(business.currencyCode, 'TRY');
    expect(business.archivedAt, isNull);
  });

  test('onboarding inputunu atomik RPC parametrelerine eşler', () async {
    final dataSource = _FakeBusinessesDataSource();
    final repository = BusinessesRepositoryImpl(dataSource);

    await repository.completeOnboarding(
      OnboardingInput(
        businessName: 'Test İşletmesi',
        timezone: 'Europe/Istanbul',
        serviceName: 'Bilardo',
        servicePricePerMinute: Money(minorUnits: 250, currencyCode: 'TRY'),
        roundingIntervalMinutes: 15,
        minimumChargeMinutes: 10,
      ),
    );

    expect(dataSource.rpcParams?['p_currency_code'], 'TRY');
    expect(dataSource.rpcParams?['p_service_price_per_minute_minor'], 250);
    expect(dataSource.rpcParams?['p_include_product'], isFalse);
    expect(dataSource.rpcParams?['p_product_price_minor'], isNull);
  });
}

class _FakeBusinessesDataSource implements BusinessesRemoteDataSource {
  Map<String, Object?>? rpcParams;

  @override
  Future<List<Map<String, dynamic>>> getBusinesses() async => [_businessRow];

  @override
  Future<Map<String, dynamic>> getBusiness(String businessId) async =>
      _businessRow;

  @override
  Future<Map<String, dynamic>> updateBusiness(
    Map<String, Object?> values,
  ) async => _businessRow;

  @override
  Future<String> completeOnboarding(Map<String, Object?> params) async {
    rpcParams = params;
    return 'business-1';
  }

  @override
  Future<List<Map<String, dynamic>>> getMembers(String businessId) async => [];

  @override
  Future<Map<String, dynamic>> addMember(Map<String, Object?> values) async =>
      _memberRow;

  @override
  Future<Map<String, dynamic>> updateMember(
    Map<String, Object?> values,
  ) async => _memberRow;
}

final _businessRow = <String, dynamic>{
  'id': 'business-1',
  'name': 'Test İşletmesi',
  'currency_code': 'TRY',
  'timezone': 'Europe/Istanbul',
  'is_active': true,
  'archived_at': null,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

final _memberRow = <String, dynamic>{
  'id': 'member-1',
  'business_id': 'business-1',
  'user_id': 'user-1',
  'role': 'owner',
  'is_active': true,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};
