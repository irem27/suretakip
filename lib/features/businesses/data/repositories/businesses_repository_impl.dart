import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/supabase_error_guard.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/features/businesses/data/datasources/businesses_remote_data_source.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
import 'package:suretakip/features/businesses/domain/entities/onboarding_input.dart';
import 'package:suretakip/features/businesses/domain/repositories/businesses_repository.dart';

class BusinessesRepositoryImpl implements BusinessesRepository {
  const BusinessesRepositoryImpl(
    this._dataSource, {
    AppLogger logger = const NoopAppLogger(),
  }) : _logger = logger;

  final BusinessesRemoteDataSource _dataSource;
  final AppLogger _logger;

  @override
  Future<List<Business>> getBusinesses() => _guard(() async {
    final rows = await _dataSource.getBusinesses();
    return rows.map(_businessFromJson).toList(growable: false);
  });

  @override
  Future<Business> getBusiness(String businessId) => _guard(
    () async => _businessFromJson(await _dataSource.getBusiness(businessId)),
  );

  @override
  Future<Business> updateBusiness(Business business) => _guard(
    () async => _businessFromJson(
      await _dataSource.updateBusiness({
        'id': business.id,
        'name': business.name,
        'currency_code': business.currencyCode,
        'timezone': business.timezone,
        'is_active': business.isActive,
        'archived_at': business.archivedAt?.toIso8601String(),
      }),
    ),
  );

  @override
  Future<String> completeOnboarding(OnboardingInput input) => _guard(() {
    final product = input.productPrice;
    return _dataSource.completeOnboarding({
      'p_business_name': input.businessName,
      'p_currency_code': input.currencyCode,
      'p_timezone': input.timezone,
      'p_service_name': input.serviceName,
      'p_service_price_per_minute_minor':
          input.servicePricePerMinute.minorUnits,
      'p_service_rounding_interval_minutes': input.roundingIntervalMinutes,
      'p_service_minimum_charge_minutes': input.minimumChargeMinutes,
      'p_include_product': input.includeProduct,
      'p_product_name': input.productName,
      'p_product_price_minor': product?.minorUnits,
    });
  });

  @override
  Future<List<BusinessMember>> getMembers(String businessId) =>
      _guard(() async {
        final rows = await _dataSource.getMembers(businessId);
        return rows.map(_memberFromJson).toList(growable: false);
      });

  @override
  Future<BusinessMember> addMember({
    required String businessId,
    required String userId,
    MemberRole role = MemberRole.staff,
  }) => _guard(() async {
    final memberId = await _dataSource.addMember({
      'p_business_id': businessId,
      'p_user_id': userId,
      'p_role': role.name,
    });
    return _readMember(memberId);
  });

  @override
  Future<BusinessMember> changeMemberRole({
    required String memberId,
    required MemberRole role,
  }) => _guard(() async {
    await _dataSource.updateMemberRole({
      'p_member_id': memberId,
      'p_role': role.name,
    });
    return _readMember(memberId);
  });

  @override
  Future<BusinessMember> setMemberActive({
    required String memberId,
    required bool isActive,
  }) => _guard(() async {
    await _dataSource.setMemberActive({
      'p_member_id': memberId,
      'p_is_active': isActive,
    });
    return _readMember(memberId);
  });

  @override
  Future<void> removeMember(String memberId) =>
      _guard(() => _dataSource.removeMember({'p_member_id': memberId}));

  @override
  Future<void> transferOwnership({
    required String businessId,
    required String toMemberId,
  }) => _guard(
    () => _dataSource.transferOwnership({
      'p_business_id': businessId,
      'p_to_member_id': toMemberId,
    }),
  );

  /// Mutasyon RPC'leri void/uuid döndürür. Güncel satırı sunucudan okuyoruz;
  /// istemci hiçbir alanı (özellikle rol ve is_active) kendi tahmin etmez.
  Future<BusinessMember> _readMember(String memberId) async =>
      _memberFromJson(await _dataSource.getMember(memberId));

  Business _businessFromJson(Map<String, dynamic> json) => Business(
    id: json['id'] as String,
    name: json['name'] as String,
    currencyCode: json['currency_code'] as String,
    timezone: json['timezone'] as String,
    isActive: json['is_active'] as bool,
    archivedAt: _nullableDate(json['archived_at']),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  BusinessMember _memberFromJson(Map<String, dynamic> json) => BusinessMember(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    userId: json['user_id'] as String,
    role: MemberRole.values.byName(json['role'] as String),
    isActive: json['is_active'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  DateTime? _nullableDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  Future<T> _guard<T>(Future<T> Function() operation) => SupabaseErrorGuard.run(
    operation,
    logger: _logger,
    context: 'BusinessesRepository',
  );
}
