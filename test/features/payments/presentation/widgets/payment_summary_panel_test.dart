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
import 'package:suretakip/features/payments/presentation/widgets/payment_summary_panel.dart';

void main() {
  testWidgets('yükleniyor durumunda ilerleme göstergesi görünür', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_summaryWithPayment)
      ..loadCompleter = Completer<SessionPaymentSummary>();
    await _pumpPanel(tester, repository, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.loadCompleter!.complete(_summaryWithPayment);
    await tester.pumpAndSettle();
  });

  testWidgets('yükleme başarısız olunca hata kartı ve tekrar dene görünür', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_summaryWithPayment)
      ..failLoad = true;
    await _pumpPanel(tester, repository, settle: false);
    await tester.pump();
    await tester.pump();

    expect(find.text('Ödeme bilgileri yüklenemedi.'), findsOneWidget);

    repository.failLoad = false;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();

    expect(find.text('Ödeme bilgileri yüklenemedi.'), findsNothing);
    expect(find.text('Ödeme geçmişi'), findsOneWidget);
  });

  testWidgets('ödeme yoksa boş liste kartı görünür ve Ödeme Al gizlenir', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_paidSummary);
    await _pumpPanel(tester, repository);

    expect(find.text('Henüz tahsilat veya iade kaydı yok.'), findsOneWidget);
    expect(find.text('Ödeme Al'), findsNothing);
  });

  testWidgets('kalan bakiye varsa Ödeme Al butonu tetiklenebilir', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_partialSummary);
    var collected = false;
    await _pumpPanel(tester, repository, onCollect: () => collected = true);

    await tester.tap(find.text('Ödeme Al'));
    await tester.pump();

    expect(collected, isTrue);
  });

  testWidgets('iptal edilen ödeme gerekçesi ile birlikte gösterilir', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_voidedSummary);
    await _pumpPanel(tester, repository, canManage: true);

    expect(find.textContaining('İptal edildi: müşteri talebi'), findsOneWidget);
    expect(find.text('İptal et'), findsNothing);
    expect(find.text('İade et'), findsNothing);
  });

  testWidgets('iade kaydı için iptal/iade aksiyonları gösterilmez', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_refundedSummary);
    await _pumpPanel(tester, repository, canManage: true);

    expect(find.textContaining('İade ·'), findsOneWidget);
    expect(find.byKey(const ValueKey('void-payment-payment-2')), findsNothing);
    expect(
      find.byKey(const ValueKey('refund-payment-payment-2')),
      findsNothing,
    );
  });

  testWidgets('gerekçe boş bırakılınca void diyaloğu doğrulama gösterir', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_summaryWithPayment);
    await _pumpPanel(tester, repository, canManage: true);

    await tester.tap(find.text('İptal et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İptal Et'));
    await tester.pump();

    expect(find.text('Gerekçe zorunlu.'), findsOneWidget);
    expect(repository.voidCalls, 0);
  });

  testWidgets('void diyaloğu vazgeç ile kapanır ve mutasyon yapılmaz', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_summaryWithPayment);
    await _pumpPanel(tester, repository, canManage: true);

    await tester.tap(find.text('İptal et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(repository.voidCalls, 0);
    expect(find.text('Tahsilatı iptal et'), findsNothing);
  });

  testWidgets('geçerli gerekçe ile ödeme iptal edilir ve mesaj gösterilir', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_summaryWithPayment);
    await _pumpPanel(tester, repository, canManage: true);

    await tester.tap(find.text('İptal et'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'müşteri talebi');
    await tester.tap(find.text('İptal Et'));
    await tester.pumpAndSettle();

    expect(repository.voidCalls, 1);
    expect(find.text('Tahsilat iptal edildi.'), findsOneWidget);
  });

  testWidgets('void mutasyonu hata dönerse DomainException mesajı gösterilir', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_summaryWithPayment)
      ..voidError = const ConflictException('Bu işlem zaten iptal edilmiş.');
    await _pumpPanel(tester, repository, canManage: true);

    await tester.tap(find.text('İptal et'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'müşteri talebi');
    await tester.tap(find.text('İptal Et'));
    await tester.pumpAndSettle();

    expect(find.text('Bu işlem zaten iptal edilmiş.'), findsOneWidget);
  });

  testWidgets('iade diyaloğu iade edilebilir bakiyeyi aşınca hata verir', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_summaryWithPayment);
    await _pumpPanel(tester, repository, canManage: true);

    await tester.tap(find.text('İade et'));
    await tester.pumpAndSettle();

    final amountField = find.byType(TextFormField).first;
    await tester.enterText(amountField, '999999,00');
    await tester.enterText(find.byType(TextFormField).last, 'ürün iadesi');
    await tester.tap(find.text('İade Et'));
    await tester.pump();

    expect(find.text('Tutar iade edilebilir bakiyeyi aşamaz.'), findsOneWidget);
    expect(repository.refundCalls, 0);
  });

  testWidgets('iade diyaloğu vazgeç ile kapanır', (tester) async {
    final repository = _FakePaymentsRepository(_summaryWithPayment);
    await _pumpPanel(tester, repository, canManage: true);

    await tester.tap(find.text('İade et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(repository.refundCalls, 0);
    expect(find.text('Tahsilatı iade et'), findsNothing);
  });

  testWidgets('geçerli iade isteği gönderilince başarı mesajı gösterilir', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_summaryWithPayment);
    await _pumpPanel(tester, repository, canManage: true);

    await tester.tap(find.text('İade et'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'ürün iadesi');
    await tester.tap(find.text('İade Et'));
    await tester.pumpAndSettle();

    expect(repository.refundCalls, 1);
    expect(find.text('İade kaydedildi.'), findsOneWidget);
  });

  testWidgets('replay edilen iade sonucu ayrı bir mesaj gösterir', (
    tester,
  ) async {
    final repository = _FakePaymentsRepository(_summaryWithPayment)
      ..replayedRefund = true;
    await _pumpPanel(tester, repository, canManage: true);

    await tester.tap(find.text('İade et'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'ürün iadesi');
    await tester.tap(find.text('İade Et'));
    await tester.pumpAndSettle();

    expect(find.text('Bu iade zaten kaydedilmişti.'), findsOneWidget);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester,
  _FakePaymentsRepository repository, {
  bool canManage = false,
  bool settle = true,
  VoidCallback? onCollect,
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
              onCollect: onCollect ?? _noop,
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void _noop() {}

class _FakePaymentsRepository implements PaymentsRepository {
  _FakePaymentsRepository(this.summary);

  final SessionPaymentSummary summary;
  Completer<SessionPaymentSummary>? loadCompleter;
  var failLoad = false;
  var voidCalls = 0;
  var refundCalls = 0;
  Object? voidError;
  var replayedRefund = false;

  PaymentMutationResult mutation({bool replayed = false}) =>
      PaymentMutationResult(
        summary: summary,
        paymentId: 'payment-1',
        replayed: replayed,
      );

  @override
  Future<SessionPaymentSummary> getSessionPaymentSummary(
    String sessionId,
  ) async {
    if (failLoad) throw const NetworkException('Ağ hatası');
    if (loadCompleter != null) return loadCompleter!.future;
    return summary;
  }

  @override
  Future<List<SessionPaymentStatusSummary>> getSessionsPaymentStatus(
    List<String> sessionIds,
  ) async => const [];

  @override
  Future<PaymentMutationResult> recordSessionPayment(
    PaymentInput input,
  ) async => mutation();

  @override
  Future<PaymentMutationResult> refundPayment(RefundInput input) async {
    refundCalls++;
    return mutation(replayed: replayedRefund);
  }

  @override
  Future<PaymentMutationResult> voidPayment({
    required String paymentId,
    required String reason,
  }) async {
    voidCalls++;
    if (voidError != null) {
      final error = voidError!;
      voidError = null;
      throw error;
    }
    return mutation();
  }
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

final _paidSummary = _partialSummary.copyWith(
  collected: Money(minorUnits: 10000, currencyCode: 'TRY'),
  netPaid: Money(minorUnits: 10000, currencyCode: 'TRY'),
  remaining: Money.zero('TRY'),
  paymentStatus: SessionPaymentStatus.paid,
);

Payment _collectedPayment({int amountMinor = 2000}) => Payment(
  id: 'payment-1',
  kind: PaymentKind.collection,
  method: PaymentMethod.cash,
  status: PaymentRecordStatus.completed,
  amountMinor: amountMinor,
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
);

final _summaryWithPayment = _partialSummary.copyWith(
  payments: [_collectedPayment()],
);

final _voidedSummary = _partialSummary.copyWith(
  payments: [
    Payment(
      id: 'payment-1',
      kind: PaymentKind.collection,
      method: PaymentMethod.cash,
      status: PaymentRecordStatus.voided,
      amountMinor: 2000,
      currencyCode: 'TRY',
      originalPaymentId: null,
      externalReference: null,
      note: null,
      receivedByMemberId: 'member-2',
      receivedByMe: false,
      receivedAt: DateTime.utc(2026, 7, 19, 10),
      voidedByMemberId: 'member-1',
      voidedAt: DateTime.utc(2026, 7, 20),
      voidReason: 'müşteri talebi',
    ),
  ],
);

final _refundedSummary = _partialSummary.copyWith(
  payments: [
    _collectedPayment(),
    Payment(
      id: 'payment-2',
      kind: PaymentKind.refund,
      method: PaymentMethod.cash,
      status: PaymentRecordStatus.completed,
      amountMinor: 500,
      currencyCode: 'TRY',
      originalPaymentId: 'payment-1',
      externalReference: null,
      note: null,
      receivedByMemberId: 'member-2',
      receivedByMe: false,
      receivedAt: DateTime.utc(2026, 7, 20, 10),
      voidedByMemberId: null,
      voidedAt: null,
      voidReason: null,
    ),
  ],
);
