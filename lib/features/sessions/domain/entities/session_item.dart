import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_item.freezed.dart';

@freezed
class SessionItem with _$SessionItem {
  const factory SessionItem({
    required String id,
    required String businessId,
    required String sessionId,
    required String? productId,
    required String productNameSnapshot,
    required String? skuSnapshot,
    required int unitPriceMinorSnapshot,
    required String currencyCodeSnapshot,
    required int quantity,
    required int discountMinor,
    required int taxMinor,
    required int lineTotalMinor,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _SessionItem;
}
