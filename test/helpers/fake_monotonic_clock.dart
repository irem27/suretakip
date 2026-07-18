import 'package:suretakip/core/utils/monotonic_clock.dart';

final class FakeMonotonicClock implements MonotonicClock {
  FakeMonotonicClock([this._elapsed = Duration.zero]);

  Duration _elapsed;
  bool isStopped = false;

  @override
  Duration get elapsed => _elapsed;

  void advance(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'Negatif olamaz.');
    }
    if (!isStopped) _elapsed += duration;
  }

  @override
  void stop() => isStopped = true;
}
