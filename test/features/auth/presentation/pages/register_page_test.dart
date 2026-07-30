import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';
import 'package:suretakip/features/auth/domain/repositories/auth_repository.dart';
import 'package:suretakip/features/auth/presentation/pages/register_page.dart';

void main() {
  testWidgets('kayıt formu Türkçe parola doğrulamalarını gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(home: RegisterPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kayıt Ol'));
    await tester.pumpAndSettle();

    expect(find.text('E-posta zorunlu.'), findsOneWidget);
    expect(find.text('Şifre zorunlu.'), findsOneWidget);
  });

  testWidgets(
    'signUp oturum kurmadıysa (e-posta doğrulaması bekleniyorsa) login sayfasına yönlendirir',
    (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.register,
        routes: [
          GoRoute(
            path: AppRoutes.register,
            builder: (context, state) => const RegisterPage(),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (context, state) =>
                const Scaffold(body: Text('Giriş Sayfası')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(authenticatedUserId: null),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Sifre123!');
      await tester.enterText(find.byType(TextFormField).at(2), 'Sifre123!');
      await tester.tap(find.text('Kayıt Ol'));
      await tester.pumpAndSettle();

      expect(find.text('Giriş Sayfası'), findsOneWidget);
    },
  );

  testWidgets(
    'signUp anında oturum kurduysa register sayfasında koşulsuz login navigasyonu yapmaz',
    (tester) async {
      final router = GoRouter(
        initialLocation: AppRoutes.register,
        routes: [
          GoRoute(
            path: AppRoutes.register,
            builder: (context, state) => const RegisterPage(),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (context, state) =>
                const Scaffold(body: Text('Giriş Sayfası')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(authenticatedUserId: 'user-1'),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Sifre123!');
      await tester.enterText(find.byType(TextFormField).at(2), 'Sifre123!');
      await tester.tap(find.text('Kayıt Ol'));
      await tester.pumpAndSettle();

      // Oturum zaten kurulduğu için sayfa router redirect'ine bırakılır;
      // register_page kendisi login'e zorlamaz.
      expect(find.text('Giriş Sayfası'), findsNothing);
      expect(find.byType(RegisterPage), findsOneWidget);
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.authenticatedUserId});

  final String? authenticatedUserId;

  @override
  Stream<AuthSessionState> watchAuthState() => const Stream.empty();

  @override
  Future<String?> getAuthenticatedUserId() async => authenticatedUserId;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> updatePassword({required String newPassword}) async {}

  @override
  Future<void> signOut() async {}
}
