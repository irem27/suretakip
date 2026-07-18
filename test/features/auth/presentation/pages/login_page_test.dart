import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/theme/app_theme.dart';
import 'package:suretakip/features/auth/domain/repositories/auth_repository.dart';
import 'package:suretakip/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets('boş giriş formu Türkçe doğrulama mesajları verir', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();

    expect(find.text('E-posta zorunlu.'), findsOneWidget);
    expect(find.text('Şifre zorunlu.'), findsOneWidget);
  });

  testWidgets('dar ekranda ve 2.0x yazıda taşmaz, hedefler 48 pikseldir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, textScaler: const TextScaler.linear(2));

    expect(tester.takeException(), isNull);
    final loginButton = find.widgetWithText(FilledButton, 'Giriş Yap');
    expect(tester.getSize(loginButton).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('SüreTakip'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: const LoginPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<String?> watchAuthenticatedUserId() => const Stream.empty();

  @override
  Future<String?> getAuthenticatedUserId() async => null;

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
  Future<void> signOut() async {}
}
