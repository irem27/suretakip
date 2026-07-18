import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:suretakip/core/constants/app_constants.dart';

class SupabaseInitializer {
  // Derleme zamanı sabitleri: `--dart-define` / `--dart-define-from-file` ile verilir.
  static const _supabaseUrl = String.fromEnvironment(
    AppConstants.supabaseUrlEnvKey,
  );
  static const _supabaseAnonKey = String.fromEnvironment(
    AppConstants.supabaseAnonKeyEnvKey,
  );

  static Future<void> initialize() async {
    final supabaseUrl = _supabaseUrl.trim();
    final supabaseAnonKey = _supabaseAnonKey.trim();

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL ve SUPABASE_ANON_KEY tanımlı değil. '
        'Uygulamayı `--dart-define-from-file=.env.staging` veya '
        '`.env.production` ile çalıştırın (bkz. README).',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
