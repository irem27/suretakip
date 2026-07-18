import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';

class LoginController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signIn(email: email.trim(), password: password),
    );
    return !state.hasError;
  }
}

class RegisterController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signUp(email: email.trim(), password: password),
    );
    return !state.hasError;
  }
}

class PasswordResetController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> send(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(email: email.trim()),
    );
    return !state.hasError;
  }
}

class SignOutController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}

final loginControllerProvider = AsyncNotifierProvider<LoginController, void>(
  LoginController.new,
);
final registerControllerProvider =
    AsyncNotifierProvider<RegisterController, void>(RegisterController.new);
final passwordResetControllerProvider =
    AsyncNotifierProvider<PasswordResetController, void>(
      PasswordResetController.new,
    );
final signOutControllerProvider =
    AsyncNotifierProvider<SignOutController, void>(SignOutController.new);
