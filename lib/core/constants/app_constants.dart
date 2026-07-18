class AppConstants {
  static const appName = 'SüreTakip';

  /// Supabase yapılandırması derleme zamanında `--dart-define-from-file` ile
  /// verilir; `.env` artık asset olarak paketlenmez (bkz. README).
  static const supabaseUrlEnvKey = 'SUPABASE_URL';
  static const supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';
  static const passwordResetRedirectUrl = 'com.suretakip.app://reset-password';

  static const defaultCurrencyCode = 'TRY';
  static const defaultTimezone = 'Europe/Istanbul';

  static const minimumPasswordLength = 8;
  static const defaultRoundingIntervalMinutes = 1;
  static const defaultMinimumChargeMinutes = 0;
  static const serviceRoundingIntervalOptions = <int>[1, 5, 10, 15, 30];
  static const serviceMinimumChargeOptions = <int>[0, 5, 10, 15, 30, 60];
  static const maximumNameLength = 120;
  static const historyQueryLimit = 200;
  static const historyEarliestYear = 2020;
  static const reportRankingLimit = 5;

  static const businessesTable = 'businesses';
  static const businessMembersTable = 'business_members';
  static const customersTable = 'customers';
  static const servicesTable = 'services';
  static const productsTable = 'products';
  static const inventoryMovementsTable = 'inventory_movements';
  static const sessionsTable = 'sessions';
  static const sessionItemsTable = 'session_items';
  static const sessionTimeEntriesTable = 'session_time_entries';
  static const completeOnboardingRpc = 'complete_onboarding';
  static const createProductWithStockRpc = 'create_product_with_stock';
  static const serverNowRpc = 'server_now';
  static const startSessionRpc = 'start_session';
  static const pauseSessionRpc = 'pause_session';
  static const resumeSessionRpc = 'resume_session';
  static const addProductToSessionRpc = 'add_product_to_session';
  static const completeSessionRpc = 'complete_session';
  static const cancelSessionRpc = 'cancel_session';
  static const reportRevenueSummaryRpc = 'report_revenue_summary';
  static const reportTopServicesRpc = 'report_top_services';
  static const reportTopProductsRpc = 'report_top_products';
  static const reportTopCustomersRpc = 'report_top_customers';
  static const dashboardMetricsRpc = 'dashboard_metrics';

  /// Üyelik mutasyonları yalnızca bu RPC'lerle yapılır; business_members
  /// tablosuna doğrudan insert/update/delete yetkisi kaldırılmıştır
  /// (20260718090200). Son owner invariantı sunucu tarafında uygulanır.
  static const addBusinessMemberRpc = 'add_business_member';
  static const updateBusinessMemberRoleRpc = 'update_business_member_role';
  static const setBusinessMemberActiveRpc = 'set_business_member_active';
  static const removeBusinessMemberRpc = 'remove_business_member';
  static const transferBusinessOwnershipRpc = 'transfer_business_ownership';

  static const supportedCurrencyCodes = <String>['TRY', 'USD', 'EUR', 'GBP'];
  static const supportedTimezones = <String>[
    'Europe/Istanbul',
    'Europe/London',
    'Europe/Berlin',
    'America/New_York',
  ];
}
