import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';

/// Hizmet senkronizasyon RPC sözleşmesi. Test için sahte (fake) uygulanabilir.
abstract interface class ServiceSyncApi {
  Future<SyncPushResult> createService({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> service,
    required int payloadVersion,
  });

  Future<SyncPushResult> updateService({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> service,
    required int expectedVersion,
    required int payloadVersion,
  });

  Future<SyncPushResult> setServiceActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String serviceId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  });
}

/// `create_service`/`update_service`/`set_service_active` Supabase RPC'lerini
/// çağırır ve dönen `result`/`error_code` sözleşmesini (Bölüm 7.3.3)
/// [SyncPushResult]'a çevirir. Transport hataları yukarı fırlatılır; iş
/// kuralı sonuçları burada ayrıştırılır.
class ServiceSyncRpc implements ServiceSyncApi {
  const ServiceSyncRpc(this._client);

  final SupabaseClient _client;

  @override
  Future<SyncPushResult> createService({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> service,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'create_service',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_service': service,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }

  @override
  Future<SyncPushResult> updateService({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> service,
    required int expectedVersion,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'update_service',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_service': service,
        'p_expected_version': expectedVersion,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }

  @override
  Future<SyncPushResult> setServiceActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String serviceId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'set_service_active',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_service_id': serviceId,
        'p_is_active': isActive,
        'p_expected_version': expectedVersion,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }
}
