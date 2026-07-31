import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/utils/business_date_ranges.dart';

void main() {
  test('İstanbul bugünü sunucu anından UTC sınırlarına çevirir', () {
    final range = BusinessDateRanges.day(
      serverNow: DateTime.utc(2026, 7, 18, 12),
      timezone: 'Europe/Istanbul',
    );

    expect(range.start, DateTime.utc(2026, 7, 17, 21));
    expect(range.endExclusive, DateTime.utc(2026, 7, 18, 21));
  });

  test('Berlin DST geçiş gününde gün 23 saat sürer', () {
    final range = BusinessDateRanges.day(
      serverNow: DateTime.utc(2026, 3, 29, 12),
      timezone: 'Europe/Berlin',
    );

    expect(range.start, DateTime.utc(2026, 3, 28, 23));
    expect(range.endExclusive, DateTime.utc(2026, 3, 29, 22));
  });

  test('hafta pazartesi başlar', () {
    final range = BusinessDateRanges.week(
      serverNow: DateTime.utc(2026, 7, 18, 12),
      timezone: 'Europe/Istanbul',
    );

    expect(range.start, DateTime.utc(2026, 7, 12, 21));
    expect(range.endExclusive, DateTime.utc(2026, 7, 19, 21));
  });

  test('ay ayın ilk gününden başlar ve bir sonraki ayla biter', () {
    final range = BusinessDateRanges.month(
      serverNow: DateTime.utc(2026, 7, 18, 12),
      timezone: 'Europe/Istanbul',
    );

    expect(range.start, DateTime.utc(2026, 6, 30, 21));
    expect(range.endExclusive, DateTime.utc(2026, 7, 31, 21));
  });

  test('New York DST geçişinde ay sınırı ofseti doğru hesaplar', () {
    final range = BusinessDateRanges.month(
      serverNow: DateTime.utc(2026, 3, 10, 12),
      timezone: 'America/New_York',
    );

    expect(range.start, DateTime.utc(2026, 3, 1, 5));
    expect(range.endExclusive, DateTime.utc(2026, 4, 1, 4));
  });

  test('localDates seçilen takvim aralığını UTC sınırlarına çevirir', () {
    final range = BusinessDateRanges.localDates(
      firstDate: DateTime.utc(2026, 7, 1),
      lastDate: DateTime.utc(2026, 7, 5),
      timezone: 'Europe/Istanbul',
    );

    expect(range.start, DateTime.utc(2026, 6, 30, 21));
    expect(range.endExclusive, DateTime.utc(2026, 7, 5, 21));
  });

  test('localDate bir anı işletme yerel takvim gününe çevirir', () {
    final result = BusinessDateRanges.localDate(
      instant: DateTime.utc(2026, 7, 18, 23),
      timezone: 'Europe/Istanbul',
    );

    expect(result, DateTime(2026, 7, 19));
  });

  test('localDateTime bir anı işletme yerel duvar saatine çevirir', () {
    final result = BusinessDateRanges.localDateTime(
      instant: DateTime.utc(2026, 7, 18, 10, 30, 15),
      timezone: 'Europe/Istanbul',
    );

    expect(result, DateTime.utc(2026, 7, 18, 13, 30, 15));
  });

  test('UtcDateRange.contains aralık sınırlarını doğru değerlendirir', () {
    final range = BusinessDateRanges.day(
      serverNow: DateTime.utc(2026, 7, 18, 12),
      timezone: 'Europe/Istanbul',
    );

    expect(range.contains(range.start), isTrue);
    expect(range.contains(range.endExclusive), isFalse);
    expect(
      range.contains(range.start.subtract(const Duration(seconds: 1))),
      isFalse,
    );
  });

  test('desteklenmeyen saat dilimi ArgumentError fırlatır', () {
    expect(
      () => BusinessDateRanges.day(
        serverNow: DateTime.utc(2026, 7, 18, 12),
        timezone: 'Asia/Tokyo',
      ),
      throwsArgumentError,
    );
  });

  test('isSupportedBusinessTimezone desteklenen saat dilimini onaylar', () {
    expect('Europe/Istanbul'.isSupportedBusinessTimezone, isTrue);
    expect('Asia/Tokyo'.isSupportedBusinessTimezone, isFalse);
  });
}
