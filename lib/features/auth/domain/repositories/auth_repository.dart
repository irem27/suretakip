abstract interface class AuthRepository {
  Stream<String?> watchAuthenticatedUserId();

  Future<String?> getAuthenticatedUserId();

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}
