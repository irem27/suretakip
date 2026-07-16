import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:menusayac/app/router/app_router.dart';
import 'package:menusayac/app/theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key, this.routerOverride});

  final GoRouter? routerOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appRouter = routerOverride ?? ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Menü Sayaç',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
