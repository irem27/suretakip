import 'package:suretakip/core/constants/app_constants.dart';

final class UtcDateRange {
  const UtcDateRange({required this.start, required this.endExclusive});

  final DateTime start;
  final DateTime endExclusive;

  bool contains(DateTime value) {
    final utc = value.toUtc();
    return !utc.isBefore(start) && utc.isBefore(endExclusive);
  }
}

final class BusinessDateRanges {
  const BusinessDateRanges._();

  static UtcDateRange day({
    required DateTime serverNow,
    required String timezone,
  }) {
    final localNow = _localWallTime(serverNow.toUtc(), timezone);
    final start = DateTime.utc(localNow.year, localNow.month, localNow.day);
    return _wallRange(start, start.add(const Duration(days: 1)), timezone);
  }

  static UtcDateRange week({
    required DateTime serverNow,
    required String timezone,
  }) {
    final localNow = _localWallTime(serverNow.toUtc(), timezone);
    final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
    final start = today.subtract(Duration(days: localNow.weekday - 1));
    return _wallRange(start, start.add(const Duration(days: 7)), timezone);
  }

  static UtcDateRange month({
    required DateTime serverNow,
    required String timezone,
  }) {
    final localNow = _localWallTime(serverNow.toUtc(), timezone);
    final start = DateTime.utc(localNow.year, localNow.month);
    final end = DateTime.utc(localNow.year, localNow.month + 1);
    return _wallRange(start, end, timezone);
  }

  static UtcDateRange localDates({
    required DateTime firstDate,
    required DateTime lastDate,
    required String timezone,
  }) {
    final start = DateTime.utc(firstDate.year, firstDate.month, firstDate.day);
    final end = DateTime.utc(lastDate.year, lastDate.month, lastDate.day + 1);
    return _wallRange(start, end, timezone);
  }

  static DateTime localDate({
    required DateTime instant,
    required String timezone,
  }) {
    final wall = _localWallTime(instant.toUtc(), timezone);
    return DateTime(wall.year, wall.month, wall.day);
  }

  static DateTime localDateTime({
    required DateTime instant,
    required String timezone,
  }) {
    final wall = _localWallTime(instant.toUtc(), timezone);
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
    );
  }

  static UtcDateRange _wallRange(
    DateTime startWall,
    DateTime endWall,
    String timezone,
  ) => UtcDateRange(
    start: _wallToUtc(startWall, timezone),
    endExclusive: _wallToUtc(endWall, timezone),
  );

  static DateTime _localWallTime(DateTime utc, String timezone) =>
      utc.add(_offsetAtUtc(utc, timezone));

  static DateTime _wallToUtc(DateTime wall, String timezone) {
    var candidate = wall.subtract(_standardOffset(timezone));
    candidate = wall.subtract(_offsetAtUtc(candidate, timezone));
    return candidate.toUtc();
  }

  static Duration _standardOffset(String timezone) => switch (timezone) {
    'Europe/Istanbul' => const Duration(hours: 3),
    'Europe/London' => Duration.zero,
    'Europe/Berlin' => const Duration(hours: 1),
    'America/New_York' => const Duration(hours: -5),
    _ => throw ArgumentError.value(
      timezone,
      'timezone',
      'Desteklenmeyen işletme saat dilimi.',
    ),
  };

  static Duration _offsetAtUtc(DateTime utc, String timezone) =>
      switch (timezone) {
        'Europe/Istanbul' => const Duration(hours: 3),
        'Europe/London' =>
          _isEuropeDst(utc) ? const Duration(hours: 1) : Duration.zero,
        'Europe/Berlin' =>
          _isEuropeDst(utc)
              ? const Duration(hours: 2)
              : const Duration(hours: 1),
        'America/New_York' =>
          _isNewYorkDst(utc)
              ? const Duration(hours: -4)
              : const Duration(hours: -5),
        _ => _standardOffset(timezone),
      };

  static bool _isEuropeDst(DateTime utc) {
    final start = DateTime.utc(utc.year, 3, _lastSunday(utc.year, 3), 1);
    final end = DateTime.utc(utc.year, 10, _lastSunday(utc.year, 10), 1);
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static bool _isNewYorkDst(DateTime utc) {
    final startDay = _nthSunday(utc.year, 3, 2);
    final endDay = _nthSunday(utc.year, 11, 1);
    final start = DateTime.utc(utc.year, 3, startDay, 7);
    final end = DateTime.utc(utc.year, 11, endDay, 6);
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static int _lastSunday(int year, int month) {
    final lastDay = DateTime.utc(year, month + 1, 0);
    return lastDay.day - (lastDay.weekday % DateTime.daysPerWeek);
  }

  static int _nthSunday(int year, int month, int occurrence) {
    final first = DateTime.utc(year, month);
    final firstSunday = 1 + ((DateTime.sunday - first.weekday) % 7);
    return firstSunday + ((occurrence - 1) * 7);
  }
}

extension AppTimezoneValidation on String {
  bool get isSupportedBusinessTimezone =>
      AppConstants.supportedTimezones.contains(this);
}
