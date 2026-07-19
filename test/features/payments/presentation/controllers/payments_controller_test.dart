import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/payment_input.dart';
import 'package:suretakip/features/payments/domain/entities/payment_mutation_result.dart';
import 'package:suretakip/features/payments/domain/entities/refund_input.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
import 'package:suretakip/features/payments/presentation/controllers/payments_controller.dart';

void main() {
  test('controller ilk yüklemede loading ardından success üretir', () async {
    final repository = _FakePaymentsRepository()..loadCompleter = Completer();
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      sessionPaymentControllerProvider('session-1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      container.read(sessionPaymentControllerProvider('session-1')).isLoading,
      isTrue,
    );

    repository.loadCompleter!.complete(_summary);
    await container.read(sessionPaymentControllerProvider('session-1').future);

    expect(
      container.read(sessionPaymentControllerProvider('session-1')).value,
      _summary,
    );
  });

  test('mutation hatasını AsyncError durumuna taşır', () async {
    final repository = _FakePaymentsRepository()
      ..recordError = const ConflictException('Kalan bakiye aşılıyor.');
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = _listen(container);
    addTearDown(subscription.close);
    await container.read(sessionPaymentControllerProvider('session-1').future);

    final success = await container
        .read(sessionPaymentControllerProvider('session-1').notifier)
        .recordPayment(
          method: PaymentMethod.cash,
          amount: Money(minorUnits: 1000, currencyCode: 'TRY'),
        );

    final state = container.read(sessionPaymentControllerProvider('session-1'));
    expect(success, isNull);
    expect(state.hasError, isTrue);
    expect(state.error, isA<ConflictException>());
  });

  test('mutation sırasında loading, tamamlanınca success üretir', () async {
    final repository = _FakePaymentsRepository()..recordCompleter = Completer();
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = _listen(container);
    addTearDown(subscription.close);
    await container.read(sessionPaymentControllerProvider('session-1').future);

    final operation = container
        .read(sessionPaymentControllerProvider('session-1').notifier)
        .recordPayment(
          method: PaymentMethod.card,
          amount: Money(minorUnits: 2000, currencyCode: 'TRY'),
        );
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(sessionPaymentControllerProvider('session-1')).isLoading,
      isTrue,
    );

    repository.recordCompleter!.complete(_mutation());
    expect(await operation, isNotNull);
    expect(
      container.read(sessionPaymentControllerProvider('session-1')).value,
      _updatedSummary,
    );
  });

  test(
    'aynı ödeme niyetinin retry anahtarı sabit, yeni niyetinki farklıdır',
    () async {
      final repository = _FakePaymentsRepository()
        ..recordError = const NetworkException('Ağ hatası');
      final keys = ['key-1', 'key-2'].iterator;
      final container = _container(
        repository,
        keyGenerator: () {
          keys.moveNext();
          return keys.current;
        },
      );
      addTearDown(container.dispose);
      final subscription = _listen(container);
      addTearDown(subscription.close);
      await container.read(
        sessionPaymentControllerProvider('session-1').future,
      );
      final controller = container.read(
        sessionPaymentControllerProvider('session-1').notifier,
      );

      await controller.recordPayment(
        method: PaymentMethod.cash,
        amount: Money(minorUnits: 1000, currencyCode: 'TRY'),
      );
      repository.recordError = null;
      await controller.retryPayment();
      await controller.recordPayment(
        method: PaymentMethod.card,
        amount: Money(minorUnits: 2000, currencyCode: 'TRY'),
      );

      expect(repository.paymentInputs.map((input) => input.idempotencyKey), [
        'key-1',
        'key-1',
        'key-2',
      ]);
    },
  );

  test(
    'aynı iade niyetinin retry anahtarı sabit, yeni niyetinki farklıdır',
    () async {
      final repository = _FakePaymentsRepository()
        ..refundError = const NetworkException('Ağ hatası');
      final keys = ['refund-key-1', 'refund-key-2'].iterator;
      final container = _container(
        repository,
        keyGenerator: () {
          keys.moveNext();
          return keys.current;
        },
      );
      addTearDown(container.dispose);
      final subscription = _listen(container);
      addTearDown(subscription.close);
      await container.read(
        sessionPaymentControllerProvider('session-1').future,
      );
      final controller = container.read(
        sessionPaymentControllerProvider('session-1').notifier,
      );

      await controller.refundPayment(
        paymentId: 'payment-1',
        amount: Money(minorUnits: 500, currencyCode: 'TRY'),
        reason: 'Kısmi iade',
      );
      repository.refundError = null;
      await controller.retryRefund();
      await controller.refundPayment(
        paymentId: 'payment-1',
        amount: Money(minorUnits: 250, currencyCode: 'TRY'),
        reason: 'Ek iade',
      );

      expect(repository.refundInputs.map((input) => input.idempotencyKey), [
        'refund-key-1',
        'refund-key-1',
        'refund-key-2',
      ]);
    },
  );

  test(
    'aynı başarısız iade formu yeniden gönderilince anahtar korunur',
    () async {
      final repository = _FakePaymentsRepository()
        ..refundError = const NetworkException('Ağ hatası');
      final keys = ['refund-key-1', 'refund-key-2'].iterator;
      final container = _container(
        repository,
        keyGenerator: () {
          keys.moveNext();
          return keys.current;
        },
      );
      addTearDown(container.dispose);
      final subscription = _listen(container);
      addTearDown(subscription.close);
      await container.read(
        sessionPaymentControllerProvider('session-1').future,
      );
      final controller = container.read(
        sessionPaymentControllerProvider('session-1').notifier,
      );
      final amount = Money(minorUnits: 500, currencyCode: 'TRY');

      await controller.refundPayment(
        paymentId: 'payment-1',
        amount: amount,
        reason: 'Kısmi iade',
      );
      repository.refundError = null;
      await controller.refundPayment(
        paymentId: 'payment-1',
        amount: amount,
        reason: 'Kısmi iade',
      );

      expect(repository.refundInputs.map((input) => input.idempotencyKey), [
        'refund-key-1',
        'refund-key-1',
      ]);
    },
  );
}

ProviderContainer _container(
  _FakePaymentsRepository repository, {
  String Function()? keyGenerator,
}) => ProviderContainer(
  overrides: [
    paymentsRepositoryProvider.overrideWithValue(repository),
    if (keyGenerator != null)
      paymentIdempotencyKeyGeneratorProvider.overrideWithValue(keyGenerator),
  ],
);

ProviderSubscription<AsyncValue<SessionPaymentSummary>> _listen(
  ProviderContainer container,
) => container.listen(
  sessionPaymentControllerProvider('session-1'),
  (_, _) {},
  fireImmediately: true,
);

class _FakePaymentsRepository implements PaymentsRepository {
  Completer<SessionPaymentSummary>? loadCompleter;
  Completer<PaymentMutationResult>? recordCompleter;
  Object? recordError;
  Object? refundError;
  final paymentInputs = <PaymentInput>[];
  final refundInputs = <RefundInput>[];

  @override
  Future<SessionPaymentSummary> getSessionPaymentSummary(String sessionId) =>
      loadCompleter?.future ?? Future.value(_summary);

  @override
  Future<List<SessionPaymentStatusSummary>> getSessionsPaymentStatus(
    List<String> sessionIds,
  ) async => const [];

  @override
  Future<PaymentMutationResult> recordSessionPayment(PaymentInput input) {
    paymentInputs.add(input);
    final error = recordError;
    if (error != null) return Future.error(error);
    return recordCompleter?.future ?? Future.value(_mutation());
  }

  @override
  Future<PaymentMutationResult> refundPayment(RefundInput input) {
    refundInputs.add(input);
    final error = refundError;
    return error == null ? Future.value(_mutation()) : Future.error(error);
  }

  @override
  Future<PaymentMutationResult> voidPayment({
    required String paymentId,
    required String reason,
  }) async => _mutation();
}

PaymentMutationResult _mutation({bool replayed = false}) =>
    PaymentMutationResult(
      summary: _updatedSummary,
      paymentId: 'payment-1',
      replayed: replayed,
    );

final _summary = SessionPaymentSummary(
  sessionId: 'session-1',
  sessionTotal: Money(minorUnits: 10000, currencyCode: 'TRY'),
  collected: Money.zero('TRY'),
  refunded: Money.zero('TRY'),
  netPaid: Money.zero('TRY'),
  remaining: Money(minorUnits: 10000, currencyCode: 'TRY'),
  paymentStatus: SessionPaymentStatus.unpaid,
  currencyCode: 'TRY',
  payments: const [],
);

final _updatedSummary = _summary.copyWith(
  collected: Money(minorUnits: 2000, currencyCode: 'TRY'),
  netPaid: Money(minorUnits: 2000, currencyCode: 'TRY'),
  remaining: Money(minorUnits: 8000, currencyCode: 'TRY'),
  paymentStatus: SessionPaymentStatus.partiallyPaid,
);
