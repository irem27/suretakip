import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/constants/app_constants.dart';

/// Raporlar SUNUCU TARAFINDA aggregate edilir (SECURITY DEFINER RPC'ler,
/// işletme saat dilimine göre dönemler, tüm tutarlar minor-unit). İstemci
/// yalnızca sonucu okur; ham seansları çekip client'ta toplamaz.
class ReportsRemoteDataSource {
  const ReportsRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> revenueSummary(String businessId) async {
    final result = await _client.rpc(
      AppConstants.reportRevenueSummaryRpc,
      params: {'p_business_id': businessId},
    );
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> topServices({
    required String businessId,
    required String period,
    required int limit,
  }) => _topQuery(AppConstants.reportTopServicesRpc, businessId, period, limit);

  Future<List<Map<String, dynamic>>> topProducts({
    required String businessId,
    required String period,
    required int limit,
  }) => _topQuery(AppConstants.reportTopProductsRpc, businessId, period, limit);

  Future<List<Map<String, dynamic>>> topCustomers({
    required String businessId,
    required String period,
    required int limit,
  }) =>
      _topQuery(AppConstants.reportTopCustomersRpc, businessId, period, limit);

  Future<List<Map<String, dynamic>>> _topQuery(
    String rpc,
    String businessId,
    String period,
    int limit,
  ) async {
    final result = await _client.rpc(
      rpc,
      params: {
        'p_business_id': businessId,
        'p_period': period,
        'p_limit': limit,
      },
    );
    return (result as List).cast<Map<String, dynamic>>();
  }
}
