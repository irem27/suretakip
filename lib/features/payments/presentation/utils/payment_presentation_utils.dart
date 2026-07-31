import 'package:suretakip/features/payments/domain/entities/payment.dart';

String paymentMethodLabel(PaymentMethod method) => switch (method) {
  PaymentMethod.cash => 'Nakit',
  PaymentMethod.card => 'Kart',
  PaymentMethod.bankTransfer => 'Havale',
  PaymentMethod.other => 'Diğer',
};

String minorUnitsToPaymentInput(int minorUnits) {
  final whole = minorUnits ~/ 100;
  final fraction = (minorUnits % 100).abs().toString().padLeft(2, '0');
  return '$whole,$fraction';
}
