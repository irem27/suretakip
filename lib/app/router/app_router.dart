import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/app/router/startup_page.dart';
import 'package:suretakip/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:suretakip/features/auth/presentation/pages/login_page.dart';
import 'package:suretakip/features/auth/presentation/pages/register_page.dart';
import 'package:suretakip/features/auth/presentation/pages/reset_password_page.dart';
import 'package:suretakip/features/businesses/presentation/pages/onboarding_page.dart';
import 'package:suretakip/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:suretakip/features/definitions/presentation/pages/definitions_menu_page.dart';
import 'package:suretakip/features/history/presentation/pages/history_page.dart';
import 'package:suretakip/features/customers/presentation/pages/customer_detail_page.dart';
import 'package:suretakip/features/customers/presentation/pages/customer_form_page.dart';
import 'package:suretakip/features/customers/presentation/pages/customers_list_page.dart';
import 'package:suretakip/features/products/presentation/pages/product_detail_page.dart';
import 'package:suretakip/features/products/presentation/pages/product_form_page.dart';
import 'package:suretakip/features/products/presentation/pages/products_list_page.dart';
import 'package:suretakip/features/reports/presentation/pages/reports_page.dart';
import 'package:suretakip/features/services/presentation/pages/service_detail_page.dart';
import 'package:suretakip/features/services/presentation/pages/service_form_page.dart';
import 'package:suretakip/features/services/presentation/pages/services_list_page.dart';
import 'package:suretakip/features/sessions/presentation/pages/session_detail_page.dart';
import 'package:suretakip/features/sessions/presentation/pages/start_session_page.dart';

// GoRouter YALNIZCA BİR KEZ oluşturulur. Auth/işletme durumu değiştiğinde
// router yeniden yaratılmaz; sadece [refreshListenable] tetiklenip `redirect`
// tekrar çalışır. Böylece token yenilemesi gibi olaylarda navigasyon yığını
// ve ekran state'i (ör. onboarding form girdileri) korunur.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authenticatedUserIdProvider, (_, _) => refresh.value++);
  ref.listen(userBusinessesProvider, (_, _) => refresh.value++);

  late final GoRouter router;
  router = GoRouter(
    initialLocation: AppRoutes.startup,
    refreshListenable: refresh,
    routes: [
      GoRoute(
        name: AppRouteNames.startup,
        path: AppRoutes.startup,
        builder: (context, state) => const StartupPage(),
      ),
      GoRoute(
        name: AppRouteNames.login,
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        name: AppRouteNames.register,
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        name: AppRouteNames.forgotPassword,
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        name: AppRouteNames.resetPassword,
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        name: AppRouteNames.onboarding,
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        name: AppRouteNames.dashboard,
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        name: AppRouteNames.history,
        path: AppRoutes.history,
        builder: (context, state) => const HistoryPage(),
      ),
      GoRoute(
        name: AppRouteNames.reports,
        path: AppRoutes.reports,
        builder: (context, state) => const ReportsPage(),
      ),
      GoRoute(
        name: AppRouteNames.services,
        path: AppRoutes.services,
        builder: (context, state) => const ServicesListPage(),
      ),
      GoRoute(
        name: AppRouteNames.serviceCreate,
        path: AppRoutes.serviceCreate,
        builder: (context, state) => const ServiceFormPage(),
      ),
      GoRoute(
        name: AppRouteNames.serviceDetail,
        path: AppRoutes.serviceDetail,
        builder: (context, state) => ServiceDetailPage(
          serviceId: state.pathParameters['serviceId'] ?? '',
        ),
      ),
      GoRoute(
        name: AppRouteNames.serviceEdit,
        path: AppRoutes.serviceEdit,
        builder: (context, state) =>
            ServiceFormPage(serviceId: state.pathParameters['serviceId'] ?? ''),
      ),
      GoRoute(
        name: AppRouteNames.definitions,
        path: AppRoutes.definitions,
        builder: (context, state) => const DefinitionsMenuPage(),
      ),
      GoRoute(
        name: AppRouteNames.products,
        path: AppRoutes.products,
        builder: (context, state) => const ProductsListPage(),
      ),
      GoRoute(
        name: AppRouteNames.productCreate,
        path: AppRoutes.productCreate,
        builder: (context, state) => const ProductFormPage(),
      ),
      GoRoute(
        name: AppRouteNames.productDetail,
        path: AppRoutes.productDetail,
        builder: (context, state) => ProductDetailPage(
          productId: state.pathParameters['productId'] ?? '',
        ),
      ),
      GoRoute(
        name: AppRouteNames.productEdit,
        path: AppRoutes.productEdit,
        builder: (context, state) =>
            ProductFormPage(productId: state.pathParameters['productId'] ?? ''),
      ),
      GoRoute(
        name: AppRouteNames.customers,
        path: AppRoutes.customers,
        builder: (context, state) => const CustomersListPage(),
      ),
      GoRoute(
        name: AppRouteNames.customerCreate,
        path: AppRoutes.customerCreate,
        builder: (context, state) => const CustomerFormPage(),
      ),
      GoRoute(
        name: AppRouteNames.customerDetail,
        path: AppRoutes.customerDetail,
        builder: (context, state) => CustomerDetailPage(
          customerId: state.pathParameters['customerId'] ?? '',
        ),
      ),
      GoRoute(
        name: AppRouteNames.customerEdit,
        path: AppRoutes.customerEdit,
        builder: (context, state) => CustomerFormPage(
          customerId: state.pathParameters['customerId'] ?? '',
        ),
      ),
      GoRoute(
        name: AppRouteNames.sessionStart,
        path: AppRoutes.sessionStart,
        builder: (context, state) => const StartSessionPage(),
      ),
      GoRoute(
        name: AppRouteNames.sessionDetail,
        path: AppRoutes.sessionDetail,
        builder: (context, state) => SessionDetailPage(
          sessionId: state.pathParameters['sessionId'] ?? '',
        ),
      ),
    ],
    redirect: (context, state) {
      // Güncel durum her çağrıda taze okunur (router yeniden yaratılmadığı için).
      final auth = ref.read(authenticatedUserIdProvider);
      final businesses = ref.read(userBusinessesProvider);
      final isResetPassword = state.matchedLocation == AppRoutes.resetPassword;

      if (auth.isLoading) {
        if (isResetPassword) return null;
        return state.matchedLocation == AppRoutes.startup
            ? null
            : AppRoutes.startup;
      }
      if (auth.hasError) {
        return state.matchedLocation == AppRoutes.startup
            ? null
            : AppRoutes.startup;
      }

      final userId = auth.valueOrNull;
      final isAuthPage = {
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
        AppRoutes.resetPassword,
      }.contains(state.matchedLocation);
      if (userId == null) return isAuthPage ? null : AppRoutes.login;
      if (isResetPassword) return null;

      if (businesses.isLoading || businesses.hasError) {
        return state.matchedLocation == AppRoutes.startup
            ? null
            : AppRoutes.startup;
      }

      final hasBusiness = businesses.valueOrNull?.isNotEmpty ?? false;
      if (!hasBusiness) {
        return state.matchedLocation == AppRoutes.onboarding
            ? null
            : AppRoutes.onboarding;
      }
      final isBusinessPage =
          state.matchedLocation == AppRoutes.dashboard ||
          state.matchedLocation == AppRoutes.history ||
          state.matchedLocation == AppRoutes.reports ||
          state.matchedLocation == AppRoutes.definitions ||
          state.matchedLocation == AppRoutes.services ||
          state.matchedLocation == AppRoutes.serviceCreate ||
          state.matchedLocation.startsWith('${AppRoutes.services}/') ||
          state.matchedLocation == AppRoutes.products ||
          state.matchedLocation == AppRoutes.productCreate ||
          state.matchedLocation.startsWith('${AppRoutes.products}/') ||
          state.matchedLocation == AppRoutes.customers ||
          state.matchedLocation == AppRoutes.customerCreate ||
          state.matchedLocation.startsWith('${AppRoutes.customers}/');
      final isSessionPage =
          state.matchedLocation == AppRoutes.sessionStart ||
          state.matchedLocation.startsWith('/sessions/');
      return isBusinessPage || isSessionPage ? null : AppRoutes.dashboard;
    },
  );

  ref.listen(authSessionStateProvider, (_, next) {
    if (!(next.valueOrNull?.isPasswordRecovery ?? false)) return;
    router.go(AppRoutes.resetPassword);
  }, fireImmediately: true);

  return router;
});
