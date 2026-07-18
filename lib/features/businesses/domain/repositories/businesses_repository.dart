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

  /// Tüm üyelik mutasyonları `security definer` RPC'ler üzerinden yürür.
  /// business_members tablosuna doğrudan yazma yetkisi yoktur
  /// (migration 20260718090200). Sunucu her çağrıda şunları uygular:
  ///   * çağıranın rolünü doğrular (staff hiçbir üyeliği yönetemez),
  ///   * admin'in owner satırına dokunmasını ve kimseyi owner yapmasını
  ///     engeller (yetki yükseltme koruması),
  ///   * "her işletmede en az bir aktif owner" invariantını korur.
  /// İstemciden gelen rol/işletme bilgisine güvenilmez.

  /// `add_business_member`. Aynı kullanıcı zaten üyeyse
  /// `member_already_exists` döner (pasif üye yeniden aktifleştirilmelidir).
  Future<BusinessMember> addMember({
    required String businessId,
    required String userId,
    MemberRole role = MemberRole.staff,
  });

  /// `update_business_member_role`. Son aktif owner'ın rolü düşürülemez.
  Future<BusinessMember> changeMemberRole({
    required String memberId,
    required MemberRole role,
  });

  /// `set_business_member_active`. Son aktif owner pasifleştirilemez.
  Future<BusinessMember> setMemberActive({
    required String memberId,
    required bool isActive,
  });

  /// `remove_business_member` — kalıcı silme. Yalnızca hiç işlem geçmişi
  /// olmayan (yanlışlıkla eklenmiş) üyeler için geçerlidir; geçmişi olan üye
  /// `on delete restrict` nedeniyle `member_has_history` ile reddedilir ve
  /// doğru operasyon [setMemberActive] ile pasifleştirmedir.
  Future<void> removeMember(String memberId);

  /// `transfer_business_ownership` — hedef üye owner olur, çağıran admin'e
  /// düşer; tek transaction. Tek owner'ın işletmeden ayrılabilmesinin tek
  /// meşru yoludur (arada hiçbir an sıfır owner oluşmaz).
  Future<void> transferOwnership({
    required String businessId,
    required String toMemberId,
  });
}
