import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/constants/app_constants.dart';

class PaymentsRemoteDataSource {
  const PaymentsRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<dynamic> getSessionPaymentSummary(Map<String, Object?> params) =>
      _client.rpc(AppConstants.getSessionPaymentSummaryRpc, params: params);

  Future<dynamic> getSessionsPaymentStatus(Map<String, Object?> params) =>
      _client.rpc(AppConstants.getSessionsPaymentStatusRpc, params: params);

  Future<dynamic> recordSessionPayment(Map<String, Object?> params) =>
      _client.rpc(AppConstants.recordSessionPaymentRpc, params: params);

  Future<dynamic> voidPayment(Map<String, Object?> params) =>
      _client.rpc(AppConstants.voidPaymentRpc, params: params);

  Future<dynamic> refundPayment(Map<String, Object?> params) =>
      _client.rpc(AppConstants.refundPaymentRpc, params: params);
}
