import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:suretakip/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/payment_input.dart';
import 'package:suretakip/features/payments/domain/entities/payment_mutation_result.dart';
import 'package:suretakip/features/payments/domain/entities/refund_input.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
import 'package:uuid/uuid.dart';

final paymentsRemoteDataSourceProvider = Provider<PaymentsRemoteDataSource>(
  (ref) => PaymentsRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepositoryImpl(
    ref.watch(paymentsRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final paymentIdempotencyKeyGeneratorProvider = Provider<String Function()>((
  ref,
) {
  const uuid = Uuid();
  return uuid.v4;
});

class SessionPaymentController
    extends AutoDisposeFamilyAsyncNotifier<SessionPaymentSummary, String> {
  PaymentInput? _paymentIntent;
  RefundInput? _refundIntent;
  SessionPaymentSummary? _lastSummary;

  SessionPaymentSummary? get currentSummary =>
      state.valueOrNull ?? _lastSummary;

  @override
  Future<SessionPaymentSummary> build(String sessionId) async {
    final summary = await ref
        .watch(paymentsRepositoryProvider)
        .getSessionPaymentSummary(sessionId);
    _lastSummary = summary;
    return summary;
  }

  Future<void> refresh() async {
    state = const AsyncLoading<SessionPaymentSummary>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final summary = await ref
          .read(paymentsRepositoryProvider)
          .getSessionPaymentSummary(arg);
      _lastSummary = summary;
      return summary;
    });
  }

  Future<PaymentMutationResult?> recordPayment({
    required PaymentMethod method,
    required Money amount,
    String? externalReference,
    String? note,
  }) {
    if (state.isLoading) return Future.value();
    final input = PaymentInput(
      sessionId: arg,
      method: method,
      amount: amount,
      idempotencyKey: ref.read(paymentIdempotencyKeyGeneratorProvider)(),
      externalReference: externalReference,
      note: note,
    );
    _paymentIntent = input;
    return _record(input);
  }

  Future<PaymentMutationResult?> retryPayment() {
    final input = _paymentIntent;
    return input == null ? Future.value() : _record(input);
  }

  Future<PaymentMutationResult?> voidPayment({
    required String paymentId,
    required String reason,
  }) => _run(
    () => ref
        .read(paymentsRepositoryProvider)
        .voidPayment(paymentId: paymentId, reason: reason),
  );

  Future<PaymentMutationResult?> refundPayment({
    required String paymentId,
    required Money amount,
    required String reason,
  }) {
    if (state.isLoading) return Future.value();
    final previous = _refundIntent;
    if (state.hasError &&
        previous != null &&
        previous.paymentId == paymentId &&
        previous.amount == amount &&
        previous.reason == reason) {
      return _refund(previous);
    }
    final input = RefundInput(
      paymentId: paymentId,
      amount: amount,
      idempotencyKey: ref.read(paymentIdempotencyKeyGeneratorProvider)(),
      reason: reason,
    );
    _refundIntent = input;
    return _refund(input);
  }

  Future<PaymentMutationResult?> retryRefund() {
    final input = _refundIntent;
    return input == null ? Future.value() : _refund(input);
  }

  Future<PaymentMutationResult?> _record(PaymentInput input) => _run(
    () => ref.read(paymentsRepositoryProvider).recordSessionPayment(input),
  );

  Future<PaymentMutationResult?> _refund(RefundInput input) =>
      _run(() => ref.read(paymentsRepositoryProvider).refundPayment(input));

  Future<PaymentMutationResult?> _run(
    Future<PaymentMutationResult> Function() operation,
  ) async {
    if (state.isLoading) return null;
    PaymentMutationResult? result;
    state = const AsyncLoading<SessionPaymentSummary>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      result = await operation();
      _lastSummary = result!.summary;
      return result!.summary;
    });
    return state.hasError ? null : result;
  }
}

final sessionPaymentControllerProvider = AsyncNotifierProvider.autoDispose
    .family<SessionPaymentController, SessionPaymentSummary, String>(
      SessionPaymentController.new,
    );
