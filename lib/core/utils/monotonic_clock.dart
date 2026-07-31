abstract interface class MonotonicClock {
  Duration get elapsed;

  void stop();
}

final class StopwatchMonotonicClock implements MonotonicClock {
  StopwatchMonotonicClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  void stop() => _stopwatch.stop();
}
