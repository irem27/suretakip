import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';

/// Offline seans senkronizasyon RPC sözleşmesi (Faz C). Test için fake edilebilir.
abstract interface class SessionSyncApi {
  Future<SyncPushResult> startSession({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> session,
    required int payloadVersion,
  });

  Future<SyncPushResult> sessionEvent({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> event,
    required int payloadVersion,
  });
}

/// `sync_start_session` ve `sync_session_event` RPC'lerini çağırır ve dönen
/// `result`/`error_code` sözleşmesini [SyncPushResult]'a çevirir.
class SessionSyncRpc implements SessionSyncApi {
  const SessionSyncRpc(this._client);

  final SupabaseClient _client;

  @override
  Future<SyncPushResult> startSession({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> session,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'sync_start_session',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_session': session,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }

  @override
  Future<SyncPushResult> sessionEvent({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> event,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'sync_session_event',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_event': event,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }
}
