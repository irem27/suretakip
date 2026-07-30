import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:suretakip/core/sync/outbox_repository.dart';
import 'package:suretakip/core/sync/product_sync_rpc.dart';
import 'package:suretakip/core/sync/retry_policy.dart';
import 'package:suretakip/core/sync/service_sync_rpc.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/services/data/local/services_local_data_source.dart';
import 'package:suretakip/features/services/data/repositories/offline_services_repository.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/entities/service_input.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';

class _FakeServiceApi implements ServiceSyncApi {
  _FakeServiceApi(this.behaviors);

  final List<FutureOr<SyncPushResult> Function()> behaviors;
  final calls = <Map<String, Object?>>[];
  var _index = 0;

  SyncPushResult _next() {
    final behavior = behaviors[_index.clamp(0, behaviors.length - 1)];
    _index++;
    return behavior() as SyncPushResult;
  }

  @override
  Future<SyncPushResult> createService({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> service,
    required int payloadVersion,
  }) async {
    calls.add({'operationId': operationId, 'businessId': businessId});
    return _next();
  }

  @override
  Future<SyncPushResult> updateService({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> service,
    required int expectedVersion,
    required int payloadVersion,
  }) async {
    calls.add({
      'operationId': operationId,
      'businessId': businessId,
      'expectedVersion': expectedVersion,
    });
    return _next();
  }

  @override
  Future<SyncPushResult> setServiceActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String serviceId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async {
    calls.add({
      'operationId': operationId,
      'businessId': businessId,
      'serviceId': serviceId,
      'expectedVersion': expectedVersion,
    });
    return _next();
  }
}

class _FakeSessionGuard implements SyncSessionGuard {
  _FakeSessionGuard([this.problem]);
  final SyncResultType? problem;
  @override
  Future<SyncResultType?> ensureValidSession() async => problem;
}

class _UnusedCustomerApi implements CustomerSyncApi {
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

class _UnusedSessionApi implements SessionSyncApi {
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

class _UnusedProductApi implements ProductSyncApi {
  @override
  Future<SyncPushResult> createProduct({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> product,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> updateProduct({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> product,
    required int expectedVersion,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> setProductActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String productId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);
}

class _UnusedServicesRemoteRepository implements ServicesRepository {
  @override
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async => const [];

  @override
  Future<Service> getService(String serviceId) => throw UnimplementedError();

  @override
  Future<Service> createService(ServiceInput input) =>
      throw UnimplementedError();

  @override
  Future<Service> updateService(Service service) =>
      throw UnimplementedError();

  @override
  Future<Service> setServiceActive(String serviceId, {required bool isActive}) =>
      throw UnimplementedError();
}

SyncPushResult _applied() => SyncPushResult(
  type: SyncResultType.applied,
  serverVersion: 1,
  createdAtServer: DateTime.utc(2026),
  updatedAtServer: DateTime.utc(2026),
);

final _input = ServiceInput(
  businessId: 'biz-1',
  name: 'Yıkama',
  pricePerMinute: Money(minorUnits: 200, currencyCode: 'TRY'),
  roundingIntervalMinutes: 5,
  minimumChargeMinutes: 10,
);

void main() {
  late AppDatabase db;
  late ServicesLocalDataSource local;
  late OutboxRepository outbox;

  DateTime clock() => DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    local = ServicesLocalDataSource(db);
    outbox = OutboxRepository(db);
  });

  tearDown(() async => db.close());

  OfflineServicesRepository buildRepo(SyncEngine engine) =>
      OfflineServicesRepository(
        local: local,
        remote: _UnusedServicesRemoteRepository(),
        deviceIdentity: DeviceIdentity(db, clock: clock),
        syncEngine: engine,
        currentActorUserId: () => 'user-1',
        clock: clock,
      );

  SyncEngine buildEngine(
    _FakeServiceApi api, {
    SyncResultType? sessionProblem,
    String? actor = 'user-1',
  }) => SyncEngine(
    outbox: outbox,
    customerRpc: _UnusedCustomerApi(),
    sessionRpc: _UnusedSessionApi(),
    productRpc: () => _UnusedProductApi(),
    serviceRpc: () => api,
    sessionGuard: _FakeSessionGuard(sessionProblem),
    retryPolicy: RetryPolicy(),
    clock: clock,
    currentActorUserId: () => actor,
  );

  test('hizmet + outbox aynı transaction ile pending yazılır', () async {
    final api = _FakeServiceApi([_applied]);
    final repo = buildRepo(
      buildEngine(api, sessionProblem: SyncResultType.authRequired),
    );

    final service = await repo.createService(_input);

    expect(service.name, 'Yıkama');
    final row = await local.findServiceRow(service.id);
    expect(row?.syncStatus, SyncStatus.pending.wireName);
    final outboxRows = await db.select(db.syncOutbox).get();
    expect(outboxRows.single.operationType, 'createService');
    expect(outboxRows.single.aggregateType, 'service');
  });

  test('internet gelince push hizmeti synced yapar', () async {
    final api = _FakeServiceApi([_applied]);
    final engine = buildEngine(api);
    final repo = buildRepo(engine);

    final service = await repo.createService(_input);
    final summary = await engine.push();

    expect(summary.pushed, 1);
    final row = await local.findServiceRow(service.id);
    expect(row?.syncStatus, SyncStatus.synced.wireName);
    expect(row?.serverVersion, 1);
  });

  test('sync başarısızlığı (offline) çağıranı düşürmez, kayıt korunur', () async {
    final api = _FakeServiceApi([() => throw const SocketException('offline')]);
    final repo = buildRepo(buildEngine(api));

    final service = await repo.createService(_input);

    final row = await local.findServiceRow(service.id);
    expect(row?.syncStatus, SyncStatus.pending.wireName);
    expect(service.name, 'Yıkama');
  });

  group('offline update ve setActive', () {
    Future<Service> seedService(String id, {int serverVersion = 3}) async {
      await db
          .into(db.localServices)
          .insert(
            LocalServicesCompanion.insert(
              id: id,
              businessId: 'biz-1',
              name: 'Yıkama',
              pricePerMinuteMinor: 200,
              roundingIntervalMinutes: 5,
              minimumChargeMinutes: 10,
              currencyCode: 'TRY',
              syncStatus: const Value('synced'),
              serverVersion: Value(serverVersion),
              createdAt: clock(),
              updatedAt: clock(),
            ),
          );
      return (await local.getService(id))!;
    }

    test('offline güncelleme yerelde pending yazar ve outbox oluşturur', () async {
      final service = await seedService('service-1');
      final api = _FakeServiceApi([_applied]);
      final repo = buildRepo(
        buildEngine(api, sessionProblem: SyncResultType.authRequired),
      );

      final updated = await repo.updateService(
        service.copyWith(name: 'Güncel Yıkama'),
      );

      expect(updated.name, 'Güncel Yıkama');
      final row = await local.findServiceRow('service-1');
      expect(row?.syncStatus, SyncStatus.pending.wireName);
      final outboxRows = await db.select(db.syncOutbox).get();
      expect(outboxRows.single.operationType, 'updateService');
      expect(outboxRows.single.expectedServerVersion, 3);
    });

    test('server_version conflict (STALE_VERSION) kaydı korur, çakışma işaretler', () async {
      final service = await seedService('service-1');
      final api = _FakeServiceApi([
        () => const SyncPushResult(
          type: SyncResultType.conflict,
          errorCode: 'STALE_VERSION',
        ),
      ]);
      final engine = buildEngine(api);
      final repo = buildRepo(engine);
      await repo.updateService(service.copyWith(name: 'Güncel Yıkama'));

      final summary = await engine.push();

      expect(summary.failed, 1);
      final row = await local.findServiceRow('service-1');
      expect(row?.syncStatus, SyncStatus.conflicted.wireName);
      expect(row?.lastSyncError, 'STALE_VERSION');
      expect(row?.name, 'Güncel Yıkama');
    });

    test('offline aktif/pasif değişimi yerelde pending yazar', () async {
      await seedService('service-1');
      final api = _FakeServiceApi([_applied]);
      final repo = buildRepo(
        buildEngine(api, sessionProblem: SyncResultType.authRequired),
      );

      final updated = await repo.setServiceActive(
        'service-1',
        isActive: false,
      );

      expect(updated.isActive, isFalse);
      final row = await local.findServiceRow('service-1');
      expect(row?.syncStatus, SyncStatus.pending.wireName);
      final outboxRows = await db.select(db.syncOutbox).get();
      expect(outboxRows.single.operationType, 'setServiceActive');
    });
  });
}
