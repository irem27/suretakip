import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';

part 'session_payment_summary.freezed.dart';

@freezed
class SessionPaymentSummary with _$SessionPaymentSummary {
  const factory SessionPaymentSummary({
    required String sessionId,
    required Money sessionTotal,
    required Money collected,
    required Money refunded,
    required Money netPaid,
    required Money remaining,
    required SessionPaymentStatus paymentStatus,
    required String currencyCode,
    required List<Payment> payments,
  }) = _SessionPaymentSummary;
}
