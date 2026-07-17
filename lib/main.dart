import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:suretakip/app/app.dart';
import 'package:suretakip/core/services/supabase_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseInitializer.initialize();
  runApp(const ProviderScope(child: App()));
}
