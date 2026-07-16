import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:menusayac/core/constants/app_constants.dart';

class SupabaseInitializer {
  static Future<void> initialize() async {
    final supabaseUrl =
        dotenv.env[AppConstants.supabaseUrlEnvKey]?.trim() ?? '';
    final supabaseAnonKey =
        dotenv.env[AppConstants.supabaseAnonKeyEnvKey]?.trim() ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL ve SUPABASE_ANON_KEY değerleri .env dosyasında tanımlı olmalı.',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
