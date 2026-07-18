import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
import 'package:suretakip/features/businesses/domain/entities/onboarding_input.dart';

abstract interface class BusinessesRepository {
  Future<List<Business>> getBusinesses();

  Future<Business> getBusiness(String businessId);

  Future<Business> updateBusiness(Business business);

  /// İşletme + owner üyeliği + zorunlu ilk hizmet + opsiyonel ilk ürünü
  /// tek atomik RPC'de oluşturur. Yeni işletmenin id'sini döndürür.
  Future<String> completeOnboarding(OnboardingInput input);

  Future<List<BusinessMember>> getMembers(String businessId);

  Future<BusinessMember> addMember({
    required String businessId,
    required String userId,
    MemberRole role = MemberRole.staff,
  });

  Future<BusinessMember> updateMember(BusinessMember member);

  /// Üyeyi pasifleştirir (is_active=false). Kalıcı silme bilinçli olarak
  /// desteklenmez: business_members, sessions ve inventory_movements
  /// tarafından `on delete restrict` ile referanslanır; geçmişi olan bir
  /// üye silinemez ve tüm proje soft-delete yaklaşımını benimser.
  Future<BusinessMember> deactivateMember(String memberId);
}
