import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';

class SessionsRemoteDataSource {
  const SessionsRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> getSessions({
    required String businessId,
    String? customerId,
  }) async {
    var query = _client
        .from(AppConstants.sessionsTable)
        .select()
        .eq('business_id', businessId);
    if (customerId != null) query = query.eq('customer_id', customerId);
    return query.order('started_at', ascending: false);
  }

  Future<Map<String, dynamic>> getSession(String sessionId) => _client
      .from(AppConstants.sessionsTable)
      .select()
      .eq('id', sessionId)
      .single();

  Future<List<Map<String, dynamic>>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) async {
    var query = _client
        .from(AppConstants.sessionsTable)
        .select()
        .eq('business_id', businessId)
        .inFilter(
          'status',
          filter.statuses.map(sessionStatusDatabaseValue).toList(),
        );
    final start = filter.endedAtOrAfter;
    final end = filter.endedBefore;
    if (start != null) {
      query = query.gte('ended_at', start.toUtc().toIso8601String());
    }
    if (end != null) {
      query = query.lt('ended_at', end.toUtc().toIso8601String());
    }
    if (filter.customerId case final customerId?) {
      query = query.eq('customer_id', customerId);
    }
    if (filter.serviceId case final serviceId?) {
      query = query.eq('service_id', serviceId);
    }
    return query.order('ended_at', ascending: false).limit(filter.limit);
  }

  Future<List<Map<String, dynamic>>> getSessionItems(String sessionId) =>
      _client
          .from(AppConstants.sessionItemsTable)
          .select()
          .eq('session_id', sessionId)
          .order('created_at');

  Future<List<Map<String, dynamic>>> getSessionTimeEntries(String sessionId) =>
      _client
          .from(AppConstants.sessionTimeEntriesTable)
          .select()
          .eq('session_id', sessionId)
          .order('started_at');

  Future<dynamic> startSession({
    required String businessId,
    required String serviceId,
    String? customerId,
    String? notes,
  }) => _client.rpc(
    AppConstants.startSessionRpc,
    params: {
      'p_business_id': businessId,
      'p_service_id': serviceId,
      'p_customer_id': customerId,
      'p_notes': notes,
    },
  );

  Future<dynamic> pauseSession(String sessionId) => _client.rpc(
    AppConstants.pauseSessionRpc,
    params: {'p_session_id': sessionId},
  );

  Future<dynamic> resumeSession(String sessionId) => _client.rpc(
    AppConstants.resumeSessionRpc,
    params: {'p_session_id': sessionId},
  );

  Future<dynamic> addProductToSession({
    required String sessionId,
    required String productId,
    required int quantity,
    required int discountMinor,
    required int taxMinor,
  }) => _client.rpc(
    AppConstants.addProductToSessionRpc,
    params: {
      'p_session_id': sessionId,
      'p_product_id': productId,
      'p_quantity': quantity,
      'p_discount_minor': discountMinor,
      'p_tax_minor': taxMinor,
    },
  );

  Future<dynamic> completeSession({
    required String sessionId,
    required int discountMinor,
    required int taxMinor,
  }) => _client.rpc(
    AppConstants.completeSessionRpc,
    params: {
      'p_session_id': sessionId,
      'p_discount_minor': discountMinor,
      'p_tax_minor': taxMinor,
    },
  );

  Future<dynamic> cancelSession(String sessionId) => _client.rpc(
    AppConstants.cancelSessionRpc,
    params: {'p_session_id': sessionId},
  );

  Future<dynamic> serverNow() => _client.rpc(AppConstants.serverNowRpc);
}
