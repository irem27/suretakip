import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:suretakip/features/auth/data/repositories/auth_repository_impl.dart';

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
    expect(await repository.watchAuthenticatedUserId().toList(), [
      'user-1',
      null,
    ]);
  });
}

class _FakeAuthDataSource implements AuthRemoteDataSource {
  String? email;
  String? password;

  @override
  String? getAuthenticatedUserId() => 'user-1';

  @override
  Stream<String?> watchAuthenticatedUserId() =>
      Stream<String?>.fromIterable(['user-1', null]);

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
  Future<void> signOut() async {}
}
