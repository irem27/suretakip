import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';

@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String businessId,
    required String name,
    required String? sku,
    required int unitPriceMinor,
    required String currencyCode,
    required bool trackStock,
    required int stockQuantity,
    required bool isActive,
    required DateTime? archivedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Product;
}
