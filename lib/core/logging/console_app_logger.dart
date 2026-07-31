import 'package:flutter/foundation.dart';
import 'package:suretakip/core/errors/sensitive_data_sanitizer.dart';
import 'package:suretakip/core/logging/app_logger.dart';

typedef LogOutput = void Function(String message);

final class ConsoleAppLogger implements AppLogger {
  ConsoleAppLogger({LogOutput? output})
    : _output = output ?? ((message) => debugPrint(message));

  final LogOutput _output;

  @override
  void error(Object error, {StackTrace? stackTrace, String? context}) => _write(
    level: 'ERROR',
    value: error,
    stackTrace: stackTrace,
    context: context,
  );

  @override
  void warn(Object warning, {StackTrace? stackTrace, String? context}) =>
      _write(
        level: 'WARN',
        value: warning,
        stackTrace: stackTrace,
        context: context,
      );

  @override
  void info(Object message, {String? context}) =>
      _write(level: 'INFO', value: message, context: context);

  void _write({
    required String level,
    required Object value,
    StackTrace? stackTrace,
    String? context,
  }) {
    if (!kDebugMode) return;
    final safeContext = context == null
        ? null
        : SensitiveDataSanitizer.sanitize(context);
    final safeValue = SensitiveDataSanitizer.sanitize(value);
    final safeStack = stackTrace == null
        ? null
        : SensitiveDataSanitizer.sanitize(stackTrace);
    final contextPart = safeContext == null ? '' : ' [$safeContext]';
    final stackPart = safeStack == null ? '' : '\n$safeStack';
    _output('$level$contextPart: $safeValue$stackPart');
  }
}
