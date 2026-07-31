import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:suretakip/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/domain/entities/payment_input.dart';
import 'package:suretakip/features/payments/domain/entities/refund_input.dart';

void main() {
  group('zarf eşleme', () {
    test('toplu ödeme durumlarını geçmiş olmadan eksiksiz eşler', () async {
      final repository = PaymentsRepositoryImpl(
        _FakePaymentsDataSource(
          response: _fullEnvelope,
          batchResponse: [_batchRow],
        ),
      );

      final summaries = await repository.getSessionsPaymentStatus([
        'session-1',
      ]);

      expect(summaries, hasLength(1));
      final summary = summaries.single;
      expect(summary.sessionId, 'session-1');
      expect(
        summary.sessionTotal,
        Money(minorUnits: 45000, currencyCode: 'TRY'),
      );
      expect(summary.collected, Money(minorUnits: 30000, currencyCode: 'TRY'));
      expect(summary.refunded, Money(minorUnits: 10000, currencyCode: 'TRY'));
      expect(summary.netPaid, Money(minorUnits: 20000, currencyCode: 'TRY'));
      expect(summary.remaining, Money(minorUnits: 25000, currencyCode: 'TRY'));
      expect(summary.paymentStatus, SessionPaymentStatus.partiallyPaid);
      expect(summary.currencyCode, 'TRY');
    });

    test(
      'mutasyon özetle birlikte payment_id ve replayed bilgisini döner',
      () async {
        final replayEnvelope = Map<String, dynamic>.from(_fullEnvelope)
          ..['replayed'] = true;
        final repository = PaymentsRepositoryImpl(
          _FakePaymentsDataSource(response: replayEnvelope),
        );

        final result = await repository.recordSessionPayment(
          PaymentInput(
            sessionId: 'session-1',
            method: PaymentMethod.cash,
            amount: Money(minorUnits: 1000, currencyCode: 'TRY'),
            idempotencyKey: 'intent-1',
          ),
        );

        expect(result.paymentId, 'payment-refund');
        expect(result.replayed, isTrue);
        expect(result.summary.sessionId, 'session-1');
      },
    );

    test('void mutasyonu replayed alanı yoksa false döner', () async {
      final voidEnvelope = Map<String, dynamic>.from(_fullEnvelope)
        ..remove('replayed');
      final repository = PaymentsRepositoryImpl(
        _FakePaymentsDataSource(response: voidEnvelope),
      );

      final result = await repository.voidPayment(
        paymentId: 'payment-collection',
        reason: 'Yanlış kayıt',
      );

      expect(result.replayed, isFalse);
    });

    test('void edilmiş tahsilat ve iadeyi eksiksiz eşler', () async {
      final repository = PaymentsRepositoryImpl(
        _FakePaymentsDataSource(response: _fullEnvelope),
      );

      final summary = await repository.getSessionPaymentSummary('session-1');

      expect(summary.sessionId, 'session-1');
      expect(summary.currencyCode, 'TRY');
      expect(
        summary.sessionTotal,
        Money(minorUnits: 45000, currencyCode: 'TRY'),
      );
      expect(summary.collected, Money(minorUnits: 30000, currencyCode: 'TRY'));
      expect(summary.refunded, Money(minorUnits: 10000, currencyCode: 'TRY'));
      expect(summary.netPaid, Money(minorUnits: 20000, currencyCode: 'TRY'));
      expect(summary.remaining, Money(minorUnits: 25000, currencyCode: 'TRY'));
      expect(summary.paymentStatus, SessionPaymentStatus.partiallyPaid);

      final voided = summary.payments[1];
      expect(voided.id, 'payment-voided');
      expect(voided.kind, PaymentKind.collection);
      expect(voided.method, PaymentMethod.card);
      expect(voided.status, PaymentRecordStatus.voided);
      expect(voided.amountMinor, 5000);
      expect(voided.amount, Money(minorUnits: 5000, currencyCode: 'TRY'));
      expect(voided.originalPaymentId, isNull);
      expect(voided.externalReference, 'POS-42');
      expect(voided.note, 'Yanlış kart');
      expect(voided.receivedByMemberId, 'member-2');
      expect(voided.receivedByMe, isFalse);
      expect(voided.receivedAt, DateTime.utc(2026, 7, 19, 9, 15));
      expect(voided.voidedByMemberId, 'member-owner');
      expect(voided.voidedAt, DateTime.utc(2026, 7, 19, 9, 20));
      expect(voided.voidReason, 'Yanlış yöntem');

      final refund = summary.payments[2];
      expect(refund.kind, PaymentKind.refund);
      expect(refund.method, PaymentMethod.cash);
      expect(refund.status, PaymentRecordStatus.completed);
      expect(refund.originalPaymentId, 'payment-collection');
      expect(refund.amountMinor, 10000);
      expect(refund.receivedByMe, isTrue);
      expect(refund.voidedAt, isNull);
    });

    test('sunucunun payments sırasını değiştirmeden korur', () async {
      final repository = PaymentsRepositoryImpl(
        _FakePaymentsDataSource(response: _fullEnvelope),
      );

      final summary = await repository.getSessionPaymentSummary('session-1');

      expect(summary.payments.map((payment) => payment.id), [
        'payment-collection',
        'payment-voided',
        'payment-refund',
      ]);
    });
  });

  group('RPC parametreleri', () {
    late _FakePaymentsDataSource dataSource;
    late PaymentsRepositoryImpl repository;

    setUp(() {
      dataSource = _FakePaymentsDataSource(response: _fullEnvelope);
      repository = PaymentsRepositoryImpl(dataSource);
    });

    test('özet parametresini birebir iletir', () async {
      await repository.getSessionPaymentSummary('session-1');

      expect(dataSource.summaryParams, {'p_session_id': 'session-1'});
    });

    test(
      'toplu durum parametresini tek RPC çağrısında birebir iletir',
      () async {
        dataSource.batchResponse = [_batchRow];

        await repository.getSessionsPaymentStatus(['session-1', 'session-2']);

        expect(dataSource.batchCallCount, 1);
        expect(dataSource.batchParams, {
          'p_session_ids': ['session-1', 'session-2'],
        });
      },
    );

    test(
      'tahsilat parametrelerini snake_case ve tam içerikle iletir',
      () async {
        await repository.recordSessionPayment(
          PaymentInput(
            sessionId: 'session-1',
            method: PaymentMethod.bankTransfer,
            amount: Money(minorUnits: 12500, currencyCode: 'TRY'),
            idempotencyKey: 'intent-1',
            externalReference: 'EFT-7',
            note: 'İlk taksit',
          ),
        );

        expect(dataSource.recordParams, {
          'p_session_id': 'session-1',
          'p_payment_method': 'bank_transfer',
          'p_amount_minor': 12500,
          'p_idempotency_key': 'intent-1',
          'p_external_reference': 'EFT-7',
          'p_note': 'İlk taksit',
        });
      },
    );

    test('iptal parametrelerini birebir iletir', () async {
      await repository.voidPayment(
        paymentId: 'payment-1',
        reason: 'Mükerrer kayıt',
      );

      expect(dataSource.voidParams, {
        'p_payment_id': 'payment-1',
        'p_reason': 'Mükerrer kayıt',
      });
    });

    test('iade parametrelerini birebir iletir', () async {
      await repository.refundPayment(
        RefundInput(
          paymentId: 'payment-1',
          amount: Money(minorUnits: 4000, currencyCode: 'TRY'),
          idempotencyKey: 'refund-intent-1',
          reason: 'Kısmi iade',
        ),
      );

      expect(dataSource.refundParams, {
        'p_payment_id': 'payment-1',
        'p_amount_minor': 4000,
        'p_idempotency_key': 'refund-intent-1',
        'p_reason': 'Kısmi iade',
      });
    });
  });
}

class _FakePaymentsDataSource implements PaymentsRemoteDataSource {
  _FakePaymentsDataSource({required this.response, this.batchResponse});

  final Map<String, dynamic> response;
  List<Map<String, dynamic>>? batchResponse;
  Map<String, Object?>? summaryParams;
  Map<String, Object?>? batchParams;
  Map<String, Object?>? recordParams;
  Map<String, Object?>? voidParams;
  Map<String, Object?>? refundParams;
  int batchCallCount = 0;

  @override
  Future<dynamic> getSessionPaymentSummary(Map<String, Object?> params) async {
    summaryParams = params;
    return response;
  }

  @override
  Future<dynamic> getSessionsPaymentStatus(Map<String, Object?> params) async {
    batchCallCount += 1;
    batchParams = params;
    return batchResponse ?? const <Map<String, dynamic>>[];
  }

  @override
  Future<dynamic> recordSessionPayment(Map<String, Object?> params) async {
    recordParams = params;
    return response;
  }

  @override
  Future<dynamic> voidPayment(Map<String, Object?> params) async {
    voidParams = params;
    return response;
  }

  @override
  Future<dynamic> refundPayment(Map<String, Object?> params) async {
    refundParams = params;
    return response;
  }
}

final _batchRow = <String, dynamic>{
  'session_id': 'session-1',
  'currency_code': 'TRY',
  'session_total_minor': 45000,
  'collected_minor': 30000,
  'refunded_minor': 10000,
  'net_paid_minor': 20000,
  'remaining_minor': 25000,
  'payment_status': 'partially_paid',
};

final _fullEnvelope = <String, dynamic>{
  'session_id': 'session-1',
  'currency_code': 'TRY',
  'session_total_minor': 45000,
  'collected_minor': 30000,
  'refunded_minor': 10000,
  'net_paid_minor': 20000,
  'remaining_minor': 25000,
  'payment_status': 'partially_paid',
  'payment_id': 'payment-refund',
  'replayed': false,
  'payments': [
    {
      'id': 'payment-collection',
      'payment_kind': 'collection',
      'payment_method': 'cash',
      'status': 'completed',
      'amount_minor': 30000,
      'currency_code': 'TRY',
      'original_payment_id': null,
      'external_reference': null,
      'note': null,
      'received_by_member_id': 'member-1',
      'received_by_me': true,
      'received_at': '2026-07-19T09:12:44.000Z',
      'voided_by_member_id': null,
      'voided_at': null,
      'void_reason': null,
    },
    {
      'id': 'payment-voided',
      'payment_kind': 'collection',
      'payment_method': 'card',
      'status': 'voided',
      'amount_minor': 5000,
      'currency_code': 'TRY',
      'original_payment_id': null,
      'external_reference': 'POS-42',
      'note': 'Yanlış kart',
      'received_by_member_id': 'member-2',
      'received_by_me': false,
      'received_at': '2026-07-19T09:15:00.000Z',
      'voided_by_member_id': 'member-owner',
      'voided_at': '2026-07-19T09:20:00.000Z',
      'void_reason': 'Yanlış yöntem',
    },
    {
      'id': 'payment-refund',
      'payment_kind': 'refund',
      'payment_method': 'cash',
      'status': 'completed',
      'amount_minor': 10000,
      'currency_code': 'TRY',
      'original_payment_id': 'payment-collection',
      'external_reference': null,
      'note': 'Müşteri iadesi',
      'received_by_member_id': 'member-owner',
      'received_by_me': true,
      'received_at': '2026-07-19T09:25:00.000Z',
      'voided_by_member_id': null,
      'voided_at': null,
      'void_reason': null,
    },
  ],
};
