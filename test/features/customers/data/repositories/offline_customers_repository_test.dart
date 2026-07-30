import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:suretakip/core/sync/outbox_repository.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/features/customers/data/datasources/customers_remote_data_source.dart';
import 'package:suretakip/features/customers/data/local/customers_local_data_source.dart';
import 'package:suretakip/features/customers/data/repositories/offline_customers_repository.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';

void main() {
  late AppDatabase db;
  late CustomersLocalDataSource local;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    local = CustomersLocalDataSource(db);
  });

  tearDown(() => db.close());

  test('offline oluşturulan müşteri Drift domain streaminde görünür', () async {
    final repository = _repository(db: db, local: local);

    final created = await repository.createCustomer(
      const CustomerInput(businessId: 'business-1', name: 'Çevrimdışı Müşteri'),
      actorUserId: 'user-1',
    );
    final customers = await repository
        .watchCustomersDomain(businessId: 'business-1', includeInactive: true)
        .firstWhere((rows) => rows.isNotEmpty);

    expect(customers.single.id, created.id);
    expect(customers.single.name, 'Çevrimdışı Müşteri');
    expect(
      (await local.findCustomer(created.id))?.syncStatus,
      SyncStatus.pending.wireName,
    );
  });

  test('pullFromServer dirty yerel kayıtları ezmez', () async {
    final now = DateTime.utc(2026, 7, 22, 9);
    const dirtyStatuses = <SyncStatus>[
      SyncStatus.localOnly,
      SyncStatus.pending,
      SyncStatus.processing,
      SyncStatus.retrying,
      SyncStatus.conflicted,
    ];
    for (final status in dirtyStatuses) {
      await db
          .into(db.localCustomers)
          .insert(
            LocalCustomersCompanion.insert(
              id: 'dirty-${status.name}',
              businessId: 'business-1',
              name: 'Yerel ${status.name}',
              syncStatus: status.wireName,
              createdAtLocal: now,
              updatedAtLocal: now,
            ),
          );
    }
    await db
        .into(db.localCustomers)
        .insert(
          LocalCustomersCompanion.insert(
            id: 'clean-synced',
            businessId: 'business-1',
            name: 'Eski Sunucu Adı',
            syncStatus: SyncStatus.synced.wireName,
            createdAtLocal: now,
            updatedAtLocal: now,
          ),
        );

    final remoteRows = <Map<String, dynamic>>[
      for (final status in dirtyStatuses)
        _remoteRow(id: 'dirty-${status.name}', name: 'Sunucu ${status.name}'),
      _remoteRow(id: 'clean-synced', name: 'Güncel Sunucu Adı'),
      _remoteRow(id: 'new-server', name: 'Yeni Sunucu Müşterisi'),
    ];
    final repository = _repository(
      db: db,
      local: local,
      remote: _FakeCustomersRemoteDataSource(remoteRows),
    );

    await repository.pullFromServer('business-1');

    for (final status in dirtyStatuses) {
      final row = await local.findCustomer('dirty-${status.name}');
      expect(row?.name, 'Yerel ${status.name}');
      expect(row?.syncStatus, status.wireName);
    }
    expect(
      (await local.findCustomer('clean-synced'))?.name,
      'Güncel Sunucu Adı',
    );
    expect(
      (await local.findCustomer('new-server'))?.syncStatus,
      SyncStatus.synced.wireName,
    );
  });
}

OfflineCustomersRepository _repository({
  required AppDatabase db,
  required CustomersLocalDataSource local,
  CustomersRemoteDataSource? remote,
}) => OfflineCustomersRepository(
  local: local,
  remote: remote ?? const _FakeCustomersRemoteDataSource([]),
  deviceIdentity: DeviceIdentity(db),
  syncEngine: SyncEngine(
    outbox: OutboxRepository(db),
    customerRpc: _NoopCustomerApi(),
    sessionRpc: _NoopSessionApi(),
    sessionGuard: _AuthRequiredGuard(),
  ),
);

Map<String, dynamic> _remoteRow({required String id, required String name}) => {
  'id': id,
  'business_id': 'business-1',
  'name': name,
  'phone': null,
  'email': null,
  'notes': null,
  'is_active': true,
  'archived_at': null,
  'server_version': 3,
  'created_at': '2026-07-20T08:00:00Z',
  'updated_at': '2026-07-22T08:00:00Z',
};

class _FakeCustomersRemoteDataSource implements CustomersRemoteDataSource {
  const _FakeCustomersRemoteDataSource(this.rows);

  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> getCustomers({
    required String businessId,
    required bool includeInactive,
  }) async => rows;

  @override
  Future<Map<String, dynamic>> createCustomer(Map<String, Object?> values) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getCustomer(String id) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> updateCustomer(
    Map<String, Object?> values, {
    DateTime? expectedUpdatedAt,
  }) => throw UnimplementedError();
}

class _AuthRequiredGuard implements SyncSessionGuard {
  @override
  Future<SyncResultType?> ensureValidSession() async =>
      SyncResultType.authRequired;
}

class _NoopCustomerApi implements CustomerSyncApi {
  @override
  Future<SyncPushResult> createCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> updateCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int expectedVersion,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> setCustomerActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String customerId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);
}

class _NoopSessionApi implements SessionSyncApi {
  @override
  Future<SyncPushResult> startSession({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> session,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> sessionEvent({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> event,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);
}
