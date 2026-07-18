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

  Future<Map<String, dynamic>> addMember(Map<String, Object?> values) => _client
      .from(AppConstants.businessMembersTable)
      .insert(values)
      .select()
      .single();

  Future<Map<String, dynamic>> updateMember(Map<String, Object?> values) =>
      _client
          .from(AppConstants.businessMembersTable)
          .update(values)
          .eq('id', values['id']! as String)
          .select()
          .single();
}
