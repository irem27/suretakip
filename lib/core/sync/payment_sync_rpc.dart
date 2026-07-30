import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';

/// Offline seans ödemesi senkronizasyon RPC sözleşmesi. Test için sahte
/// (fake) uygulanabilir.
abstract interface class PaymentSyncApi {
  Future<SyncPushResult> recordSessionPayment({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> payment,
    required int payloadVersion,
  });
}

/// `sync_record_session_payment` Supabase RPC'sini çağırır ve dönen
/// `result`/`error_code` sözleşmesini (Bölüm 7.3.3) [SyncPushResult]'a
/// çevirir. `sync_session_event` ile aynı kitap (sync_processed_operations)
/// desenini paylaşır; ayrıca `payments` tablosundaki
/// `(business_id, idempotency_key)` UNIQUE kısıtı ikinci bir çift-tahsilat
/// koruması sağlar (bkz. migration'daki açıklama).
class PaymentSyncRpc implements PaymentSyncApi {
  const PaymentSyncRpc(this._client);

  final SupabaseClient _client;

  @override
  Future<SyncPushResult> recordSessionPayment({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> payment,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'sync_record_session_payment',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_payment': payment,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }
}
