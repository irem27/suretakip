import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/core/logging/app_logger_provider.dart';
import 'package:suretakip/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:suretakip/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:suretakip/features/auth/domain/repositories/auth_repository.dart';
import 'package:suretakip/features/businesses/data/datasources/businesses_remote_data_source.dart';
import 'package:suretakip/features/businesses/data/repositories/businesses_repository_impl.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/repositories/businesses_repository.dart';
import 'package:suretakip/features/customers/data/datasources/customers_remote_data_source.dart';
import 'package:suretakip/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:suretakip/features/customers/domain/repositories/customers_repository.dart';
import 'package:suretakip/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:suretakip/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:suretakip/features/dashboard/domain/repositories/dashboard_repository.dart';
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

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final authenticatedUserIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthenticatedUserId();
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authenticatedUserIdProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

final businessesRemoteDataSourceProvider = Provider<BusinessesRemoteDataSource>(
  (ref) => BusinessesRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final businessesRepositoryProvider = Provider<BusinessesRepository>((ref) {
  return BusinessesRepositoryImpl(
    ref.watch(businessesRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final userBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final userId = await ref.watch(authenticatedUserIdProvider.future);
  if (userId == null) return const [];
  return ref.watch(businessesRepositoryProvider).getBusinesses();
});

final activeBusinessProvider = Provider<Business?>((ref) {
  final businesses = ref.watch(userBusinessesProvider).valueOrNull;
  return businesses == null || businesses.isEmpty ? null : businesses.first;
});

final servicesRemoteDataSourceProvider = Provider<ServicesRemoteDataSource>(
  (ref) => ServicesRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final servicesRepositoryProvider = Provider<ServicesRepository>((ref) {
  return ServicesRepositoryImpl(
    ref.watch(servicesRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final productsRemoteDataSourceProvider = Provider<ProductsRemoteDataSource>(
  (ref) => ProductsRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepositoryImpl(
    ref.watch(productsRemoteDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

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
