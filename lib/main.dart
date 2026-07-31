import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:suretakip/app/app.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/logging/app_logger_provider.dart';
import 'package:suretakip/core/services/supabase_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  final logger = container.read(appLoggerProvider);

  FlutterError.onError = (details) {
    logger.error(
      details.exception,
      stackTrace: details.stack,
      context: details.context?.toDescription(),
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    logger.error(
      error,
      stackTrace: stackTrace,
      context: 'Yakalanmamış platform hatası',
    );
    return true;
  };

  await SupabaseInitializer.initialize();
  container.read(syncTriggerServiceProvider);
  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
