import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';
import 'package:suretakip/features/auth/domain/repositories/auth_repository.dart';
import 'package:suretakip/features/auth/presentation/pages/reset_password_page.dart';

void main() {
  testWidgets('boş form Türkçe şifre doğrulamalarını gösterir', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Şifreyi Güncelle'));
    await tester.pumpAndSettle();

    expect(find.text('Şifre zorunlu.'), findsNWidgets(2));
  });

  testWidgets('farklı şifreler eşleşme hatası gösterir', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextFormField).first, 'yeni-secret');
    await tester.enterText(find.byType(TextFormField).last, 'farkli-secret');
    await tester.tap(find.text('Şifreyi Güncelle'));
    await tester.pumpAndSettle();

    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
      child: const MaterialApp(home: ResetPasswordPage()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeAuthRepository implements AuthRepository {
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
