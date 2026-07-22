/// Bir kaydın merkezle olan senkronizasyon durumu (Bölüm 25).
enum SyncStatus {
  localOnly,
  pending,
  processing,
  retrying,
  synced,
  conflicted,
  rejected;

  String get wireName => name;

  static SyncStatus fromWire(String value) =>
      SyncStatus.values.firstWhere((s) => s.name == value);
}

/// Outbox operasyon türleri (Sprint 1 müşteri + Faz C seans event'leri).
enum SyncOperationType {
  createCustomer,
  startSession,
  pauseSession,
  resumeSession;

  String get wireName => name;

  static SyncOperationType fromWire(String value) =>
      SyncOperationType.values.firstWhere((o) => o.name == value);
}

/// Sunucu RPC çağrısının sınıflandırılmış sonucu (Bölüm 25).
enum SyncResultType {
  applied,
  alreadyProcessed,
  retryableFailure,
  conflict,
  rejected,
  authRequired,
}
