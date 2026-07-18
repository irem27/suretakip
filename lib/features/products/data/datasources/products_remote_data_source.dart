import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/constants/app_constants.dart';

class ProductsRemoteDataSource {
  const ProductsRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> getProducts({
    required String businessId,
    required bool includeInactive,
  }) async {
    var query = _client
        .from(AppConstants.productsTable)
        .select()
        .eq('business_id', businessId);
    if (!includeInactive) query = query.eq('is_active', true);
    return query.order('name');
  }

  Future<Map<String, dynamic>> getProduct(String id) =>
      _client.from(AppConstants.productsTable).select().eq('id', id).single();

  Future<String> createProductWithStock(Map<String, Object?> params) async {
    final result = await _client.rpc(
      AppConstants.createProductWithStockRpc,
      params: params,
    );
    return result as String;
  }

  Future<Map<String, dynamic>> updateProduct(Map<String, Object?> values) =>
      _client
          .from(AppConstants.productsTable)
          .update(values)
          .eq('id', values['id']! as String)
          .select()
          .single();

  Future<List<Map<String, dynamic>>> getInventoryMovements({
    required String businessId,
    String? productId,
  }) async {
    var query = _client
        .from(AppConstants.inventoryMovementsTable)
        .select()
        .eq('business_id', businessId);
    if (productId != null) query = query.eq('product_id', productId);
    return query.order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> createInventoryMovement(
    Map<String, Object?> values,
  ) => _client
      .from(AppConstants.inventoryMovementsTable)
      .insert(values)
      .select()
      .single();
}
