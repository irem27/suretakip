import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/payment_input.dart';
import 'package:suretakip/features/payments/domain/entities/payment_mutation_result.dart';
import 'package:suretakip/features/payments/domain/entities/refund_input.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
import 'package:suretakip/features/payments/presentation/controllers/payments_controller.dart';
import 'package:suretakip/features/payments/presentation/widgets/session_payment_sheet.dart';

void main() {
  group('SessionPaymentSheet', () {
    testWidgets('yüklenirken ilerleme göstergesi gösterir', (tester) async {
      final repository = _FakePaymentsRepository()..loadCompleter = Completer();
      await _pump(tester, repository);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('yükleme hatasında tekrar dene gösterir ve yeniden dener', (
      tester,
    ) async {
      final repository = _FakePaymentsRepository()..loadCompleter = Completer();
      await _pump(tester, repository);
      repository.loadCompleter!.completeError(
        const NetworkException('ağ hatası'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ödeme bilgileri yüklenemedi.'), findsOneWidget);
      repository.loadCompleter = null;
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pumpAndSettle();

      expect(find.text('Bu işlemin bakiyesi ödendi.'), findsNothing);
      expect(find.byType(SessionPaymentSheet), findsOneWidget);
    });

    testWidgets('bakiye sıfırsa ödendi mesajı gösterir', (tester) async {
      final repository = _FakePaymentsRepository(summary: _paidSummary);
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('Bu işlemin bakiyesi ödendi.'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<PaymentMethod>), findsNothing);
    });

    testWidgets('tutar kalan bakiyeyi aşarsa doğrulama hatası gösterir', (
      tester,
    ) async {
      final repository = _FakePaymentsRepository();
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '999999');
      await tester.ensureVisible(
        find.byKey(const Key('payment-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('payment-submit-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Tutar kalan bakiyeyi aşamaz.'), findsOneWidget);
      expect(repository.paymentInputs, isEmpty);
    });

    testWidgets('geçerli tutar ile başarılı ödeme snackbar gösterir', (
      tester,
    ) async {
      final repository = _FakePaymentsRepository();
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('payment-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('payment-submit-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Tahsilat kaydedildi.'), findsOneWidget);
      expect(repository.paymentInputs, hasLength(1));
    });

    testWidgets('tekrarlanan (replay) ödeme farklı bir mesaj gösterir', (
      tester,
    ) async {
      final repository = _FakePaymentsRepository()..replayResult = true;
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('payment-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('payment-submit-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Bu tahsilat zaten kaydedilmişti.'), findsOneWidget);
    });

    testWidgets('mutasyon hatasında satır içi hata gösterir', (tester) async {
      final repository = _FakePaymentsRepository()
        ..recordError = const ConflictException('Kalan bakiye aşılıyor.');
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('payment-submit-button')),
      );
      await tester.tap(
        find.byKey(const Key('payment-submit-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Kalan bakiye aşılıyor.'), findsOneWidget);
    });

    testWidgets('kapat butonu ekranı kapatır', (tester) async {
      final repository = _FakePaymentsRepository();
      await _pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SessionPaymentSheet), findsNothing);
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakePaymentsRepository repository,
) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [paymentsRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        home: Scaffold(body: SessionPaymentSheet(sessionId: 'session-1')),
      ),
    ),
  );
}

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

final _paidSummary = _summary.copyWith(
  collected: Money(minorUnits: 10000, currencyCode: 'TRY'),
  netPaid: Money(minorUnits: 10000, currencyCode: 'TRY'),
  remaining: Money.zero('TRY'),
  paymentStatus: SessionPaymentStatus.paid,
);

class _FakePaymentsRepository implements PaymentsRepository {
  _FakePaymentsRepository({SessionPaymentSummary? summary})
    : summary = summary ?? _summary;

  final SessionPaymentSummary summary;
  Completer<SessionPaymentSummary>? loadCompleter;
  Object? recordError;
  bool replayResult = false;
  final paymentInputs = <PaymentInput>[];

  @override
  Future<SessionPaymentSummary> getSessionPaymentSummary(String sessionId) =>
      loadCompleter?.future ?? Future.value(summary);

  @override
  Future<List<SessionPaymentStatusSummary>> getSessionsPaymentStatus(
    List<String> sessionIds,
  ) async => const [];

  @override
  Future<PaymentMutationResult> recordSessionPayment(PaymentInput input) {
    paymentInputs.add(input);
    final error = recordError;
    if (error != null) return Future.error(error);
    return Future.value(
      PaymentMutationResult(
        summary: _paidSummary,
        paymentId: 'payment-1',
        replayed: replayResult,
      ),
    );
  }

  @override
  Future<PaymentMutationResult> refundPayment(RefundInput input) async =>
      PaymentMutationResult(
        summary: _paidSummary,
        paymentId: 'payment-1',
        replayed: false,
      );

  @override
  Future<PaymentMutationResult> voidPayment({
    required String paymentId,
    required String reason,
  }) async => PaymentMutationResult(
    summary: _paidSummary,
    paymentId: paymentId,
    replayed: false,
  );
}
