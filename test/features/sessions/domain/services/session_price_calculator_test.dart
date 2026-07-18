import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/domain/services/session_price_calculator.dart';

void main() {
  group('SessionPriceCalculator', () {
    const calculator = SessionPriceCalculator();

    test('aktif saniyeyi yukarı yuvarlar, sonra minimum süreyi uygular', () {
      final quote = calculator.calculate(
        activeDuration: const Duration(minutes: 6, seconds: 1),
        pricePerMinute: Money(minorUnits: 300, currencyCode: 'TRY'),
        roundingIntervalMinutes: 5,
        minimumChargeMinutes: 15,
        items: const [],
      );

      expect(quote.activeDuration, const Duration(minutes: 6, seconds: 1));
      expect(quote.billableDuration, const Duration(minutes: 15));
      expect(quote.chargedMinutes, 15);
      expect(quote.serviceTotal, Money(minorUnits: 4500, currencyCode: 'TRY'));
      expect(quote.productsTotal, Money.zero('TRY'));
      expect(quote.grandTotal, Money(minorUnits: 4500, currencyCode: 'TRY'));
    });

    test('tam aralıkta ek dakika eklemez ve ürün satırlarını toplar', () {
      final quote = calculator.calculate(
        activeDuration: const Duration(minutes: 10),
        pricePerMinute: Money(minorUnits: 125, currencyCode: 'TRY'),
        roundingIntervalMinutes: 5,
        minimumChargeMinutes: 0,
        items: [_item(lineTotalMinor: 750), _item(lineTotalMinor: 250)],
      );

      expect(quote.chargedMinutes, 10);
      expect(quote.serviceTotal.minorUnits, 1250);
      expect(quote.productsTotal.minorUnits, 1000);
      expect(quote.grandTotal.minorUnits, 2250);
    });

    test('indirim ve vergiyi RPC sırasıyla genel toplama uygular', () {
      final quote = calculator.calculate(
        activeDuration: const Duration(minutes: 2),
        pricePerMinute: Money(minorUnits: 500, currencyCode: 'TRY'),
        roundingIntervalMinutes: 1,
        minimumChargeMinutes: 0,
        items: [_item(lineTotalMinor: 600)],
        discount: Money(minorUnits: 200, currencyCode: 'TRY'),
        tax: Money(minorUnits: 100, currencyCode: 'TRY'),
      );

      expect(quote.grandTotal.minorUnits, 1500);
    });

    test('genel toplamı negatif yapan indirimi reddeder', () {
      expect(
        () => calculator.calculate(
          activeDuration: Duration.zero,
          pricePerMinute: Money(minorUnits: 100, currencyCode: 'TRY'),
          roundingIntervalMinutes: 1,
          minimumChargeMinutes: 0,
          items: const [],
          discount: Money(minorUnits: 1, currencyCode: 'TRY'),
        ),
        throwsArgumentError,
      );
    });

    test('negatif indirim veya vergiyi RPC gibi reddeder', () {
      expect(
        () => calculator.calculate(
          activeDuration: Duration.zero,
          pricePerMinute: Money(minorUnits: 100, currencyCode: 'TRY'),
          roundingIntervalMinutes: 1,
          minimumChargeMinutes: 0,
          items: const [],
          tax: Money(minorUnits: -1, currencyCode: 'TRY'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('calculateSessionActiveDuration', () {
    test(
      'yalnız active aralıklarını, açık aralıkta serverNow kullanarak toplar',
      () {
        final start = DateTime.utc(2026, 7, 17, 10);
        final duration = calculateSessionActiveDuration(
          entries: [
            _entry(
              type: TimeEntryType.active,
              startedAt: start,
              endedAt: start.add(const Duration(minutes: 10)),
            ),
            _entry(
              type: TimeEntryType.paused,
              startedAt: start.add(const Duration(minutes: 10)),
              endedAt: start.add(const Duration(minutes: 30)),
            ),
            _entry(
              type: TimeEntryType.active,
              startedAt: start.add(const Duration(minutes: 30)),
            ),
          ],
          serverNow: start.add(const Duration(minutes: 37, seconds: 5)),
        );

        expect(duration, const Duration(minutes: 17, seconds: 5));
      },
    );
  });
}

SessionItem _item({required int lineTotalMinor}) => SessionItem(
  id: 'item-$lineTotalMinor',
  businessId: 'business',
  sessionId: 'session',
  productId: 'product',
  productNameSnapshot: 'Ürün',
  skuSnapshot: null,
  unitPriceMinorSnapshot: lineTotalMinor,
  currencyCodeSnapshot: 'TRY',
  quantity: 1,
  discountMinor: 0,
  taxMinor: 0,
  lineTotalMinor: lineTotalMinor,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

SessionTimeEntry _entry({
  required TimeEntryType type,
  required DateTime startedAt,
  DateTime? endedAt,
}) => SessionTimeEntry(
  id: '${type.name}-${startedAt.microsecondsSinceEpoch}',
  businessId: 'business',
  sessionId: 'session',
  entryType: type,
  startedAt: startedAt,
  endedAt: endedAt,
  createdAt: startedAt,
);
