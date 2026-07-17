import 'package:suretakip/core/errors/domain_exception.dart';

abstract final class PostgresErrorMapper {
  static DomainException map({
    required String message,
    String? code,
    Object? cause,
  }) {
    final errorKey = _extractErrorKey(message);
    final rpcException = _mapRpcError(errorKey, cause);
    if (rpcException != null) return rpcException;

    return switch (code) {
      '401' || 'PGRST301' => AuthenticationException(
        'Oturumunuz geçersiz veya süresi dolmuş.',
        code: code,
        cause: cause,
      ),
      '403' || '42501' => AuthorizationException(
        'Bu işlem için yetkiniz bulunmuyor.',
        code: code,
        cause: cause,
      ),
      'PGRST116' => NotFoundException(
        'Aradığınız kayıt bulunamadı.',
        code: code,
        cause: cause,
      ),
      '23505' => ConflictException(
        'Bu bilgilerle eşleşen bir kayıt zaten var.',
        code: code,
        cause: cause,
      ),
      '23503' || '23514' || '22023' => ValidationException(
        'Girilen bilgiler veritabanı kurallarıyla uyuşmuyor.',
        code: code,
        cause: cause,
      ),
      _ => DatabaseException(
        'Veritabanı işlemi tamamlanamadı. Lütfen tekrar deneyin.',
        code: code,
        cause: cause,
      ),
    };
  }

  static String _extractErrorKey(String message) {
    final normalized = message.trim().toLowerCase();
    for (final key in _rpcErrorKeys) {
      if (normalized == key || normalized.contains(key)) return key;
    }
    return normalized;
  }

  static DomainException? _mapRpcError(String key, Object? cause) =>
      switch (key) {
        'authentication_required' => AuthenticationException(
          'Bu işlem için giriş yapmanız gerekiyor.',
          code: key,
          cause: cause,
        ),
        'not_a_member' => AuthorizationException(
          'Bu işletmenin aktif bir üyesi değilsiniz.',
          code: key,
          cause: cause,
        ),
        'not_authorized' => AuthorizationException(
          'Bu işlemi yapmaya yetkiniz bulunmuyor.',
          code: key,
          cause: cause,
        ),
        'business_name_required' => ValidationException(
          'İşletme adı boş bırakılamaz.',
          code: key,
          cause: cause,
        ),
        'invalid_quantity' => ValidationException(
          'Ürün adedi sıfırdan büyük olmalıdır.',
          code: key,
          cause: cause,
        ),
        'invalid_amount' => ValidationException(
          'Tutarlar negatif olamaz.',
          code: key,
          cause: cause,
        ),
        'invalid_discount' => ValidationException(
          'İndirim toplam tutardan büyük olamaz.',
          code: key,
          cause: cause,
        ),
        'currency_mismatch' => ValidationException(
          'Ürün ile işlem aynı para biriminde olmalıdır.',
          code: key,
          cause: cause,
        ),
        'customer_not_found' => NotFoundException(
          'Müşteri bulunamadı veya aktif değil.',
          code: key,
          cause: cause,
        ),
        'session_not_found' => NotFoundException(
          'İşlem kaydı bulunamadı.',
          code: key,
          cause: cause,
        ),
        'service_not_available' => NotFoundException(
          'Hizmet bulunamadı veya kullanıma açık değil.',
          code: key,
          cause: cause,
        ),
        'product_not_available' => NotFoundException(
          'Ürün bulunamadı veya satışa açık değil.',
          code: key,
          cause: cause,
        ),
        'business_not_active' => ConflictException(
          'İşletme aktif olmadığı için işlem başlatılamıyor.',
          code: key,
          cause: cause,
        ),
        'insufficient_stock' => ConflictException(
          'Bu ürün için yeterli stok bulunmuyor.',
          code: key,
          cause: cause,
        ),
        'session_not_active' => ConflictException(
          'Yalnızca aktif bir işlem duraklatılabilir.',
          code: key,
          cause: cause,
        ),
        'session_not_paused' => ConflictException(
          'Yalnızca duraklatılmış bir işleme devam edilebilir.',
          code: key,
          cause: cause,
        ),
        'session_not_open' => ConflictException(
          'Bu işlem artık değişikliğe açık değil.',
          code: key,
          cause: cause,
        ),
        'session_already_cancelled' => ConflictException(
          'Bu işlem daha önce iptal edilmiş.',
          code: key,
          cause: cause,
        ),
        'already_completed' => ConflictException(
          'Bu işlem daha önce tamamlanmış.',
          code: key,
          cause: cause,
        ),
        _ => null,
      };

  static const _rpcErrorKeys = <String>{
    'authentication_required',
    'business_name_required',
    'business_not_active',
    'currency_mismatch',
    'customer_not_found',
    'insufficient_stock',
    'invalid_amount',
    'invalid_discount',
    'invalid_quantity',
    'not_a_member',
    'not_authorized',
    'product_not_available',
    'service_not_available',
    'session_already_cancelled',
    'session_not_active',
    'session_not_found',
    'session_not_open',
    'session_not_paused',
    'already_completed',
  };
}
