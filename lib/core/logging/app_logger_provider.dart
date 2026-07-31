import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/console_app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';

final appLoggerProvider = Provider<AppLogger>((ref) {
  if (kDebugMode) return ConsoleAppLogger();
  return const NoopAppLogger();
});
