import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';

Payment _payment({int amountMinor = 1500, String currency = 'TRY'}) => Payment(
  id: 'p1',
  kind: PaymentKind.collection,
  method: PaymentMethod.cash,
  status: PaymentRecordStatus.completed,
  amountMinor: amountMinor,
  currencyCode: currency,
  originalPaymentId: null,
  externalReference: null,
  note: null,
  receivedByMemberId: 'm1',
  receivedByMe: true,
  receivedAt: DateTime.utc(2026, 1, 1),
  voidedByMemberId: null,
  voidedAt: null,
  voidReason: null,
);

void main() {
  group('Payment.amount', () {
    test('amountMinor ve currencyCode ile Money üretir', () {
      final money = _payment(amountMinor: 2500, currency: 'USD').amount;

      expect(money.minorUnits, 2500);
      expect(money.currencyCode, 'USD');
    });
  });

  group('paymentMethodDatabaseValue', () {
    test('her yöntem doğru db değeri', () {
      expect(paymentMethodDatabaseValue(PaymentMethod.cash), 'cash');
      expect(paymentMethodDatabaseValue(PaymentMethod.card), 'card');
      expect(
        paymentMethodDatabaseValue(PaymentMethod.bankTransfer),
        'bank_transfer',
      );
      expect(paymentMethodDatabaseValue(PaymentMethod.other), 'other');
    });
  });

  group('paymentMethodFromDatabase', () {
    test('bilinen değerler doğru enum', () {
      expect(paymentMethodFromDatabase('cash'), PaymentMethod.cash);
      expect(paymentMethodFromDatabase('card'), PaymentMethod.card);
      expect(
        paymentMethodFromDatabase('bank_transfer'),
        PaymentMethod.bankTransfer,
      );
      expect(paymentMethodFromDatabase('other'), PaymentMethod.other);
    });

    test('bilinmeyen değer FormatException', () {
      expect(
        () => paymentMethodFromDatabase('bitcoin'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('paymentKindFromDatabase', () {
    test('bilinen değerler doğru enum', () {
      expect(paymentKindFromDatabase('collection'), PaymentKind.collection);
      expect(paymentKindFromDatabase('refund'), PaymentKind.refund);
    });

    test('bilinmeyen değer FormatException', () {
      expect(
        () => paymentKindFromDatabase('tip'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
