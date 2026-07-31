import 'package:intl/intl.dart';
import 'package:suretakip/core/errors/domain_exception.dart';

String serviceErrorMessage(Object? error, String fallback) =>
    error is DomainException ? error.message : fallback;

String formatMoneyPerMinute(int minorUnits, String currencyCode) {
  final formatter = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: _currencySymbol(currencyCode),
    decimalDigits: 2,
  );
  return '${formatter.format(minorUnits / 100)} / dakika';
}

String minorUnitsToInput(int minorUnits) {
  final whole = minorUnits ~/ 100;
  final fraction = (minorUnits % 100).abs().toString().padLeft(2, '0');
  return '$whole,$fraction';
}

String _currencySymbol(String currencyCode) => switch (currencyCode) {
  'TRY' => '₺',
  'USD' => r'$',
  'EUR' => '€',
  'GBP' => '£',
  _ => '$currencyCode ',
};
