import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/errors/sensitive_data_sanitizer.dart';
import 'package:suretakip/core/errors/supabase_error_guard.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:suretakip/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(
    this._dataSource, {
    AppLogger logger = const NoopAppLogger(),
  }) : _logger = logger;

  final AuthRemoteDataSource _dataSource;
  final AppLogger _logger;

  @override
  Stream<String?> watchAuthenticatedUserId() =>
      _dataSource.watchAuthenticatedUserId();

  @override
  Future<String?> getAuthenticatedUserId() async =>
      _dataSource.getAuthenticatedUserId();

  @override
  Future<void> signIn({required String email, required String password}) =>
      _run(() => _dataSource.signIn(email: email, password: password));

  @override
  Future<void> signUp({required String email, required String password}) =>
      _run(() => _dataSource.signUp(email: email, password: password));

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      _run(() => _dataSource.sendPasswordResetEmail(email: email));

  @override
  Future<void> signOut() => _run(_dataSource.signOut);

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      _logger.error(error, stackTrace: stackTrace, context: 'AuthRepository');
      final networkException = SupabaseErrorGuard.mapNetworkError(error);
      if (networkException != null) throw networkException;
      if (error is DomainException) rethrow;
      if (error is AuthException) {
        throw AuthenticationException(
          _authMessage(error),
          code: error.code,
          cause: SensitiveDataSanitizer.sanitizedCause(),
        );
      }
      throw UnknownException(
        'İşlem tamamlanamadı. Lütfen tekrar deneyin.',
        cause: SensitiveDataSanitizer.sanitizedCause(),
      );
    }
  }

  String _authMessage(AuthException error) {
    return switch (error.code) {
      'invalid_credentials' => 'E-posta veya şifre hatalı.',
      'email_not_confirmed' =>
        'Devam etmek için e-posta adresinizi doğrulayın.',
      'user_already_exists' => 'Bu e-posta adresiyle bir hesap zaten var.',
      'weak_password' => 'Şifreniz yeterince güçlü değil.',
      'over_email_send_rate_limit' =>
        'Çok sık istek gönderdiniz. Lütfen biraz sonra tekrar deneyin.',
      _ => 'Kimlik doğrulama işlemi tamamlanamadı. Lütfen tekrar deneyin.',
    };
  }
}
