import 'package:suretakip/features/products/domain/entities/inventory_movement.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';

abstract interface class ProductsRepository {
  Future<List<Product>> getProducts({
    required String businessId,
    bool includeInactive = false,
  });

  Future<Product> getProduct(String productId);

  Future<Product> createProduct(Product product);

  Future<Product> updateProduct(Product product);

  Future<List<InventoryMovement>> getInventoryMovements({
    required String businessId,
    String? productId,
  });

  Future<InventoryMovement> createInventoryMovement(InventoryMovement movement);
}
