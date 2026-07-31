import 'package:suretakip/core/value_objects/money.dart';

/// Yeni ürün oluşturma girdisi. id, timestamp ve is_active DB tarafından
/// üretilir. Fiyat [Money] olarak alınır — ISO 4217 doğrulaması zorlanır.
final class ProductInput {
  const ProductInput({
    required this.businessId,
    required this.name,
    required this.sku,
    required this.unitPrice,
    required this.trackStock,
    required this.stockQuantity,
  });

  final String businessId;
  final String name;
  final String? sku;
  final Money unitPrice;
  final bool trackStock;
  final int stockQuantity;
}
