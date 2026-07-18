abstract interface class AuthRepository {
  Stream<String?> watchAuthenticatedUserId();

  Future<String?> getAuthenticatedUserId();

  Future<void> signIn({required String email, required String password});

  /// Yeni hesap oluşturur. E-posta doğrulaması gerekiyorsa oturum açılmadan da
  /// dönebilir; çağıran taraf akışı buna göre yönetir.
  Future<void> signUp({required String email, required String password});

  /// Verilen e-posta adresine şifre sıfırlama bağlantısı gönderir.
  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}
