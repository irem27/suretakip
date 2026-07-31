import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/logging/app_logger_provider.dart';
import 'package:suretakip/features/businesses/data/local/businesses_local_data_source.dart';
import 'package:suretakip/features/businesses/data/repositories/cached_businesses_repository.dart';
import 'package:suretakip/features/products/data/local/products_local_data_source.dart';
import 'package:suretakip/features/products/data/repositories/offline_products_repository.dart';
import 'package:suretakip/features/services/data/local/services_local_data_source.dart';
import 'package:suretakip/features/services/data/repositories/offline_services_repository.dart';
import 'package:suretakip/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:suretakip/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';
import 'package:suretakip/features/auth/domain/repositories/auth_repository.dart';
import 'package:suretakip/features/businesses/data/datasources/businesses_remote_data_source.dart';
import 'package:suretakip/features/businesses/data/repositories/businesses_repository_impl.dart';
import 'package:suretakip/features/businesses/domain/entities/business_capabilities.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
import 'package:suretakip/features/businesses/domain/repositories/businesses_repository.dart';
import 'package:suretakip/features/customers/data/datasources/customers_remote_data_source.dart';
import 'package:suretakip/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';
import 'package:suretakip/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:suretakip/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:suretakip/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:suretakip/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:suretakip/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:suretakip/features/payments/domain/repositories/payments_repository.dart';
import 'package:suretakip/features/products/data/datasources/products_remote_data_source.dart';
import 'package:suretakip/features/products/data/repositories/products_repository_impl.dart';
import 'package:suretakip/features/products/domain/repositories/products_repository.dart';
import 'package:suretakip/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:suretakip/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:suretakip/features/reports/domain/repositories/reports_repository.dart';
import 'package:suretakip/features/services/data/datasources/services_remote_data_source.dart';
import 'package:suretakip/features/services/data/repositories/services_repository_impl.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';
import 'package:suretakip/features/sessions/data/datasources/sessions_remote_data_source.dart';
import 'package:suretakip/features/sessions/data/repositories/sessions_repository_impl.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';

export 'package:suretakip/core/logging/app_logger_provider.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Uygulama ömrü boyunca tek Drift veritabanı örneği (tek writer). Offline
/// önbellek ve sync katmanı bunu paylaşır.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final businessesLocalDataSourceProvider = Provider<BusinessesLocalDataSource>(
  (ref) => BusinessesLocalDataSource(ref.watch(appDatabaseProvider)),
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final authSessionStateProvider = StreamProvider<AuthSessionState>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthState();
});

final authenticatedUserIdProvider = Provider<AsyncValue<String?>>((ref) {
  return ref.watch(authSessionStateProvider).whenData((state) => state.userId);
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authenticatedUserIdProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

final businessesRemoteDataSourceProvider = Provider<BusinessesRemoteDataSource>(
  (ref) => BusinessesRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final businessesRepositoryProvider = Provider<BusinessesRepository>((ref) {
  // Read-through önbellek: internetsiz açılışta son senkronlanan işletme +
  // rol yerelden okunur; çevrimiçiyken sunucu otoriterdir ve önbellek tazelenir.
  return CachedBusinessesRepository(
    remote: BusinessesRepositoryImpl(
      ref.watch(businessesRemoteDataSourceProvider),
      logger: ref.watch(appLoggerProvider),
    ),
    local: ref.watch(businessesLocalDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final userBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final authState = await ref.watch(authSessionStateProvider.future);
  final userId = authState.userId;
  if (userId == null) return const [];
  return ref.watch(businessesRepositoryProvider).getBusinesses();
});

class SelectedBusinessIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.listen(userBusinessesProvider, (_, next) {
      if (!next.hasValue || state == null) return;
      final activeBusinesses = next.requireValue.where(
        (business) => business.isActive,
      );
      if (!activeBusinesses.any((business) => business.id == state)) {
        state = null;
      }
    });
    return null;
  }

  void selectBusiness(String? businessId) {
    if (businessId == null) {
      state = null;
      return;
    }
    final businesses = ref.read(userBusinessesProvider).valueOrNull;
    final isActiveMembership =
        businesses?.any(
          (business) => business.isActive && business.id == businessId,
        ) ??
        false;
    state = isActiveMembership ? businessId : null;
  }
}

final selectedBusinessIdProvider =
    NotifierProvider<SelectedBusinessIdNotifier, String?>(
      SelectedBusinessIdNotifier.new,
    );

final activeBusinessProvider = Provider<Business?>((ref) {
  final businesses = ref.watch(userBusinessesProvider).valueOrNull;
  if (businesses == null) return null;
  final activeBusinesses = businesses
      .where((business) => business.isActive)
      .toList(growable: false);
  if (activeBusinesses.isEmpty) return null;

  final selectedId = ref.watch(selectedBusinessIdProvider);
  for (final business in activeBusinesses) {
    if (business.id == selectedId) return business;
  }
  return activeBusinesses.first;
});

typedef BusinessScope = ({String? businessId, int generation});

class BusinessScopeGenerationNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void advance() => state++;
}

final businessScopeGenerationProvider =
    NotifierProvider<BusinessScopeGenerationNotifier, int>(
      BusinessScopeGenerationNotifier.new,
    );

final activeBusinessScopeProvider = Provider<BusinessScope>((ref) {
  return (
    businessId: ref.watch(activeBusinessProvider)?.id,
    generation: ref.watch(businessScopeGenerationProvider),
  );
});

final currentMemberProvider = FutureProvider.autoDispose
    .family<BusinessMember?, BusinessScope>((ref, scope) async {
      await ref.watch(userBusinessesProvider.future);
      final authenticatedUserId = ref.watch(authenticatedUserIdProvider);
      final userId = await authenticatedUserId.when(
        data: Future.value,
        loading: () async =>
            (await ref.watch(authSessionStateProvider.future)).userId,
        error: Future.error,
      );
      final businessId = scope.businessId;
      if (businessId == null || userId == null) return null;

      final members = await ref
          .watch(businessesRepositoryProvider)
          .getMembers(businessId);
      for (final member in members) {
        if (member.businessId == businessId &&
            member.userId == userId &&
            member.isActive) {
          return member;
        }
      }
      return null;
    });

final businessCapabilitiesProvider = Provider<AsyncValue<BusinessCapabilities>>(
  (ref) {
    final scope = ref.watch(activeBusinessScopeProvider);
    return ref
        .watch(currentMemberProvider(scope))
        .whenData((member) => BusinessCapabilities.forRole(member?.role));
  },
);

final servicesRemoteDataSourceProvider = Provider<ServicesRemoteDataSource>(
  (ref) => ServicesRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final servicesLocalDataSourceProvider = Provider<ServicesLocalDataSource>(
  (ref) => ServicesLocalDataSource(ref.watch(appDatabaseProvider)),
);

// Offline-first (Sprint 1, müşteri deseniyle birebir aynı): write yolu her
// zaman yerel + outbox'tan geçer, `remote` yalnız önbellek boşken/tazeleme
// için kullanılır. Bu tanım kasıtlı olarak `sync_providers.dart`'taki
// `syncEngineProvider`/`deviceIdentityProvider`'ı paylaşır (dosyalar arası
// döngüsel import Dart'ta geçerlidir; her iki taraf da yalnız lazy Provider
// closure'ları içerir).
// Concrete offline repo (pullFromServer gibi offline'a özel metotlar için).
final offlineServicesRepositoryProvider = Provider<OfflineServicesRepository>((
  ref,
) {
  return OfflineServicesRepository(
    local: ref.watch(servicesLocalDataSourceProvider),
    remote: ServicesRepositoryImpl(
      ref.watch(servicesRemoteDataSourceProvider),
      logger: ref.watch(appLoggerProvider),
    ),
    deviceIdentity: ref.watch(deviceIdentityProvider),
    syncEngine: ref.watch(syncEngineProvider),
    currentActorUserId: () =>
        ref.read(supabaseClientProvider).auth.currentUser?.id,
    logger: ref.watch(appLoggerProvider),
  );
});

final servicesRepositoryProvider = Provider<ServicesRepository>(
  (ref) => ref.watch(offlineServicesRepositoryProvider),
);

final productsRemoteDataSourceProvider = Provider<ProductsRemoteDataSource>(
  (ref) => ProductsRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final productsLocalDataSourceProvider = Provider<ProductsLocalDataSource>(
  (ref) => ProductsLocalDataSource(ref.watch(appDatabaseProvider)),
);

final offlineProductsRepositoryProvider = Provider<OfflineProductsRepository>((
  ref,
) {
  return OfflineProductsRepository(
    local: ref.watch(productsLocalDataSourceProvider),
    remote: ProductsRepositoryImpl(
      ref.watch(productsRemoteDataSourceProvider),
      logger: ref.watch(appLoggerProvider),
    ),
    deviceIdentity: ref.watch(deviceIdentityProvider),
    syncEngine: ref.watch(syncEngineProvider),
    currentActorUserId: () =>
        ref.read(supabaseClientProvider).auth.currentUser?.id,
    logger: ref.watch(appLoggerProvider),
  );
});

final productsRepositoryProvider = Provider<ProductsRepository>(
  (ref) => ref.watch(offlineProductsRepositoryProvider),
);

final customersRemoteDataSourceProvider = Provider<CustomersRemoteDataSource>(
  (ref) => CustomersRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepositoryImpl(
    ref.watch(customersRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final sessionsRemoteDataSourceProvider = Provider<SessionsRemoteDataSource>(
  (ref) => SessionsRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  return SessionsRepositoryImpl(
    ref.watch(sessionsRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final paymentsRemoteDataSourceProvider = Provider<PaymentsRemoteDataSource>(
  (ref) => PaymentsRemoteDataSource(ref.watch(supabaseClientProvider)),
);

/// Sunucu-otoriteli çevrimiçi uygulama (`record_session_payment` RPC'sini
/// doğrudan çağırır). Offline-first kararı için bkz.
/// `OfflinePaymentsRepository` dosya başı açıklaması.
final paymentsRemoteRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepositoryImpl(
    ref.watch(paymentsRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

/// Müşteri/ürün/seans ile aynı "drop-in" fikri: controller/UI bu sözleşmeyi
/// (interface) hiç değiştirmeden çevrimdışı yazma yoluna geçer. Yalnız
/// `recordSessionPayment` cihazda kuyruğa alınabilir; okuma + void/iade
/// sunucu-otoriteli kalır (bkz. `sync_providers.dart` ->
/// `offlinePaymentsRepositoryProvider`).
final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return ref.watch(offlinePaymentsRepositoryProvider);
});

final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>(
  (ref) => DashboardRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    ref.watch(dashboardRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final reportsRemoteDataSourceProvider = Provider<ReportsRemoteDataSource>(
  (ref) => ReportsRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepositoryImpl(
    ref.watch(reportsRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});
