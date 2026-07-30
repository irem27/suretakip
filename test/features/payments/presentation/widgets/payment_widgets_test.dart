import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/payment_input.dart';
import 'package:suretakip/features/payments/domain/entities/payment_mutation_result.dart';
import 'package:suretakip/features/payments/domain/entities/refund_input.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_summary.dart';
import 'package:suretakip/features/payments/domain/entities/session_payment_status_summary.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
import 'package:suretakip/features/payments/presentation/controllers/payments_controller.dart';
import 'package:suretakip/features/payments/presentation/widgets/payment_status_badge.dart';
import 'package:suretakip/features/payments/presentation/widgets/payment_summary_panel.dart';
import 'package:suretakip/features/payments/presentation/widgets/session_payment_sheet.dart';

void main() {
  testWidgets('üç ödeme durumu doğru Türkçe rozetlerle gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PaymentStatusBadge(status: SessionPaymentStatus.unpaid),
              PaymentStatusBadge(status: SessionPaymentStatus.partiallyPaid),
              PaymentStatusBadge(status: SessionPaymentStatus.paid),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Ödenmedi'), findsOneWidget);
    expect(find.text('Kısmi ödendi'), findsOneWidget);
    expect(find.text('Ödendi'), findsOneWidget);
  });

  testWidgets('kısmi ödeme tutarları, durum ve kalan ön-dolgusu görünür', (
    tester,
  ) async {
    await _pumpSheet(tester, _FakePaymentsRepository(_partialSummary));

    expect(find.text('Kısmi ödendi'), findsOneWidget);
    expect(find.textContaining('100,00'), findsOneWidget);
    expect(find.textContaining('20,00'), findsOneWidget);
    expect(find.textContaining('80,00'), findsWidgets);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      '80,00',
    );
  });

  testWidgets('kalan bakiyeyi aşan tutar UI tarafından engellenir', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_partialSummary);
    await _pumpSheet(tester, repository);

    await tester.enterText(find.byType(TextFormField), '80,01');
    await tester.tap(find.byKey(const Key('payment-submit-button')));
    await tester.pump();

    expect(find.text('Tutar kalan bakiyeyi aşamaz.'), findsOneWidget);
    expect(repository.recordCalls, 0);
  });

  testWidgets('ödeme sürerken ikinci submit yeni RPC çağrısı oluşturmaz', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_partialSummary)
      ..recordCompleter = Completer<PaymentMutationResult>();
    await _pumpSheet(tester, repository);

    final submit = find.byKey(const Key('payment-submit-button'));
    await tester.tap(submit);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();

    expect(repository.recordCalls, 1);
    expect(find.text('Kaydediliyor…'), findsOneWidget);

    repository.recordCompleter!.complete(repository.mutation());
    await tester.pumpAndSettle();
  });

  testWidgets('replay sonucu ikinci başarı yerine zaten kaydedildi der', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_partialSummary)
      ..replayed = true;
    await _pumpSheet(tester, repository);

    await tester.tap(find.byKey(const Key('payment-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Bu tahsilat zaten kaydedilmişti.'), findsOneWidget);
    expect(find.text('Tahsilat kaydedildi.'), findsNothing);
  });

  testWidgets(
    'başarısız gönderim sonrası aynı tutar yeniden yazılınca retry key korunur',
    (tester) async {
      final repository = _FakePaymentsRepository(_partialSummary)
        ..failNextRecord = true;
      await _pumpSheet(tester, repository);

      final submit = find.byKey(const Key('payment-submit-button'));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(repository.recordCalls, 1);

      // Kullanıcı alana dokunur ama tutar GERÇEKTE değişmez (aynı değer).
      await tester.enterText(find.byType(TextFormField), '80,00');
      await tester.pump();

      await tester.tap(submit);
      await tester.pumpAndSettle();

      // İkinci deneme retryPayment üzerinden gitmeli: AYNI idempotency key
      // yeniden kullanılmalı, yoksa sunucu ilk isteği zaten işlemiş olsa bile
      // yeni bir key ile çift tahsilat oluşur.
      expect(repository.recordCalls, 2);
      expect(repository.idempotencyKeysUsed, hasLength(2));
      expect(
        repository.idempotencyKeysUsed[1],
        repository.idempotencyKeysUsed[0],
      );
      expect(find.text('Tahsilat kaydedildi.'), findsOneWidget);
    },
  );

  testWidgets('staff iptal/iade görmez, owner/admin paneli görür', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_summaryWithPayment);

    await _pumpPanel(tester, repository, canManage: false);
    expect(find.textContaining('Ekip üyesi'), findsOneWidget);
    expect(find.text('İptal et'), findsNothing);
    expect(find.text('İade et'), findsNothing);

    await _pumpPanel(tester, repository, canManage: true);
    expect(find.text('İptal et'), findsOneWidget);
    expect(find.text('İade et'), findsOneWidget);
  });

  testWidgets('ödeme sheet kapanınca İşlemler bağlamı yerinde kalır', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_partialSummary);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentsRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  const Text('İşlemler bağlamı'),
                  FilledButton(
                    onPressed: () => showSessionPaymentSheet(
                      context,
                      sessionId: 'session-1',
                    ),
                    child: const Text('Ödeme aç'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ödeme aç'));
    await tester.pumpAndSettle();
    expect(find.text('Tahsilat'), findsOneWidget);

    await tester.tap(find.byTooltip('Ödeme yapmadan kapat'));
    await tester.pumpAndSettle();
    expect(find.text('İşlemler bağlamı'), findsOneWidget);
    expect(find.text('Tahsilat'), findsNothing);
  });
}

Future<void> _pumpSheet(
  WidgetTester tester,
  _FakePaymentsRepository repository,
) async {
  tester.view.physicalSize = const Size(800, 1400);
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
  await tester.pumpAndSettle();
}

Future<void> _pumpPanel(
  WidgetTester tester,
  _FakePaymentsRepository repository, {
  required bool canManage,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [paymentsRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PaymentSummaryPanel(
              sessionId: 'session-1',
              canManage: canManage,
              onCollect: _noop,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _noop() {}

class _FakePaymentsRepository implements PaymentsRepository {
  _FakePaymentsRepository(this.summary);

  final SessionPaymentSummary summary;
  var recordCalls = 0;
  var replayed = false;
  var failNextRecord = false;
  Completer<PaymentMutationResult>? recordCompleter;
  final idempotencyKeysUsed = <String>[];

  PaymentMutationResult mutation() => PaymentMutationResult(
    summary: summary,
    paymentId: 'payment-1',
    replayed: replayed,
  );

  @override
  Future<SessionPaymentSummary> getSessionPaymentSummary(
    String sessionId,
  ) async => summary;

  @override
  Future<List<SessionPaymentStatusSummary>> getSessionsPaymentStatus(
    List<String> sessionIds,
  ) async => const [];

  @override
  Future<PaymentMutationResult> recordSessionPayment(PaymentInput input) {
    recordCalls++;
    idempotencyKeysUsed.add(input.idempotencyKey);
    if (failNextRecord) {
      failNextRecord = false;
      return Future.error(StateError('ağ hatası'));
    }
    return recordCompleter?.future ?? Future.value(mutation());
  }

  @override
  Future<PaymentMutationResult> refundPayment(RefundInput input) async =>
      mutation();

  @override
  Future<PaymentMutationResult> voidPayment({
    required String paymentId,
    required String reason,
  }) async => mutation();
}

final _partialSummary = SessionPaymentSummary(
  sessionId: 'session-1',
  sessionTotal: Money(minorUnits: 10000, currencyCode: 'TRY'),
  collected: Money(minorUnits: 2000, currencyCode: 'TRY'),
  refunded: Money.zero('TRY'),
  netPaid: Money(minorUnits: 2000, currencyCode: 'TRY'),
  remaining: Money(minorUnits: 8000, currencyCode: 'TRY'),
  paymentStatus: SessionPaymentStatus.partiallyPaid,
  currencyCode: 'TRY',
  payments: const [],
);

final _summaryWithPayment = _partialSummary.copyWith(
  payments: [
    Payment(
      id: 'payment-1',
      kind: PaymentKind.collection,
      method: PaymentMethod.cash,
      status: PaymentRecordStatus.completed,
      amountMinor: 2000,
      currencyCode: 'TRY',
      originalPaymentId: null,
      externalReference: null,
      note: null,
      receivedByMemberId: 'member-2',
      receivedByMe: false,
      receivedAt: DateTime.utc(2026, 7, 19, 10),
      voidedByMemberId: null,
      voidedAt: null,
      voidReason: null,
    ),
  ],
);
