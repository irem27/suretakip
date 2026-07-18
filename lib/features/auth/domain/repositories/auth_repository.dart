import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';

abstract interface class AuthRepository {
  Stream<AuthSessionState> watchAuthState();

  Future<String?> getAuthenticatedUserId();

  Future<void> signIn({required String email, required String password});

  /// Yeni hesap oluşturur. E-posta doğrulaması gerekiyorsa oturum açılmadan da
  /// dönebilir; çağıran taraf akışı buna göre yönetir.
  Future<void> signUp({required String email, required String password});

  /// Verilen e-posta adresine şifre sıfırlama bağlantısı gönderir.
  Future<void> sendPasswordResetEmail({required String email});

  Future<void> updatePassword({required String newPassword});

  Future<void> signOut();
}
