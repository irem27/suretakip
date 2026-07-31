import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/outbox_repository.dart';
import 'package:suretakip/core/sync/customer_delta_store.dart';
import 'package:suretakip/core/sync/customer_delta_sync_service.dart';
import 'package:suretakip/core/sync/offline_bootstrap.dart';
import 'package:suretakip/core/sync/payment_sync_rpc.dart';
import 'package:suretakip/core/sync/product_sync_rpc.dart';
import 'package:suretakip/core/sync/service_sync_rpc.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/core/sync/session_snapshot_sync_service.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/core/sync/sync_pull_rpc.dart';
import 'package:suretakip/core/sync/sync_trigger_service.dart';
import 'package:suretakip/features/customers/data/local/customers_local_data_source.dart';
import 'package:suretakip/features/customers/data/repositories/offline_customers_repository.dart';
import 'package:suretakip/features/payments/data/repositories/offline_payments_repository.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/data/repositories/offline_sessions_repository.dart';

// appDatabaseProvider artık app_providers.dart'ta tanımlı (offline önbellek de
// aynı Drift örneğini paylaşıyor); geriye dönük import uyumu için re-export.
export 'package:suretakip/app/providers/app_providers.dart'
    show appDatabaseProvider;

final customersLocalDataSourceProvider = Provider<CustomersLocalDataSource>(
  (ref) => CustomersLocalDataSource(ref.watch(appDatabaseProvider)),
);

final outboxRepositoryProvider = Provider<OutboxRepository>(
  (ref) => OutboxRepository(ref.watch(appDatabaseProvider)),
);

final deviceIdentityProvider = Provider<DeviceIdentity>(
  (ref) => DeviceIdentity(ref.watch(appDatabaseProvider)),
);

final customerSyncApiProvider = Provider<CustomerSyncApi>(
  (ref) => CustomerSyncRpc(ref.watch(supabaseClientProvider)),
);

final sessionSyncApiProvider = Provider<SessionSyncApi>(
  (ref) => SessionSyncRpc(ref.watch(supabaseClientProvider)),
);

final productSyncApiProvider = Provider<ProductSyncApi>(
  (ref) => ProductSyncRpc(ref.watch(supabaseClientProvider)),
);

final serviceSyncApiProvider = Provider<ServiceSyncApi>(
  (ref) => ServiceSyncRpc(ref.watch(supabaseClientProvider)),
);

final paymentSyncApiProvider = Provider<PaymentSyncApi>(
  (ref) => PaymentSyncRpc(ref.watch(supabaseClientProvider)),
);

// productsLocalDataSourceProvider ve servicesLocalDataSourceProvider zaten
// app_providers.dart'ta tanımlı (CachedProducts/ServicesRepository ile
// paylaşılır); burada yeniden tanımlanmaz, doğrudan kullanılır.

final sessionsLocalDataSourceProvider = Provider<SessionsLocalDataSource>(
  (ref) => SessionsLocalDataSource(ref.watch(appDatabaseProvider)),
);

final syncSessionGuardProvider = Provider<SyncSessionGuard>(
  (ref) => SupabaseSessionGuard(ref.watch(supabaseClientProvider)),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(
    outbox: ref.watch(outboxRepositoryProvider),
    customerRpc: ref.watch(customerSyncApiProvider),
    sessionRpc: ref.watch(sessionSyncApiProvider),
    // TEMBEL: yalnız ürün/hizmet outbox operasyonu dispatch edilirken
    // çağrılır; müşteri/seans akışlarında `productSyncApiProvider`/
    // `serviceSyncApiProvider` (ve `supabaseClientProvider`) hiç tetiklenmez.
    productRpc: () => ref.read(productSyncApiProvider),
    serviceRpc: () => ref.read(serviceSyncApiProvider),
    // Aynı TEMBEL gerekçe: yalnız `recordSessionPayment` outbox operasyonu
    // dispatch edilirken çağrılır.
    paymentRpc: () => ref.read(paymentSyncApiProvider),
    sessionGuard: ref.watch(syncSessionGuardProvider),
    // Yalnız oturumdaki kullanıcının kendi işletmesindeki outbox kayıtları
    // gönderilir (ortak cihaz izolasyonu, Bölüm 16.2).
    currentActorUserId: () =>
        ref.read(supabaseClientProvider).auth.currentUser?.id,
    currentBusinessId: () => ref.read(activeBusinessProvider)?.id,
    logger: ref.watch(appLoggerProvider),
  ),
);

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final syncPullApiProvider = Provider<SyncPullApi>(
  (ref) => SyncPullRpc(ref.watch(supabaseClientProvider)),
);

final customerDeltaStoreProvider = Provider<CustomerDeltaStore>(
  (ref) => CustomerDeltaStore(
    ref.watch(appDatabaseProvider),
    ref.watch(customersLocalDataSourceProvider),
  ),
);

final customerDeltaSyncServiceProvider = Provider<CustomerDeltaSyncService>(
  (ref) => CustomerDeltaSyncService(
    pull: ref.watch(syncPullApiProvider),
    store: ref.watch(customerDeltaStoreProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final sessionSnapshotSyncServiceProvider = Provider<SessionSnapshotSyncService>(
  (ref) => SessionSnapshotSyncService(
    repository: ref.watch(sessionsRepositoryProvider),
    local: ref.watch(sessionsLocalDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

/// Tek tur tam senkron: önce outbox push, sonra delta pull (Bölüm 10, adım 15).
Future<void> _runFullSync(Ref ref) async {
  await ref.read(syncEngineProvider).push();
  final businessId = ref.read(activeBusinessProvider)?.id;
  if (businessId != null) {
    await ref.read(customerDeltaSyncServiceProvider).sync(businessId);
    await ref.read(sessionSnapshotSyncServiceProvider).sync(businessId);
    // Bağlantı geri geldiğinde/foreground'da hizmet+ürün kataloglarını da
    // yerele ısıt ki sonraki çevrimdışı dönemde her fonksiyon çalışsın.
    await ref.read(offlineBootstrapProvider).warm(businessId);
  }
}

final syncTriggerServiceProvider = Provider<SyncTriggerService>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  final service = SyncTriggerService(
    connectivityChanges: connectivity.onConnectivityChanged,
    initialConnectivity: connectivity.checkConnectivity,
    push: () => _runFullSync(ref),
    logger: ref.watch(appLoggerProvider),
  );
  service.start();
  ref.listen(activeBusinessProvider, (previous, next) {
    if (next != null && previous?.id != next.id) {
      unawaited(service.trigger());
    }
  });
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// Yalnız yapıcı; kanonik ilk veri çekimi provider construction'da YAN ETKİ
/// olarak yapılmaz (Phase 6). Bootstrap/delta, `syncTriggerServiceProvider`
/// üzerinden açılış/foreground/bağlantı tetikleriyle tek kanonik akışta çalışır.
final offlineCustomersRepositoryProvider = Provider<OfflineCustomersRepository>(
  (ref) => OfflineCustomersRepository(
    local: ref.watch(customersLocalDataSourceProvider),
    remote: ref.watch(customersRemoteDataSourceProvider),
    deviceIdentity: ref.watch(deviceIdentityProvider),
    syncEngine: ref.watch(syncEngineProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

// offlineProductsRepositoryProvider/offlineServicesRepositoryProvider ayrıca
// TANIMLANMAZ: `productsRepositoryProvider`/`servicesRepositoryProvider`
// (app_providers.dart) artık doğrudan OfflineProductsRepository/
// OfflineServicesRepository döndürür — müşteri/seans ile aynı iskelet,
// tek fark: mevcut controller/UI katmanını değiştirmemek için repository
// SÖZLEŞMESİ (interface) korunarak "drop-in" bağlanmıştır.

final offlineSessionsRepositoryProvider = Provider<OfflineSessionsRepository>(
  (ref) => OfflineSessionsRepository(
    db: ref.watch(appDatabaseProvider),
    local: ref.watch(sessionsLocalDataSourceProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    deviceIdentity: ref.watch(deviceIdentityProvider),
    syncEngine: ref.watch(syncEngineProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

/// `paymentsRepositoryProvider` (payments_controller.dart) bu depoyu
/// döndürür — müşteri/ürün/seans ile aynı "drop-in" fikri, tek fark:
/// yalnız `recordSessionPayment` çevrimdışı kuyruğa alınır (bkz.
/// `OfflinePaymentsRepository` dosya başı açıklaması).
final offlinePaymentsRepositoryProvider = Provider<OfflinePaymentsRepository>(
  (ref) => OfflinePaymentsRepository(
    remote: ref.watch(paymentsRemoteRepositoryProvider),
    db: ref.watch(appDatabaseProvider),
    sessionsLocal: ref.watch(sessionsLocalDataSourceProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    deviceIdentity: ref.watch(deviceIdentityProvider),
    syncEngine: ref.watch(syncEngineProvider),
    currentActorUserId: () =>
        ref.read(supabaseClientProvider).auth.currentUser?.id,
    logger: ref.watch(appLoggerProvider),
  ),
);
