import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';
import 'package:suretakip/features/auth/domain/repositories/auth_repository.dart';
import 'package:suretakip/features/auth/presentation/pages/forgot_password_page.dart';

void main() {
  testWidgets('boş ve geçersiz e-posta Türkçe doğrulama mesajı verir', (
    tester,
  ) async {
    await _pump(tester, _FakeAuthRepository());

    await tester.tap(find.text('Sıfırlama Bağlantısı Gönder'));
    await tester.pump();
    expect(find.text('E-posta zorunlu.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'geçersiz');
    await tester.tap(find.text('Sıfırlama Bağlantısı Gönder'));
    await tester.pump();
    expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
  });

  testWidgets('geçerli e-posta kırpılarak gönderilir ve başarı bildirilir', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pump(tester, repository);

    await tester.enterText(find.byType(TextFormField), '  ayse@example.com  ');
    await tester.tap(find.text('Sıfırlama Bağlantısı Gönder'));
    await tester.pumpAndSettle();

    expect(repository.resetEmail, 'ayse@example.com');
    expect(
      find.text('Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.'),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.widgetWithText(FilledButton, 'Sıfırlama Bağlantısı Gönder'),
          )
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('gönderim hatası kullanıcı mesajını snackbar içinde gösterir', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeAuthRepository(
        error: const NetworkException('Bağlantı kurulamadı.'),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'ayse@example.com');
    await tester.tap(find.text('Sıfırlama Bağlantısı Gönder'));
    await tester.pump();

    expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, _FakeAuthRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: ForgotPasswordPage()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.error});

  final Object? error;
  String? resetEmail;

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    if (error != null) throw error!;
    resetEmail = email;
  }

  @override
  Stream<AuthSessionState> watchAuthState() => const Stream.empty();

  @override
  Future<String?> getAuthenticatedUserId() async => null;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> updatePassword({required String newPassword}) async {}
}
