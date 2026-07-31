import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/constants/app_constants.dart';

class ServicesRemoteDataSource {
  const ServicesRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> getServices({
    required String businessId,
    required bool includeInactive,
  }) async {
    var query = _client
        .from(AppConstants.servicesTable)
        .select()
        .eq('business_id', businessId);
    if (!includeInactive) query = query.eq('is_active', true);
    return query.order('name');
  }

  Future<Map<String, dynamic>> getService(String id) =>
      _client.from(AppConstants.servicesTable).select().eq('id', id).single();

  Future<Map<String, dynamic>> createService(Map<String, Object?> values) =>
      _client.from(AppConstants.servicesTable).insert(values).select().single();

  Future<Map<String, dynamic>> updateService(Map<String, Object?> values) =>
      _client
          .from(AppConstants.servicesTable)
          .update(values)
          .eq('id', values['id']! as String)
          .select()
          .single();
}
