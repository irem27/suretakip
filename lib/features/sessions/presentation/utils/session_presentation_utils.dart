import 'package:intl/intl.dart';
import 'package:suretakip/core/domain/domain_enums.dart';

String formatSessionMoney(int minorUnits, String currencyCode) {
  final symbol = switch (currencyCode) {
    'TRY' => '₺',
    'USD' => r'$',
    'EUR' => '€',
    'GBP' => '£',
    _ => '$currencyCode ',
  };
  return NumberFormat.currency(
    locale: 'tr_TR',
    symbol: symbol,
    decimalDigits: 2,
  ).format(minorUnits / 100);
}

String formatSessionDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String sessionStatusLabel(SessionStatus status) => switch (status) {
  SessionStatus.draft => 'Taslak',
  SessionStatus.active => 'Aktif',
  SessionStatus.paused => 'Duraklatıldı',
  SessionStatus.completed => 'Tamamlandı',
  SessionStatus.cancelled => 'İptal edildi',
};
