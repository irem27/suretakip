import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:suretakip/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:suretakip/features/auth/domain/entities/auth_session_state.dart';
import 'package:suretakip/features/businesses/data/datasources/businesses_remote_data_source.dart';
import 'package:suretakip/features/businesses/data/local/businesses_local_data_source.dart';
import 'package:suretakip/features/businesses/data/repositories/cached_businesses_repository.dart';
import 'package:suretakip/features/customers/data/datasources/customers_remote_data_source.dart';
import 'package:suretakip/features/customers/data/repositories/customers_repository_impl.dart';
import 'package:suretakip/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:suretakip/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:suretakip/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:suretakip/features/payments/data/repositories/payments_repository_impl.dart';
import 'package:suretakip/features/products/data/datasources/products_remote_data_source.dart';
import 'package:suretakip/features/products/data/repositories/offline_products_repository.dart';
import 'package:suretakip/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:suretakip/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:suretakip/features/services/data/datasources/services_remote_data_source.dart';
import 'package:suretakip/features/services/data/repositories/offline_services_repository.dart';
import 'package:suretakip/features/sessions/data/datasources/sessions_remote_data_source.dart';
import 'package:suretakip/features/sessions/data/repositories/sessions_repository_impl.dart';

ProviderContainer _container() {
  final database = AppDatabase.forExecutor(NativeDatabase.memory());
  final client = SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    httpClient: null,
  );
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      supabaseClientProvider.overrideWithValue(client),
    ],
  );
}

void main() {
  group('app_providers wiring', () {
    late ProviderContainer container;

    setUp(() => container = _container());
    tearDown(() => container.dispose());

    test('auth katmanı provider’ları kurulur', () {
      expect(
        container.read(authRemoteDataSourceProvider),
        isA<AuthRemoteDataSource>(),
      );
      expect(container.read(authRepositoryProvider), isA<AuthRepositoryImpl>());
    });

    test('authenticatedUserIdProvider giriş yoksa null userId taşır', () async {
      container.listen(authSessionStateProvider, (_, _) {});
      await container.read(authSessionStateProvider.future);

      final auth = container.read(authenticatedUserIdProvider);

      expect(auth.hasValue, isTrue);
      expect(auth.value, isNull);
    });

    test(
      'authenticatedUserIdProvider auth akışı hata verirse hatayı taşır',
      () async {
        final containerWithError = ProviderContainer(
          overrides: [
            authSessionStateProvider.overrideWith(
              (ref) => Stream<AuthSessionState>.error(Exception('boom')),
            ),
          ],
        );
        addTearDown(containerWithError.dispose);
        final subscription = containerWithError.listen(
          authenticatedUserIdProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        await pumpEventQueue();

        final auth = containerWithError.read(authenticatedUserIdProvider);

        expect(auth.hasError, isTrue);
      },
    );

    test('işletme veri kaynağı ve önbellekli repository kurulur', () {
      expect(
        container.read(businessesLocalDataSourceProvider),
        isA<BusinessesLocalDataSource>(),
      );
      expect(
        container.read(businessesRemoteDataSourceProvider),
        isA<BusinessesRemoteDataSource>(),
      );
      expect(
        container.read(businessesRepositoryProvider),
        isA<CachedBusinessesRepository>(),
      );
    });

    test('hizmet/ürün offline repository provider’ları kurulur', () {
      expect(
        container.read(servicesRemoteDataSourceProvider),
        isA<ServicesRemoteDataSource>(),
      );
      expect(
        container.read(offlineServicesRepositoryProvider),
        isA<OfflineServicesRepository>(),
      );
      expect(container.read(servicesRepositoryProvider), isNotNull);
      expect(
        container.read(productsRemoteDataSourceProvider),
        isA<ProductsRemoteDataSource>(),
      );
      expect(
        container.read(offlineProductsRepositoryProvider),
        isA<OfflineProductsRepository>(),
      );
      expect(container.read(productsRepositoryProvider), isNotNull);
    });

    test('müşteri ve seans repository provider’ları kurulur', () {
      expect(
        container.read(customersRemoteDataSourceProvider),
        isA<CustomersRemoteDataSource>(),
      );
      expect(
        container.read(customersRepositoryProvider),
        isA<CustomersRepositoryImpl>(),
      );
      expect(
        container.read(sessionsRemoteDataSourceProvider),
        isA<SessionsRemoteDataSource>(),
      );
      expect(
        container.read(sessionsRepositoryProvider),
        isA<SessionsRepositoryImpl>(),
      );
    });

    test('ödeme repository provider’ları kurulur', () {
      expect(
        container.read(paymentsRemoteDataSourceProvider),
        isA<PaymentsRemoteDataSource>(),
      );
      expect(
        container.read(paymentsRemoteRepositoryProvider),
        isA<PaymentsRepositoryImpl>(),
      );
      expect(container.read(paymentsRepositoryProvider), isNotNull);
    });

    test('dashboard ve rapor repository provider’ları kurulur', () {
      expect(
        container.read(dashboardRemoteDataSourceProvider),
        isA<DashboardRemoteDataSource>(),
      );
      expect(
        container.read(dashboardRepositoryProvider),
        isA<DashboardRepositoryImpl>(),
      );
      expect(
        container.read(reportsRemoteDataSourceProvider),
        isA<ReportsRemoteDataSource>(),
      );
      expect(
        container.read(reportsRepositoryProvider),
        isA<ReportsRepositoryImpl>(),
      );
    });
  });
}
