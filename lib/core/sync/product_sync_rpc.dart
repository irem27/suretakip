import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';

/// Ürün senkronizasyon RPC sözleşmesi. Test için sahte (fake) uygulanabilir.
abstract interface class ProductSyncApi {
  Future<SyncPushResult> createProduct({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> product,
    required int payloadVersion,
  });

  Future<SyncPushResult> updateProduct({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> product,
    required int expectedVersion,
    required int payloadVersion,
  });

  Future<SyncPushResult> setProductActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String productId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  });
}

/// `create_product`/`update_product`/`set_product_active` Supabase RPC'lerini
/// çağırır ve dönen `result`/`error_code` sözleşmesini (Bölüm 7.3.3)
/// [SyncPushResult]'a çevirir. Transport hataları yukarı fırlatılır; iş
/// kuralı sonuçları burada ayrıştırılır.
class ProductSyncRpc implements ProductSyncApi {
  const ProductSyncRpc(this._client);

  final SupabaseClient _client;

  @override
  Future<SyncPushResult> createProduct({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> product,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'create_product',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_product': product,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }

  @override
  Future<SyncPushResult> updateProduct({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> product,
    required int expectedVersion,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'update_product',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_product': product,
        'p_expected_version': expectedVersion,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }

  @override
  Future<SyncPushResult> setProductActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String productId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async {
    final response = await _client.rpc<Object?>(
      'set_product_active',
      params: {
        'p_operation_id': operationId,
        'p_idempotency_key': idempotencyKey,
        'p_business_id': businessId,
        'p_product_id': productId,
        'p_is_active': isActive,
        'p_expected_version': expectedVersion,
        'p_payload_version': payloadVersion,
      },
    );
    return parseSyncResult(response);
  }
}
