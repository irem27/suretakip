import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/utils/duration_calculator.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';

final class SessionPriceQuote {
  const SessionPriceQuote({
    required this.activeDuration,
    required this.billableDuration,
    required this.chargedMinutes,
    required this.serviceTotal,
    required this.productsTotal,
    required this.discount,
    required this.tax,
    required this.grandTotal,
  });

  final Duration activeDuration;
  final Duration billableDuration;
  final int chargedMinutes;
  final Money serviceTotal;
  final Money productsTotal;
  final Money discount;
  final Money tax;
  final Money grandTotal;
}

final class SessionPriceCalculator {
  const SessionPriceCalculator();

  SessionPriceQuote calculate({
    required Duration activeDuration,
    required Money pricePerMinute,
    required int roundingIntervalMinutes,
    required int minimumChargeMinutes,
    required Iterable<SessionItem> items,
    Money? discount,
    Money? tax,
  }) {
    final currency = pricePerMinute.currencyCode;
    final resolvedDiscount = discount ?? Money.zero(currency);
    final resolvedTax = tax ?? Money.zero(currency);
    if (resolvedDiscount.minorUnits < 0 || resolvedTax.minorUnits < 0) {
      throw ArgumentError('İndirim ve vergi negatif olamaz.');
    }
    final chargedMinutes = calculateChargedMinutes(
      activeDuration: activeDuration,
      roundingIntervalMinutes: roundingIntervalMinutes,
      minimumChargeMinutes: minimumChargeMinutes,
    );
    final serviceTotal = pricePerMinute * chargedMinutes;
    var productsTotal = Money.zero(currency);
    for (final item in items) {
      productsTotal += Money(
        minorUnits: item.lineTotalMinor,
        currencyCode: item.currencyCodeSnapshot,
      );
    }
    final grandTotal =
        serviceTotal + productsTotal - resolvedDiscount + resolvedTax;
    if (grandTotal.minorUnits < 0) {
      throw ArgumentError.value(
        resolvedDiscount,
        'discount',
        'İndirim toplam tutardan büyük olamaz.',
      );
    }

    return SessionPriceQuote(
      activeDuration: activeDuration,
      billableDuration: Duration(minutes: chargedMinutes),
      chargedMinutes: chargedMinutes,
      serviceTotal: serviceTotal,
      productsTotal: productsTotal,
      discount: resolvedDiscount,
      tax: resolvedTax,
      grandTotal: grandTotal,
    );
  }
}

Duration calculateSessionActiveDuration({
  required Iterable<SessionTimeEntry> entries,
  required DateTime serverNow,
}) {
  final durations = entries
      .where((entry) => entry.entryType == TimeEntryType.active)
      .map((entry) {
        final end = entry.endedAt ?? serverNow;
        if (end.isBefore(entry.startedAt)) return Duration.zero;
        return end.difference(entry.startedAt);
      });
  return sumDurations(durations);
}
