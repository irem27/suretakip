class AuthSessionState {
  const AuthSessionState({
    required this.userId,
    this.isPasswordRecovery = false,
  });

  final String? userId;
  final bool isPasswordRecovery;

  // İçerik eşitliği: Supabase token yenilemede (saatlik) onAuthStateChange aynı
  // içerikli yeni bir örnek yayar. == olmadan Riverpod her olayı farklı sayıp
  // userBusinessesProvider'ı gereksizce yeniden çalıştırır (fazladan ağ çağrısı).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSessionState &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          isPasswordRecovery == other.isPasswordRecovery;

  @override
  int get hashCode => Object.hash(userId, isPasswordRecovery);
}
