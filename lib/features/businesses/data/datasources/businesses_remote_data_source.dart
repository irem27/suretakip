import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/constants/app_constants.dart';

class BusinessesRemoteDataSource {
  const BusinessesRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> getBusinesses() async {
    final rows = await _client
        .from(AppConstants.businessesTable)
        .select()
        .eq('is_active', true)
        .order('created_at');
    return rows;
  }

  Future<Map<String, dynamic>> getBusiness(String businessId) => _client
      .from(AppConstants.businessesTable)
      .select()
      .eq('id', businessId)
      .single();

  Future<Map<String, dynamic>> updateBusiness(Map<String, Object?> values) =>
      _client
          .from(AppConstants.businessesTable)
          .update(values)
          .eq('id', values['id']! as String)
          .select()
          .single();

  Future<String> completeOnboarding(Map<String, Object?> params) async {
    final result = await _client.rpc(
      AppConstants.completeOnboardingRpc,
      params: params,
    );
    return result as String;
  }

  Future<List<Map<String, dynamic>>> getMembers(String businessId) async {
    final rows = await _client
        .from(AppConstants.businessMembersTable)
        .select()
        .eq('business_id', businessId)
        .order('created_at');
    return rows;
  }

  Future<Map<String, dynamic>> getMember(String memberId) => _client
      .from(AppConstants.businessMembersTable)
      .select()
      .eq('id', memberId)
      .single();

  // ---------------------------------------------------------------
  // Üyelik mutasyonları
  //
  // business_members tablosuna doğrudan insert/update/delete yetkisi
  // 20260718090200 ile kaldırıldı. Sebep: owner kendi satırını silerek /
  // pasifleştirerek / rolünü düşürerek işletmeyi SIFIR aktif owner ile
  // bırakabiliyordu (kalıcı kilitlenme). Yetki kontrolü ve son owner
  // invariantı artık sunucuda, kilit altında uygulanır.
  //
  // RPC'ler void/uuid döndürdüğü için mutasyon sonrası güncel satır
  // getMember ile okunur; istemci hiçbir alanı kendi tahmin etmez.
  // ---------------------------------------------------------------

  Future<String> addMember(Map<String, Object?> params) async {
    final result = await _client.rpc(
      AppConstants.addBusinessMemberRpc,
      params: params,
    );
    return result as String;
  }

  Future<void> updateMemberRole(Map<String, Object?> params) =>
      _client.rpc(AppConstants.updateBusinessMemberRoleRpc, params: params);

  Future<void> setMemberActive(Map<String, Object?> params) =>
      _client.rpc(AppConstants.setBusinessMemberActiveRpc, params: params);

  Future<void> removeMember(Map<String, Object?> params) =>
      _client.rpc(AppConstants.removeBusinessMemberRpc, params: params);

  Future<void> transferOwnership(Map<String, Object?> params) =>
      _client.rpc(AppConstants.transferBusinessOwnershipRpc, params: params);
}
