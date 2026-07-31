import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';

final class SessionPaymentStatusSummary {
  const SessionPaymentStatusSummary({
    required this.sessionId,
    required this.sessionTotal,
    required this.collected,
    required this.refunded,
    required this.netPaid,
    required this.remaining,
    required this.paymentStatus,
    required this.currencyCode,
  });

  final String sessionId;
  final Money sessionTotal;
  final Money collected;
  final Money refunded;
  final Money netPaid;
  final Money remaining;
  final SessionPaymentStatus paymentStatus;
  final String currencyCode;
}
