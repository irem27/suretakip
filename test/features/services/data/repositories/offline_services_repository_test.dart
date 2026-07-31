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
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/services/data/local/services_local_data_source.dart';
import 'package:suretakip/features/services/data/repositories/offline_services_repository.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/entities/service_input.dart';
import 'package:suretakip/features/services/domain/repositories/services_repository.dart';

void main() {
  late AppDatabase db;
  late ServicesLocalDataSource local;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    local = ServicesLocalDataSource(db);
  });

  tearDown(() => db.close());

  test('oturum açık kullanıcı yokken createService StateError fırlatır', () async {
    final repository = _repository(db: db, local: local, actorUserId: () => null);

    await expectLater(
      repository.createService(_input()),
      throwsA(isA<StateError>()),
    );
  });

  test('createService hizmeti yerelde beklemede olarak kalıcı yazar', () async {
    final repository = _repository(db: db, local: local);

    final created = await repository.createService(_input());

    expect(created.name, 'Bilardo');
    expect(created.pricePerMinuteMinor, 250);
    final row = await local.findServiceRow(created.id);
    expect(row?.syncStatus, SyncStatus.pending.wireName);
  });

  test('updateService, yerelde kayıt yoksa StateError fırlatır', () async {
    final repository = _repository(db: db, local: local);

    await expectLater(
      repository.updateService(_service(id: 'yok')),
      throwsA(isA<StateError>()),
    );
  });

  test('setServiceActive, yerelde kayıt yoksa StateError fırlatır', () async {
    final repository = _repository(db: db, local: local);

    await expectLater(
      repository.setServiceActive('yok', isActive: false),
      throwsA(isA<StateError>()),
    );
  });

  test('updateService var olan hizmeti yerelde günceller', () async {
    final repository = _repository(db: db, local: local);
    final created = await repository.createService(_input());

    final updated = await repository.updateService(
      _service(id: created.id).copyWith(name: 'Güncel Bilardo'),
    );

    expect(updated.name, 'Güncel Bilardo');
  });

  test('setServiceActive hizmeti yerelde pasif yapar', () async {
    final repository = _repository(db: db, local: local);
    final created = await repository.createService(_input());

    final updated = await repository.setServiceActive(
      created.id,
      isActive: false,
    );

    expect(updated.isActive, isFalse);
  });

  test(
    'getServices, önbellek boşsa sunucudan tam katalogu çekip önbelleğe yazar',
    () async {
      final remote = _FakeServicesRemote([_remoteService(id: 'server-1')]);
      final repository = _repository(db: db, local: local, remote: remote);

      final services = await repository.getServices(businessId: 'business-1');

      expect(services.single.id, 'server-1');
      expect((await local.getService('server-1'))?.id, 'server-1');
    },
  );

  test('pullFromServer tam katalogu yerele yazar', () async {
    final remote = _FakeServicesRemote([_remoteService(id: 'server-2')]);
    final repository = _repository(db: db, local: local, remote: remote);

    await repository.pullFromServer('business-1');

    expect((await local.getService('server-2'))?.id, 'server-2');
  });
}

OfflineServicesRepository _repository({
  required AppDatabase db,
  required ServicesLocalDataSource local,
  ServicesRepository? remote,
  String? Function()? actorUserId,
}) => OfflineServicesRepository(
  local: local,
  remote: remote ?? _FakeServicesRemote(const []),
  deviceIdentity: DeviceIdentity(db),
  syncEngine: SyncEngine(
    outbox: OutboxRepository(db),
    customerRpc: _NoopCustomerApi(),
    sessionRpc: _NoopSessionApi(),
    sessionGuard: _AuthRequiredGuard(),
  ),
  currentActorUserId: actorUserId ?? () => 'user-1',
);

ServiceInput _input() => ServiceInput(
  businessId: 'business-1',
  name: 'Bilardo',
  pricePerMinute: Money(minorUnits: 250, currencyCode: 'TRY'),
  roundingIntervalMinutes: 15,
  minimumChargeMinutes: 10,
);

Service _service({required String id}) => Service(
  id: id,
  businessId: 'business-1',
  name: 'Bilardo',
  pricePerMinuteMinor: 250,
  roundingIntervalMinutes: 15,
  minimumChargeMinutes: 10,
  currencyCode: 'TRY',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Service _remoteService({required String id}) => _service(id: id);

class _FakeServicesRemote implements ServicesRepository {
  _FakeServicesRemote(this.services);

  final List<Service> services;

  @override
  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async => services;

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
