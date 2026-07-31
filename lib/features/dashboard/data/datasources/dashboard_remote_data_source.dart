import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/constants/app_constants.dart';

class DashboardRemoteDataSource {
  const DashboardRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> getMetrics(String businessId) async {
    final result = await _client.rpc(
      AppConstants.dashboardMetricsRpc,
      params: {'p_business_id': businessId},
    );
    return (result as List).cast<Map<String, dynamic>>();
  }
}
