import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  Stream<AuthSessionState> watchAuthState() async* {
    yield AuthSessionState(userId: _client.auth.currentUser?.id);
    yield* _client.auth.onAuthStateChange.map(
      (state) => AuthSessionState(
        userId: state.session?.user.id,
        isPasswordRecovery: state.event == AuthChangeEvent.passwordRecovery,
      ),
    );
  }

  String? getAuthenticatedUserId() => _client.auth.currentUser?.id;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({required String email, required String password}) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    // Supabase, e-posta zaten kayıtlıysa (anti-enumeration) hata vermez; sahte
    // bir kullanıcı döndürür ve `identities` boş gelir. Bunu açık bir hataya
    // çeviririz ki kullanıcı "zaten kayıtlı" uyarısını görsün (repository
    // katmanı 'user_already_exists' kodunu uygun mesaja çevirir).
    final identities = response.user?.identities;
    if (identities != null && identities.isEmpty) {
      throw const AuthException(
        'Bu e-posta zaten kayıtlı.',
        code: 'user_already_exists',
      );
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: AppConstants.passwordResetRedirectUrl,
    );
  }

  Future<void> updatePassword({required String newPassword}) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() => _client.auth.signOut();
}
