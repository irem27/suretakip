import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/data/datasources/businesses_remote_data_source.dart';
import 'package:suretakip/features/businesses/data/repositories/businesses_repository_impl.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
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

  test(
    'opsiyonel ürünü onboarding RPC parametrelerine minor-unit ile ekler',
    () async {
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
          productName: 'Maden Suyu',
          productPrice: Money(minorUnits: 1250, currencyCode: 'TRY'),
        ),
      );

      expect(dataSource.rpcParams?['p_include_product'], isTrue);
      expect(dataSource.rpcParams?['p_product_name'], 'Maden Suyu');
      expect(dataSource.rpcParams?['p_product_price_minor'], 1250);
    },
  );

  test('tek işletmeyi ve arşiv tarihini domain modeline eşler', () async {
    final dataSource = _FakeBusinessesDataSource(
      businessRow: {..._businessRow, 'archived_at': '2026-07-18T10:00:00Z'},
    );
    final repository = BusinessesRepositoryImpl(dataSource);

    final business = await repository.getBusiness('business-1');

    expect(dataSource.requestedBusinessId, 'business-1');
    expect(business.archivedAt, DateTime.utc(2026, 7, 18, 10));
  });

  test('işletme güncellemesini soft-delete alanlarıyla iletir', () async {
    final dataSource = _FakeBusinessesDataSource();
    final repository = BusinessesRepositoryImpl(dataSource);
    final archivedAt = DateTime.utc(2026, 7, 18, 10);

    await repository.updateBusiness(
      _businessEntity(isActive: false, archivedAt: archivedAt),
    );

    expect(dataSource.businessValues?['id'], 'business-1');
    expect(dataSource.businessValues?['name'], 'Yeni Ad');
    expect(dataSource.businessValues?['is_active'], isFalse);
    expect(
      dataSource.businessValues?['archived_at'],
      archivedAt.toIso8601String(),
    );
  });

  test('üyeleri eşler ve rol güncellemelerini datasourcea iletir', () async {
    final dataSource = _FakeBusinessesDataSource();
    final repository = BusinessesRepositoryImpl(dataSource);

    final members = await repository.getMembers('business-1');
    final added = await repository.addMember(
      businessId: 'business-1',
      userId: 'user-2',
      role: MemberRole.staff,
    );
    await repository.updateMember(_memberEntity(isActive: false));
    await repository.deactivateMember('member-1');

    expect(members.single.role, MemberRole.owner);
    expect(added.businessId, 'business-1');
    expect(dataSource.requestedMembersBusinessId, 'business-1');
    expect(dataSource.addMemberValues?['user_id'], 'user-2');
    expect(dataSource.addMemberValues?['role'], 'staff');
    expect(dataSource.updateMemberCalls[0]['role'], 'owner');
    expect(dataSource.updateMemberCalls[0]['is_active'], isFalse);
    expect(dataSource.updateMemberCalls[1], {
      'id': 'member-1',
      'is_active': false,
    });
  });
}

class _FakeBusinessesDataSource implements BusinessesRemoteDataSource {
  _FakeBusinessesDataSource({Map<String, dynamic>? businessRow})
    : businessRow = businessRow ?? _businessRow;

  final Map<String, dynamic> businessRow;
  Map<String, Object?>? rpcParams;
  String? requestedBusinessId;
  String? requestedMembersBusinessId;
  Map<String, Object?>? businessValues;
  Map<String, Object?>? addMemberValues;
  final List<Map<String, Object?>> updateMemberCalls = [];

  @override
  Future<List<Map<String, dynamic>>> getBusinesses() async => [businessRow];

  @override
  Future<Map<String, dynamic>> getBusiness(String businessId) async {
    requestedBusinessId = businessId;
    return businessRow;
  }

  @override
  Future<Map<String, dynamic>> updateBusiness(
    Map<String, Object?> values,
  ) async {
    businessValues = values;
    return businessRow;
  }

  @override
  Future<String> completeOnboarding(Map<String, Object?> params) async {
    rpcParams = params;
    return 'business-1';
  }

  @override
  Future<List<Map<String, dynamic>>> getMembers(String businessId) async {
    requestedMembersBusinessId = businessId;
    return [_memberRow];
  }

  @override
  Future<Map<String, dynamic>> addMember(Map<String, Object?> values) async {
    addMemberValues = values;
    return {..._memberRow, 'user_id': values['user_id']};
  }

  @override
  Future<Map<String, dynamic>> updateMember(Map<String, Object?> values) async {
    updateMemberCalls.add(values);
    return _memberRow;
  }
}

Business _businessEntity({required bool isActive, DateTime? archivedAt}) =>
    Business(
      id: 'business-1',
      name: 'Yeni Ad',
      currencyCode: 'TRY',
      timezone: 'Europe/Istanbul',
      isActive: isActive,
      archivedAt: archivedAt,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026, 7, 18),
    );

BusinessMember _memberEntity({required bool isActive}) => BusinessMember(
  id: 'member-1',
  businessId: 'business-1',
  userId: 'user-1',
  role: MemberRole.owner,
  isActive: isActive,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 7, 18),
);

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
