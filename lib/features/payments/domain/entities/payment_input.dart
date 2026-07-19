import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';

part 'payment_input.freezed.dart';

@freezed
class PaymentInput with _$PaymentInput {
  const factory PaymentInput({
    required String sessionId,
    required PaymentMethod method,
    required Money amount,
    required String idempotencyKey,
    String? externalReference,
    String? note,
  }) = _PaymentInput;
}
