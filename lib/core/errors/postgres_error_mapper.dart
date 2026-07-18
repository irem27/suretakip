import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/errors/sensitive_data_sanitizer.dart';

abstract final class PostgresErrorMapper {
  static DomainException map({
    required String message,
    String? code,
    Object? cause,
  }) => _mapSanitized(
    message: message,
    code: SensitiveDataSanitizer.sanitizePostgresCode(code),
    cause: cause == null
        ? null
        : SensitiveDataSanitizer.sanitizedCause(
            message: 'Veritabanı hata ayrıntısı maskelendi.',
          ),
  );

  static DomainException _mapSanitized({
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
      // Tam eşleşme ya da token-sınırlı eşleşme; çıplak substring değil.
      // Böylece rastgele bir Postgres mesajında geçen bir kelime parçası
      // yanlışlıkla iş-hatası koduna eşlenmez.
      if (normalized == key || _containsToken(normalized, key)) return key;
    }
    return normalized;
  }

  static bool _containsToken(String haystack, String token) {
    var index = haystack.indexOf(token);
    while (index != -1) {
      final beforeOk = index == 0 || !_isWordChar(haystack[index - 1]);
      final after = index + token.length;
      final afterOk = after == haystack.length || !_isWordChar(haystack[after]);
      if (beforeOk && afterOk) return true;
      index = haystack.indexOf(token, index + 1);
    }
    return false;
  }

  static bool _isWordChar(String char) {
    final code = char.codeUnitAt(0);
    final isDigit = code >= 0x30 && code <= 0x39;
    final isLower = code >= 0x61 && code <= 0x7a;
    return isDigit || isLower || char == '_';
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
        'service_name_required' => ValidationException(
          'Hizmet adı boş bırakılamaz.',
          code: key,
          cause: cause,
        ),
        'product_name_required' => ValidationException(
          'Ürün adı boş bırakılamaz.',
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
        // ---- Üyelik yönetimi (20260718090200) ----
        'last_owner_protected' => ConflictException(
          'İşletmede en az bir aktif sahip kalmalıdır. Önce sahipliği '
          'başka bir üyeye devredin.',
          code: key,
          cause: cause,
        ),
        'member_not_found' => NotFoundException(
          'Üye kaydı bulunamadı.',
          code: key,
          cause: cause,
        ),
        'member_already_exists' => ConflictException(
          'Bu kullanıcı zaten işletmenin üyesi. Pasif üyeyi yeniden '
          'aktifleştirebilirsiniz.',
          code: key,
          cause: cause,
        ),
        'member_has_history' => ConflictException(
          'Bu üyenin işlem geçmişi olduğu için silinemez. Bunun yerine '
          'pasifleştirin.',
          code: key,
          cause: cause,
        ),
        'target_member_inactive' => ConflictException(
          'Sahiplik yalnızca aktif bir üyeye devredilebilir.',
          code: key,
          cause: cause,
        ),
        'cannot_transfer_to_self' => ValidationException(
          'Sahipliği kendinize devredemezsiniz.',
          code: key,
          cause: cause,
        ),
        'user_not_found' => NotFoundException(
          'Kullanıcı bulunamadı.',
          code: key,
          cause: cause,
        ),
        'user_id_required' => ValidationException(
          'Kullanıcı seçilmeden üye eklenemez.',
          code: key,
          cause: cause,
        ),
        // Savunma amaçlı: bu hatanın istemciye ulaşması, stok cache'ine
        // ledger dışından yazma denendiği anlamına gelir (20260718090000).
        'stock_quantity_direct_write_denied' => AuthorizationException(
          'Stok yalnızca stok hareketleriyle değiştirilebilir.',
          code: key,
          cause: cause,
        ),
        _ => null,
      };

  static const _rpcErrorKeys = <String>{
    'authentication_required',
    'business_name_required',
    'service_name_required',
    'product_name_required',
    'business_not_active',
    'cannot_transfer_to_self',
    'currency_mismatch',
    'customer_not_found',
    'insufficient_stock',
    'invalid_amount',
    'invalid_discount',
    'invalid_quantity',
    'last_owner_protected',
    'member_already_exists',
    'member_has_history',
    'member_not_found',
    'not_a_member',
    'not_authorized',
    'product_not_available',
    'service_not_available',
    'session_already_cancelled',
    'session_not_active',
    'session_not_found',
    'session_not_open',
    'session_not_paused',
    'stock_quantity_direct_write_denied',
    'target_member_inactive',
    'user_id_required',
    'user_not_found',
  };
}
