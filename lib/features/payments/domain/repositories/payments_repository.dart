import 'package:suretakip/features/payments/domain/entities/payment_input.dart';
import 'package:suretakip/features/payments/domain/entities/payment_mutation_result.dart';
import 'package:suretakip/features/payments/domain/entities/refund_input.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';

abstract interface class PaymentsRepository {
  Future<SessionPaymentSummary> getSessionPaymentSummary(String sessionId);

  Future<List<SessionPaymentStatusSummary>> getSessionsPaymentStatus(
    List<String> sessionIds,
  );

  Future<PaymentMutationResult> recordSessionPayment(PaymentInput input);

  Future<PaymentMutationResult> voidPayment({
    required String paymentId,
    required String reason,
  });

  Future<PaymentMutationResult> refundPayment(RefundInput input);
}
