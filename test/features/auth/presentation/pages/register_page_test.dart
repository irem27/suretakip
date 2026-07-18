import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
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
