import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/constants/app_constants.dart';

class CustomersRemoteDataSource {
  const CustomersRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> getCustomers({
    required String businessId,
    required bool includeInactive,
  }) async {
    var query = _client
        .from(AppConstants.customersTable)
        .select()
        .eq('business_id', businessId);
    if (!includeInactive) query = query.eq('is_active', true);
    return query.order('name');
  }

  Future<Map<String, dynamic>> getCustomer(String id) =>
      _client.from(AppConstants.customersTable).select().eq('id', id).single();

  Future<Map<String, dynamic>> createCustomer(Map<String, Object?> values) =>
      _client
          .from(AppConstants.customersTable)
          .insert(values)
          .select()
          .single();

  Future<Map<String, dynamic>> updateCustomer(Map<String, Object?> values) =>
      _client
          .from(AppConstants.customersTable)
          .update(values)
          .eq('id', values['id']! as String)
          .select()
          .single();
}
