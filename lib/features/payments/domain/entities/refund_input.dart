import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:suretakip/core/value_objects/money.dart';

part 'refund_input.freezed.dart';

@freezed
class RefundInput with _$RefundInput {
  const factory RefundInput({
    required String paymentId,
    required Money amount,
    required String idempotencyKey,
    required String reason,
  }) = _RefundInput;
}
