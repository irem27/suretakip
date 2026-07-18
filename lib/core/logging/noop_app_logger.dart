import 'package:suretakip/core/logging/app_logger.dart';

final class NoopAppLogger implements AppLogger {
  const NoopAppLogger();

  @override
  void error(Object error, {StackTrace? stackTrace, String? context}) {}

  @override
  void warn(Object warning, {StackTrace? stackTrace, String? context}) {}

  @override
  void info(Object message, {String? context}) {}
}
