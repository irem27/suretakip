import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';

/// Fırlatılan bir transport hatasını yeniden denenebilir (geçici) veya kalıcı
/// olarak sınıflandırır (Bölüm 12). İş kuralı hataları RPC'den `result_json`
/// içinde döndüğü için burada değil, sonuç ayrıştırmasında ele alınır.
class SyncErrorClassifier {
  const SyncErrorClassifier();

  /// HTTP status kodları geçici sunucu hatası sayılır.
  static const _retryableHttpStatuses = {429, 500, 502, 503, 504};

  SyncResultType classify(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return SyncResultType.retryableFailure;
    }
    if (error is HttpException || error is HandshakeException) {
      return SyncResultType.retryableFailure;
    }
    if (error is AuthException) {
      return SyncResultType.authRequired;
    }
    if (error is PostgrestException) {
      final status = error.code == null ? null : int.tryParse(error.code!);
      if (status != null && _retryableHttpStatuses.contains(status)) {
        return SyncResultType.retryableFailure;
      }
      // JWT süresi dolmuş / geçersiz token → oturum yenileme gerekir.
      final message = error.message.toLowerCase();
      if (message.contains('jwt') || message.contains('token')) {
        return SyncResultType.authRequired;
      }
      // Diğer Postgrest hataları (ör. kısıt ihlali) kalıcı sayılır.
      return SyncResultType.rejected;
    }
    // Bilinmeyen/belirsiz hatalar güvenli tarafta yeniden denenir; idempotency
    // sunucuda çift uygulamayı engeller (Bölüm 12).
    return SyncResultType.retryableFailure;
  }
}
