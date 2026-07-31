import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:suretakip/core/value_objects/money.dart';

part 'payment.freezed.dart';

enum PaymentMethod { cash, card, bankTransfer, other }

enum PaymentKind { collection, refund }

enum PaymentRecordStatus { completed, voided }

enum SessionPaymentStatus { unpaid, partiallyPaid, paid }

@freezed
abstract class Payment with _$Payment {
  const Payment._();

  const factory Payment({
    required String id,
    required PaymentKind kind,
    required PaymentMethod method,
    required PaymentRecordStatus status,
    required int amountMinor,
    required String currencyCode,
    required String? originalPaymentId,
    required String? externalReference,
    required String? note,
    required String receivedByMemberId,
    required bool receivedByMe,
    required DateTime receivedAt,
    required String? voidedByMemberId,
    required DateTime? voidedAt,
    required String? voidReason,
  }) = _Payment;

  Money get amount =>
      Money(minorUnits: amountMinor, currencyCode: currencyCode);
}

String paymentMethodDatabaseValue(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'cash',
  PaymentMethod.card => 'card',
  PaymentMethod.bankTransfer => 'bank_transfer',
  PaymentMethod.other => 'other',
};

PaymentMethod paymentMethodFromDatabase(String value) => switch (value) {
  'cash' => PaymentMethod.cash,
  'card' => PaymentMethod.card,
  'bank_transfer' => PaymentMethod.bankTransfer,
  'other' => PaymentMethod.other,
  _ => throw FormatException('Bilinmeyen ödeme yöntemi: $value'),
};

PaymentKind paymentKindFromDatabase(String value) => switch (value) {
  'collection' => PaymentKind.collection,
  'refund' => PaymentKind.refund,
  _ => throw FormatException('Bilinmeyen ödeme türü: $value'),
};

PaymentRecordStatus paymentRecordStatusFromDatabase(String value) =>
    switch (value) {
      'completed' => PaymentRecordStatus.completed,
      'voided' => PaymentRecordStatus.voided,
      _ => throw FormatException('Bilinmeyen ödeme kayıt durumu: $value'),
    };

SessionPaymentStatus sessionPaymentStatusFromDatabase(String value) =>
    switch (value) {
      'unpaid' => SessionPaymentStatus.unpaid,
      'partially_paid' => SessionPaymentStatus.partiallyPaid,
      'paid' => SessionPaymentStatus.paid,
      _ => throw FormatException('Bilinmeyen işlem ödeme durumu: $value'),
    };
