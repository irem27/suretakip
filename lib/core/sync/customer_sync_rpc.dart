import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';

/// Müşteri senkronizasyon RPC sözleşmesi. Test için sahte (fake) uygulanabilir.
abstract interface class CustomerSyncApi {
  Future<SyncPushResult> createCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int payloadVersion,
  });

  Future<SyncPushResult> updateCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int expectedVersion,
    required int payloadVersion,
  });

  Future<SyncPushResult> setCustomerActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String customerId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  });
}

/// `create_customer` Supabase RPC'sini çağırır ve dönen `result`/`error_code`
/// sözleşmesini (Bölüm 7.3.3) [SyncPushResult]'a çevirir. Transport hataları
/// yukarı fırlatılır; iş kuralı sonuçları burada ayrıştırılır.
class CustomerSyncRpc implements CustomerSyncApi {
  const CustomerSyncRpc(this._client);

  final SupabaseClient _client;

  @override
  Future<SyncPushResult> createCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'create_customer',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_customer': customer,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }

  @override
  Future<SyncPushResult> updateCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int expectedVersion,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'update_customer',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_customer': customer,
        'p_expected_version': expectedVersion,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }

  @override
  Future<SyncPushResult> setCustomerActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String customerId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'set_customer_active',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_customer_id': customerId,
        'p_is_active': isActive,
        'p_expected_version': expectedVersion,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }
}
