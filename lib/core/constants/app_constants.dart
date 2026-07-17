class AppConstants {
  static const appName = 'SüreTakip';

  /// Supabase yapılandırması derleme zamanında `--dart-define-from-file` ile
  /// verilir; `.env` artık asset olarak paketlenmez (bkz. README).
  static const supabaseUrlEnvKey = 'SUPABASE_URL';
  static const supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';

  static const defaultCurrencyCode = 'TRY';
  static const defaultTimezone = 'Europe/Istanbul';
}
