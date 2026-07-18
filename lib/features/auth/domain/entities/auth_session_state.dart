class AuthSessionState {
  const AuthSessionState({
    required this.userId,
    this.isPasswordRecovery = false,
  });

  final String? userId;
  final bool isPasswordRecovery;
}
