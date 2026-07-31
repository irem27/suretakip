import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';

final class PaymentMutationResult {
  const PaymentMutationResult({
    required this.summary,
    required this.paymentId,
    required this.replayed,
  });

  final SessionPaymentSummary summary;
  final String paymentId;
  final bool replayed;
}
