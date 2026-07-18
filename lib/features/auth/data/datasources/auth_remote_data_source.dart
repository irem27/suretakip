import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  Stream<String?> watchAuthenticatedUserId() async* {
    yield _client.auth.currentUser?.id;
    yield* _client.auth.onAuthStateChange.map(
      (event) => event.session?.user.id,
    );
  }

  String? getAuthenticatedUserId() => _client.auth.currentUser?.id;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({required String email, required String password}) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() => _client.auth.signOut();
}
