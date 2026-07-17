import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';

abstract interface class BusinessesRepository {
  Future<List<Business>> getBusinesses();

  Future<Business> getBusiness(String businessId);

  Future<Business> updateBusiness(Business business);

  Future<String> createBusinessWithOwner({
    required String name,
    String currencyCode = 'TRY',
    String timezone = 'Europe/Istanbul',
  });

  Future<List<BusinessMember>> getMembers(String businessId);

  Future<BusinessMember> addMember({
    required String businessId,
    required String userId,
    MemberRole role = MemberRole.staff,
  });

  Future<BusinessMember> updateMember(BusinessMember member);

  Future<void> removeMember(String memberId);
}
