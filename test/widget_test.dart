import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';
import 'package:suretakip/features/auth/domain/repositories/auth_repository.dart';
import 'package:suretakip/features/auth/presentation/pages/login_page.dart';

/// Supabase'e hiç dokunmayan sahte repository — widget testleri gerçek
/// bağlantı kurmadan render edilebilsin diye.
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

void main() {
  testWidgets('login ekranı render olur', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tekrar hoş geldiniz'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
