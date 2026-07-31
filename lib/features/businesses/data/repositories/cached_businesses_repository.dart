import 'dart:async';

import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/features/businesses/data/local/businesses_local_data_source.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
import 'package:suretakip/features/businesses/domain/entities/onboarding_input.dart';
import 'package:suretakip/features/businesses/domain/repositories/businesses_repository.dart';

/// İşletme/üyelik okumalarını read-through önbellekle saran repository.
///
/// Okuma: yerel önbellek doluysa sonuç anında döner, sunucu yenilemesi arka
/// planda çalışır (stale-while-revalidate). Önbellek boşsa ilk veri için sunucu
/// beklenir. Böylece internet ekran açmanın ön koşulu olmaz.
///
/// Yazma (onboarding, işletme güncelleme, üyelik mutasyonları) internet ister;
/// olduğu gibi sunucuya iletilir, başarı sonrası önbellek en iyi çabayla
/// tazelenir.
class CachedBusinessesRepository implements BusinessesRepository {
  CachedBusinessesRepository({
    required BusinessesRepository remote,
    required BusinessesLocalDataSource local,
    AppLogger logger = const NoopAppLogger(),
  }) : _remote = remote,
       _local = local,
       _logger = logger;

  final BusinessesRepository _remote;
  final BusinessesLocalDataSource _local;
  final AppLogger _logger;

  @override
  Future<List<Business>> getBusinesses() async {
    final cached = await _local.getBusinesses();
    if (cached.isNotEmpty) {
      unawaited(_refreshBusinesses());
      return cached;
    }
    try {
      final businesses = await _remote.getBusinesses();
      await _cache(() => _local.replaceBusinesses(businesses));
      return businesses;
    } on NetworkException {
      // Önbellek boş + çevrimdışı: boş liste "işletme yok" gibi maskelenirse
      // router kullanıcıyı yanlışlıkla onboarding'e atar. Hatayı yükselt ki UI
      // çevrimdışı/yeniden-dene göstersin (getBusiness ile tutarlı).
      rethrow;
    }
  }

  @override
  Future<Business> getBusiness(String businessId) async {
    final cached = await _local.getBusiness(businessId);
    if (cached != null) {
      unawaited(_refreshBusiness(businessId));
      return cached;
    }
    try {
      final business = await _remote.getBusiness(businessId);
      await _cache(() => _local.upsertBusiness(business));
      return business;
    } on NetworkException {
      rethrow;
    }
  }

  @override
  Future<List<BusinessMember>> getMembers(String businessId) async {
    final cached = await _local.getMembers(businessId);
    if (cached.isNotEmpty) {
      unawaited(_refreshMembers(businessId));
      return cached;
    }
    try {
      final members = await _remote.getMembers(businessId);
      await _cache(() => _local.replaceMembers(businessId, members));
      return members;
    } on NetworkException {
      // Boş önbellek + çevrimdışı: boş üye listesi kullanıcının rolünü/yetkisini
      // yanlış hesaplatır. Hatayı yükselt (getBusiness ile tutarlı).
      rethrow;
    }
  }

  // --- Yazma işlemleri: internet gerektirir, sunucuya iletilir. ---

  @override
  Future<Business> updateBusiness(Business business) async {
    final updated = await _remote.updateBusiness(business);
    await _cache(() => _local.upsertBusiness(updated));
    return updated;
  }

  @override
  Future<String> completeOnboarding(OnboardingInput input) =>
      _remote.completeOnboarding(input);

  @override
  Future<BusinessMember> addMember({
    required String businessId,
    required String userId,
    MemberRole role = MemberRole.staff,
  }) => _remote.addMember(businessId: businessId, userId: userId, role: role);

  @override
  Future<BusinessMember> changeMemberRole({
    required String memberId,
    required MemberRole role,
  }) => _remote.changeMemberRole(memberId: memberId, role: role);

  @override
  Future<BusinessMember> setMemberActive({
    required String memberId,
    required bool isActive,
  }) => _remote.setMemberActive(memberId: memberId, isActive: isActive);

  @override
  Future<void> removeMember(String memberId) => _remote.removeMember(memberId);

  @override
  Future<void> transferOwnership({
    required String businessId,
    required String toMemberId,
  }) =>
      _remote.transferOwnership(businessId: businessId, toMemberId: toMemberId);

  Future<void> _refreshBusinesses() async {
    try {
      final businesses = await _remote.getBusinesses();
      await _cache(() => _local.replaceBusinesses(businesses));
    } catch (error, stack) {
      _logRefreshError(error, stack, 'businesses');
    }
  }

  Future<void> _refreshBusiness(String businessId) async {
    try {
      final business = await _remote.getBusiness(businessId);
      await _cache(() => _local.upsertBusiness(business));
    } catch (error, stack) {
      _logRefreshError(error, stack, 'business');
    }
  }

  Future<void> _refreshMembers(String businessId) async {
    try {
      final members = await _remote.getMembers(businessId);
      await _cache(() => _local.replaceMembers(businessId, members));
    } catch (error, stack) {
      _logRefreshError(error, stack, 'members');
    }
  }

  void _logRefreshError(Object error, StackTrace stack, String target) {
    _logger.warn(
      error,
      stackTrace: stack,
      context: 'CachedBusinessesRepository.refresh.$target',
    );
  }

  /// Önbellek yazımı asla çağıranı düşürmez; hata yalnızca loglanır.
  Future<void> _cache(Future<void> Function() write) async {
    try {
      await write();
    } catch (error, stack) {
      _logger.warn(
        error,
        stackTrace: stack,
        context: 'CachedBusinessesRepository.cache',
      );
    }
  }
}
