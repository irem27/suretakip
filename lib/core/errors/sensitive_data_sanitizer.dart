abstract final class SensitiveDataSanitizer {
  static String sanitize(Object value) {
    final raw = value.toString();
    if (_containsPostgresDetails(raw)) {
      return '${value.runtimeType}: [VERİTABANI AYRINTISI MASKELENDİ]';
    }

    return _patterns.fold(raw, (text, pattern) {
      return text.replaceAll(pattern, '[MASKELENDİ]');
    });
  }

  static String? sanitizePostgresCode(String? code) {
    final normalized = code?.trim().toUpperCase();
    if (normalized == null || !_safePostgresCode.hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }

  static SanitizedErrorDetails sanitizedCause({
    String message = 'İşlem hata ayrıntısı maskelendi.',
  }) => SanitizedErrorDetails(message);

  static bool _containsPostgresDetails(String value) =>
      _postgresDetails.hasMatch(value);

  static final _patterns = <RegExp>[
    RegExp(r'Bearer\s+\S+', caseSensitive: false),
    RegExp(
      r'eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}'
      r'(?:\.[A-Za-z0-9_-]{5,})?',
    ),
    RegExp(
      r'\b(?:access[_-]?token|refresh[_-]?token|token|jwt|api[_-]?key|'
      r'authorization|password|parola|sifre|şifre)["\x27]?\s*'
      r'(?:[=:]\s*|\s+)(?:"[^"]*"|\x27[^\x27]*\x27|[^\s,}\]]+)',
      caseSensitive: false,
    ),
    RegExp(r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', caseSensitive: false),
    RegExp(
      r'(?<!\d)(?:\+?90[\s-]*)?(?:\(0?5\d{2}\)|0?5\d{2})'
      r'(?:[\s().-]*\d){7}(?!\d)',
    ),
  ];

  static final _postgresDetails = RegExp(
    r'postgrestexception|postgres(?:ql)?|sqlstate|duplicate key value|'
    r'violates\s+.+\s+constraint|\bdetail\s*:|\brelation\s+["\x27]|'
    r'\bcolumn\s+["\x27]',
    caseSensitive: false,
  );

  static final _safePostgresCode = RegExp(
    r'^(?:[0-9A-Z]{5}|PGRST[0-9]{3}|[1-5][0-9]{2})$',
  );
}

final class SanitizedErrorDetails implements Exception {
  const SanitizedErrorDetails(this.message);

  final String message;

  @override
  String toString() => message;
}
