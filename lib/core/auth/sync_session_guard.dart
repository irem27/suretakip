import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';

/// Push öncesi geçerli bir Supabase session sağlar (Bölüm 16.1). Dönüş:
/// - `null`: geçerli oturum var, push devam edebilir.
/// - `authRequired`: yeniden giriş gerekiyor, worker durmalı.
/// - `retryableFailure`: refresh geçici olarak başarısız, backoff ile tekrar.
abstract interface class SyncSessionGuard {
  Future<SyncResultType?> ensureValidSession();
}

/// Supabase tabanlı implementasyon. Access token geçerliyse dokunmaz; dolmuş
/// veya güvenli eşik içinde dolacaksa tek bir sessiz refresh dener.
class SupabaseSessionGuard implements SyncSessionGuard {
  SupabaseSessionGuard(this._client, {Duration? refreshThreshold})
    : _refreshThreshold = refreshThreshold ?? const Duration(minutes: 2);

  final SupabaseClient _client;
  final Duration _refreshThreshold;

  Future<void>? _inFlight;

  @override
  Future<SyncResultType?> ensureValidSession() async {
    final session = _client.auth.currentSession;
    if (session == null) return SyncResultType.authRequired;

    if (!_needsRefresh(session)) return null;

    try {
      // Eşzamanlı refresh çağrılarını tek uçuşa indir (single-flight).
      await (_inFlight ??= _refresh());
      return _client.auth.currentSession == null
          ? SyncResultType.authRequired
          : null;
    } on AuthException {
      return SyncResultType.authRequired;
    } catch (_) {
      // Ağ hatası: geçici say, backoff ile tekrar denenir.
      return SyncResultType.retryableFailure;
    } finally {
      _inFlight = null;
    }
  }

  bool _needsRefresh(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      expiresAt * 1000,
      isUtc: true,
    );
    return DateTime.now().toUtc().add(_refreshThreshold).isAfter(expiry);
  }

  Future<void> _refresh() async {
    await _client.auth.refreshSession();
  }
}
