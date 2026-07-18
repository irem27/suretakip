import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:suretakip/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';

void main() {
  test(
    'kimlik bilgilerini değiştirmeden datasource katmanına iletir',
    () async {
      final dataSource = _FakeAuthDataSource();
      final repository = AuthRepositoryImpl(dataSource);

      await repository.signIn(
        email: 'kullanici@example.com',
        password: 'secret',
      );

      expect(dataSource.email, 'kullanici@example.com');
      expect(dataSource.password, 'secret');
    },
  );

  test('mevcut kullanıcı ve auth akışı güvenli biçimde iletilir', () async {
    final repository = AuthRepositoryImpl(_FakeAuthDataSource());

    expect(await repository.getAuthenticatedUserId(), 'user-1');
    final states = await repository.watchAuthState().toList();
    expect(states.map((state) => state.userId), ['user-1', null]);
    expect(states.last.isPasswordRecovery, isTrue);
  });

  test('yeni şifreyi değiştirmeden datasource katmanına iletir', () async {
    final dataSource = _FakeAuthDataSource();
    final repository = AuthRepositoryImpl(dataSource);

    await repository.updatePassword(newPassword: 'yeni-secret');

    expect(dataSource.newPassword, 'yeni-secret');
  });
}

class _FakeAuthDataSource implements AuthRemoteDataSource {
  String? email;
  String? password;
  String? newPassword;

  @override
  String? getAuthenticatedUserId() => 'user-1';

  @override
  Stream<AuthSessionState> watchAuthState() => Stream.fromIterable(const [
    AuthSessionState(userId: 'user-1'),
    AuthSessionState(userId: null, isPasswordRecovery: true),
  ]);

  @override
  Future<void> signIn({required String email, required String password}) async {
    this.email = email;
    this.password = password;
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> updatePassword({required String newPassword}) async {
    this.newPassword = newPassword;
  }

  @override
  Future<void> signOut() async {}
}
