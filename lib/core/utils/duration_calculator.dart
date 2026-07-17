import 'dart:math' as math;

int calculateChargedMinutes({
  required Duration activeDuration,
  required int roundingIntervalMinutes,
  required int minimumChargeMinutes,
}) {
  if (activeDuration.isNegative) {
    throw ArgumentError.value(
      activeDuration,
      'activeDuration',
      'Aktif süre negatif olamaz.',
    );
  }
  if (roundingIntervalMinutes <= 0) {
    throw ArgumentError.value(
      roundingIntervalMinutes,
      'roundingIntervalMinutes',
      'Yuvarlama aralığı sıfırdan büyük olmalıdır.',
    );
  }
  if (minimumChargeMinutes < 0) {
    throw ArgumentError.value(
      minimumChargeMinutes,
      'minimumChargeMinutes',
      'Minimum ücret süresi negatif olamaz.',
    );
  }

  final intervalMicroseconds =
      Duration.microsecondsPerMinute * roundingIntervalMinutes;
  final roundedIntervals =
      (activeDuration.inMicroseconds + intervalMicroseconds - 1) ~/
      intervalMicroseconds;
  final roundedMinutes = roundedIntervals * roundingIntervalMinutes;

  return math.max(roundedMinutes, minimumChargeMinutes);
}

Duration sumDurations(Iterable<Duration> durations) {
  var totalMicroseconds = 0;
  for (final duration in durations) {
    if (duration.isNegative) {
      throw ArgumentError.value(
        duration,
        'durations',
        'Toplanacak süreler negatif olamaz.',
      );
    }
    totalMicroseconds += duration.inMicroseconds;
  }
  return Duration(microseconds: totalMicroseconds);
}
