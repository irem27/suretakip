import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/sync/customer_delta_store.dart';
import 'package:suretakip/core/sync/customer_delta_sync_service.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/offline_bootstrap.dart';
import 'package:suretakip/core/sync/outbox_repository.dart';
import 'package:suretakip/core/sync/session_snapshot_sync_service.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/core/sync/sync_pull_rpc.dart';
import 'package:suretakip/features/customers/data/local/customers_local_data_source.dart';
import 'package:suretakip/features/customers/data/repositories/offline_customers_repository.dart';
import 'package:suretakip/features/payments/data/repositories/offline_payments_repository.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/data/repositories/offline_sessions_repository.dart';

ProviderContainer _container() {
  final database = AppDatabase.forExecutor(NativeDatabase.memory());
  final client = SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    httpClient: null,
  );
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      supabaseClientProvider.overrideWithValue(client),
    ],
  );
  return container;
}

void main() {
  group('sync_providers wiring', () {
    late ProviderContainer container;

    setUp(() => container = _container());
    tearDown(() => container.dispose());

    test('yerel veri kaynağı ve outbox provider’ları kurulur', () {
      expect(
        container.read(customersLocalDataSourceProvider),
        isA<CustomersLocalDataSource>(),
      );
      expect(
        container.read(sessionsLocalDataSourceProvider),
        isA<SessionsLocalDataSource>(),
      );
      expect(container.read(outboxRepositoryProvider), isA<OutboxRepository>());
      expect(container.read(deviceIdentityProvider), isA<DeviceIdentity>());
    });

    test('sync RPC provider’ları supabase istemcisiyle kurulur', () {
      expect(container.read(customerSyncApiProvider), isNotNull);
      expect(container.read(sessionSyncApiProvider), isNotNull);
      expect(container.read(productSyncApiProvider), isNotNull);
      expect(container.read(serviceSyncApiProvider), isNotNull);
      expect(container.read(paymentSyncApiProvider), isNotNull);
      expect(container.read(syncPullApiProvider), isA<SyncPullRpc>());
    });

    test('connectivityProvider bir Connectivity örneği döndürür', () {
      expect(container.read(connectivityProvider), isA<Connectivity>());
    });

    test(
      'syncEngineProvider kurulur ve oturumsuz push authRequired döner',
      () async {
        final engine = container.read(syncEngineProvider);
        expect(engine, isA<SyncEngine>());

        final summary = await engine.push();

        expect(summary.authRequired, isTrue);
        expect(summary.pushed, 0);
      },
    );

    test('delta/snapshot senkron servisleri kurulur', () {
      expect(
        container.read(customerDeltaStoreProvider),
        isA<CustomerDeltaStore>(),
      );
      expect(
        container.read(customerDeltaSyncServiceProvider),
        isA<CustomerDeltaSyncService>(),
      );
      expect(
        container.read(sessionSnapshotSyncServiceProvider),
        isA<SessionSnapshotSyncService>(),
      );
      expect(container.read(offlineBootstrapProvider), isA<OfflineBootstrap>());
    });

    test('offline repository provider’ları kurulur', () {
      expect(
        container.read(offlineCustomersRepositoryProvider),
        isA<OfflineCustomersRepository>(),
      );
      expect(
        container.read(offlineSessionsRepositoryProvider),
        isA<OfflineSessionsRepository>(),
      );
      expect(
        container.read(offlinePaymentsRepositoryProvider),
        isA<OfflinePaymentsRepository>(),
      );
    });
  });
}
