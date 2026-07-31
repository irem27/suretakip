import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';
import 'package:suretakip/features/auth/domain/repositories/auth_repository.dart';
import 'package:suretakip/features/auth/presentation/controllers/auth_controllers.dart';

void main() {
  test(
    'LoginController giriş bilgilerini repository katmanına iletir',
    () async {
      final repository = _FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(loginControllerProvider.notifier)
          .signIn(email: '  test@example.com ', password: 'secret123');

      expect(success, isTrue);
      expect(repository.email, 'test@example.com');
      expect(repository.password, 'secret123');
    },
  );

  test('PasswordResetController repository reset methodunu çağırır', () async {
    final repository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(passwordResetControllerProvider.notifier)
        .send(' test@example.com ');

    expect(success, isTrue);
    expect(repository.resetEmail, 'test@example.com');
  });

  test('UpdatePasswordController yeni şifreyi repositoryye iletir', () async {
    final repository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(updatePasswordControllerProvider.notifier)
        .changePassword('yeni-secret');

    expect(success, isTrue);
    expect(repository.newPassword, 'yeni-secret');
  });
}

class _FakeAuthRepository implements AuthRepository {
  String? email;
  String? password;
  String? resetEmail;
  String? newPassword;

  @override
  Future<String?> getAuthenticatedUserId() async => null;

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    resetEmail = email;
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    this.newPassword = newPassword;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    this.email = email;
    this.password = password;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Stream<AuthSessionState> watchAuthState() => const Stream.empty();
}
