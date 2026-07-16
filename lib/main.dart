import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:menusayac/app/app.dart';
import 'package:menusayac/core/constants/app_constants.dart';
import 'package:menusayac/core/services/supabase_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: AppConstants.envFileName);
  await SupabaseInitializer.initialize();
  runApp(const ProviderScope(child: App()));
}
