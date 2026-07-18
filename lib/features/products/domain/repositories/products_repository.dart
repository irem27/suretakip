import 'package:suretakip/features/products/domain/entities/inventory_movement.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';

abstract interface class ProductsRepository {
  Future<List<Product>> getProducts({
    required String businessId,
    bool includeInactive = false,
  });

  Future<Product> getProduct(String productId);

  Future<Product> createProduct(ProductInput input);

  Future<Product> updateProduct(Product product);

  Future<Product> setProductActive(String productId, {required bool isActive});

  Future<List<InventoryMovement>> getInventoryMovements({
    required String businessId,
    String? productId,
  });

  Future<InventoryMovement> createInventoryMovement(InventoryMovement movement);
}
