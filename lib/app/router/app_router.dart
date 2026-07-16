import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:menusayac/features/auth/presentation/pages/login_page.dart';
import 'package:menusayac/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:menusayac/app/providers/app_providers.dart';
import 'package:menusayac/app/router/app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);
  final supabaseClient = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        name: AppRouteNames.login,
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        name: AppRouteNames.dashboard,
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardPage(),
      ),
    ],
    redirect: (context, state) {
      final session = supabaseClient.auth.currentSession;
      final loggedIn = session != null;
      final goingToLogin = state.matchedLocation == AppRoutes.login;

      if (!loggedIn) {
        return goingToLogin ? null : AppRoutes.login;
      }

      if (goingToLogin) {
        return AppRoutes.dashboard;
      }

      return null;
    },
  );
});
