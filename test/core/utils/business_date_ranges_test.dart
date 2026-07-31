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
}
