import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
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

  test('kayıt, sıfırlama e-postası ve çıkış işlemlerini iletir', () async {
    final dataSource = _FakeAuthDataSource();
    final repository = AuthRepositoryImpl(dataSource);

    await repository.signUp(email: 'yeni@example.com', password: 'secret123');
    await repository.sendPasswordResetEmail(email: 'yeni@example.com');
    await repository.signOut();

    expect(dataSource.signUpEmail, 'yeni@example.com');
    expect(dataSource.signUpPassword, 'secret123');
    expect(dataSource.resetEmail, 'yeni@example.com');
    expect(dataSource.signedOut, isTrue);
  });

  test('Supabase auth kodunu güvenli Türkçe domain hatasına eşler', () async {
    final repository = AuthRepositoryImpl(
      _FakeAuthDataSource(
        error: const AuthException(
          'ham sağlayıcı mesajı',
          code: 'invalid_credentials',
        ),
      ),
    );

    expect(
      () => repository.signIn(email: 'x@example.com', password: 'yanlış'),
      throwsA(
        isA<AuthenticationException>()
            .having(
              (error) => error.message,
              'message',
              'E-posta veya şifre hatalı.',
            )
            .having((error) => error.code, 'code', 'invalid_credentials'),
      ),
    );
  });

  test('bilinmeyen hatayı kullanıcı güvenli mesajına eşler', () async {
    final repository = AuthRepositoryImpl(
      _FakeAuthDataSource(error: StateError('gizli ayrıntı')),
    );

    expect(
      () => repository.signIn(email: 'x@example.com', password: 'secret'),
      throwsA(
        isA<UnknownException>().having(
          (error) => error.message,
          'message',
          'İşlem tamamlanamadı. Lütfen tekrar deneyin.',
        ),
      ),
    );
  });

  test('hazır domain hatasını değiştirmeden yeniden fırlatır', () async {
    const error = ValidationException('Geçersiz istek.');
    final repository = AuthRepositoryImpl(_FakeAuthDataSource(error: error));

    expect(
      () => repository.signIn(email: 'x@example.com', password: 'secret'),
      throwsA(same(error)),
    );
  });
}

class _FakeAuthDataSource implements AuthRemoteDataSource {
  _FakeAuthDataSource({this.error});

  final Object? error;
  String? email;
  String? password;
  String? newPassword;
  String? signUpEmail;
  String? signUpPassword;
  String? resetEmail;
  bool signedOut = false;

  @override
  String? getAuthenticatedUserId() => 'user-1';

  @override
  Stream<AuthSessionState> watchAuthState() => Stream.fromIterable(const [
    AuthSessionState(userId: 'user-1'),
    AuthSessionState(userId: null, isPasswordRecovery: true),
  ]);

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (error != null) throw error!;
    this.email = email;
    this.password = password;
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    signUpEmail = email;
    signUpPassword = password;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    resetEmail = email;
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    this.newPassword = newPassword;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}
