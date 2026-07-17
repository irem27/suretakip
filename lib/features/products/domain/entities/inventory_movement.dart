import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:suretakip/core/domain/domain_enums.dart';

part 'inventory_movement.freezed.dart';

@freezed
class InventoryMovement with _$InventoryMovement {
  const factory InventoryMovement({
    required String id,
    required String businessId,
    required String productId,
    required String? sessionItemId,
    required InventoryMovementType movementType,
    required int quantityDelta,
    required String? note,
    required String? createdByMemberId,
    required DateTime createdAt,
  }) = _InventoryMovement;
}
