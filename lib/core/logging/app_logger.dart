abstract interface class AppLogger {
  void error(Object error, {StackTrace? stackTrace, String? context});

  void warn(Object warning, {StackTrace? stackTrace, String? context});

  void info(Object message, {String? context});
}
