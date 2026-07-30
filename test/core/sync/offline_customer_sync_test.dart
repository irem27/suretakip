import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:suretakip/core/sync/outbox_repository.dart';
import 'package:suretakip/core/sync/retry_policy.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/features/customers/data/local/customers_local_data_source.dart';
import 'package:suretakip/features/customers/data/datasources/customers_remote_data_source.dart';
import 'package:suretakip/features/customers/data/repositories/offline_customers_repository.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';

/// Sunucuyu taklit eden sahte RPC. Sırayla verilen davranışları uygular.
class _FakeCustomerApi implements CustomerSyncApi {
  _FakeCustomerApi(this.behaviors);

  final List<FutureOr<SyncPushResult> Function()> behaviors;
  final calls = <Map<String, Object?>>[];
  var _index = 0;

  @override
  Future<SyncPushResult> createCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int payloadVersion,
  }) async {
    calls.add({
      'operationId': operationId,
      'idempotencyKey': idempotencyKey,
      'businessId': businessId,
    });
    final behavior = behaviors[_index.clamp(0, behaviors.length - 1)];
    _index++;
    return behavior();
  }
}

class _FakeSessionGuard implements SyncSessionGuard {
  _FakeSessionGuard([this.problem]);
  final SyncResultType? problem;
  @override
  Future<SyncResultType?> ensureValidSession() async => problem;
}

/// Müşteri testlerinde seans RPC'si çağrılmaz; boş fake yeterli.
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

class _UnusedCustomersRemoteDataSource implements CustomersRemoteDataSource {
  @override
  Future<List<Map<String, dynamic>>> getCustomers({
    required String businessId,
    required bool includeInactive,
  }) async => const [];

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

SyncPushResult _applied() => SyncPushResult(
  type: SyncResultType.applied,
  serverVersion: 1,
  createdAtServer: DateTime.utc(2026),
  updatedAtServer: DateTime.utc(2026),
);

void main() {
  late AppDatabase db;
  late CustomersLocalDataSource local;
  late OutboxRepository outbox;

  DateTime clock() => DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    local = CustomersLocalDataSource(db);
    outbox = OutboxRepository(db);
  });

  tearDown(() async => db.close());

  OfflineCustomersRepository buildRepo(SyncEngine engine) =>
      OfflineCustomersRepository(
        local: local,
        remote: _UnusedCustomersRemoteDataSource(),
        deviceIdentity: DeviceIdentity(db, clock: clock),
        syncEngine: engine,
        clock: clock,
      );

  SyncEngine buildEngine(
    _FakeCustomerApi api, {
    SyncResultType? sessionProblem,
    DateTime Function()? engineClock,
    String? actor = 'user-1',
  }) => SyncEngine(
    outbox: outbox,
    customerRpc: api,
    sessionRpc: _UnusedSessionApi(),
    sessionGuard: _FakeSessionGuard(sessionProblem),
    retryPolicy: RetryPolicy(),
    clock: engineClock ?? clock,
    currentActorUserId: () => actor,
  );

  const input = CustomerInput(businessId: 'biz-1', name: 'Ali Veli');

  test('müşteri + outbox aynı transaction ile pending yazılır', () async {
    final api = _FakeCustomerApi([_applied]);
    // Oturum auth engelli: arka plan push hiçbir kaydı değiştirmez, böylece
    // enqueue sonrası durum deterministik gözlemlenir.
    final repo = buildRepo(
      buildEngine(api, sessionProblem: SyncResultType.authRequired),
    );

    final row = await repo.createCustomer(input, actorUserId: 'user-1');

    expect(row.name, 'Ali Veli');
    expect(row.syncStatus, SyncStatus.pending.wireName);

    final outboxRows = await db.select(db.syncOutbox).get();
    expect(outboxRows, hasLength(1));
    expect(outboxRows.single.sequenceNumber, 1);
    expect(outboxRows.single.operationType, 'createCustomer');
    // {business_id}:{device_id}:{operation_id} biçimi.
    expect(
      outboxRows.single.idempotencyKey,
      matches(RegExp(r'^biz-1:[0-9a-f-]{36}:[0-9a-f-]{36}$')),
    );
    expect(outboxRows.single.operationId, isNotEmpty);
  });

  test('internet gelince push müşteriyi synced yapar', () async {
    final api = _FakeCustomerApi([_applied]);
    final engine = buildEngine(api);
    final repo = buildRepo(engine);

    await repo.createCustomer(input, actorUserId: 'user-1');
    final summary = await engine.push();

    expect(summary.pushed, 1);
    final customer = (await db.select(db.localCustomers).get()).single;
    expect(customer.syncStatus, SyncStatus.synced.wireName);
    expect(customer.serverVersion, 1);
    final out = (await db.select(db.syncOutbox).get()).single;
    expect(out.status, SyncStatus.synced.wireName);
    expect(out.submittedByUserId, 'user-1');
  });

  test('aynı operasyon üç kez gönderilse de tek kayıt kalır', () async {
    // İlk push applied; sonraki turlar already_processed döndürür.
    final api = _FakeCustomerApi([
      _applied,
      () => const SyncPushResult(type: SyncResultType.alreadyProcessed),
    ]);
    final engine = buildEngine(api);
    final repo = buildRepo(engine);
    await repo.createCustomer(input, actorUserId: 'user-1');

    await engine.push();
    await engine.push();
    await engine.push();

    // synced kayıt tekrar claim edilmez → RPC yalnız bir kez çağrılır.
    expect(api.calls, hasLength(1));
    expect((await db.select(db.localCustomers).get()), hasLength(1));
  });

  test('geçici hata retrying yapar, kayıt korunur, sonra başarır', () async {
    var tick = DateTime.utc(2026, 1, 1, 12);
    final api = _FakeCustomerApi([
      () => throw const SocketException('offline'),
      _applied,
    ]);
    final engine = buildEngine(api, engineClock: () => tick);
    final repo = buildRepo(engine);
    await repo.createCustomer(input, actorUserId: 'user-1');

    final first = await engine.push();
    expect(first.retried, 1);
    final out = (await db.select(db.syncOutbox).get()).single;
    expect(out.status, SyncStatus.retrying.wireName);
    expect(out.attemptCount, 1);
    expect(out.nextAttemptAt, isNotNull);
    // Aggregate durumu outbox ile tutarlıdır; kayıt silinmeden retrying kalır.
    final customer = (await db.select(db.localCustomers).get()).single;
    expect(customer.syncStatus, SyncStatus.retrying.wireName);

    // Backoff sonrası zamanı ilerlet ve tekrar dene.
    tick = tick.add(const Duration(minutes: 5));
    final second = await engine.push();
    expect(second.pushed, 1);
    final syncedCustomer = (await db.select(db.localCustomers).get()).single;
    expect(syncedCustomer.syncStatus, SyncStatus.synced.wireName);
  });

  test('authRequired push kaydı bozmadan durur', () async {
    final api = _FakeCustomerApi([_applied]);
    final engine = buildEngine(
      api,
      sessionProblem: SyncResultType.authRequired,
    );
    final repo = buildRepo(engine);
    await repo.createCustomer(input, actorUserId: 'user-1');

    final summary = await engine.push();

    expect(summary.authRequired, isTrue);
    expect(api.calls, isEmpty);
    final out = (await db.select(db.syncOutbox).get()).single;
    expect(out.status, SyncStatus.pending.wireName);
  });

  test(
    'authRequired gönderilmemiş diğer claimleri processing bırakmaz',
    () async {
      final api = _FakeCustomerApi([
        () => const SyncPushResult(type: SyncResultType.authRequired),
      ]);
      final enqueueOnlyEngine = buildEngine(
        api,
        sessionProblem: SyncResultType.authRequired,
      );
      final repo = buildRepo(enqueueOnlyEngine);
      await repo.createCustomer(input, actorUserId: 'user-1');
      await repo.createCustomer(
        const CustomerInput(businessId: 'biz-1', name: 'Ayşe Yılmaz'),
        actorUserId: 'user-1',
      );

      final summary = await buildEngine(api).push();

      expect(summary.authRequired, isTrue);
      final outboxRows = await db.select(db.syncOutbox).get();
      expect(outboxRows, hasLength(2));
      expect(
        outboxRows.every((row) => row.status == SyncStatus.pending.wireName),
        isTrue,
      );
    },
  );

  test(
    'uygulama processing sırasında kapanırsa operasyon kurtarılır',
    () async {
      final api = _FakeCustomerApi([_applied]);
      final engine = buildEngine(api);
      final repo = buildRepo(
        buildEngine(api, sessionProblem: SyncResultType.authRequired),
      );
      await repo.createCustomer(input, actorUserId: 'user-1');

      await outbox.claimReady(
        actorUserId: 'user-1',
        now: clock().subtract(const Duration(minutes: 6)),
      );
      expect(
        (await db.select(db.syncOutbox).get()).single.status,
        SyncStatus.processing.wireName,
      );

      // Yeni SyncEngine örneği, uygulamanın yeniden açılmasını temsil eder.
      final summary = await engine.push();

      expect(summary.pushed, 1);
      expect(api.calls, hasLength(1));
      expect(
        (await db.select(db.syncOutbox).get()).single.status,
        SyncStatus.synced.wireName,
      );
    },
  );

  test(
    'aktif processing lease başka worker tarafından sahiplenilmez',
    () async {
      final api = _FakeCustomerApi([_applied]);
      final engine = buildEngine(api);
      final repo = buildRepo(
        buildEngine(api, sessionProblem: SyncResultType.authRequired),
      );
      await repo.createCustomer(input, actorUserId: 'user-1');

      await outbox.claimReady(actorUserId: 'user-1', now: clock());

      final summary = await engine.push();

      expect(summary.pushed, 0);
      expect(api.calls, isEmpty);
      expect(
        (await db.select(db.syncOutbox).get()).single.status,
        SyncStatus.processing.wireName,
      );
    },
  );

  test('iki worker aynı pending operasyonu birlikte claim edemez', () async {
    final api = _FakeCustomerApi([_applied]);
    final repo = buildRepo(
      buildEngine(api, sessionProblem: SyncResultType.authRequired),
    );
    await repo.createCustomer(input, actorUserId: 'user-1');

    final claims = await Future.wait([
      outbox.claimReady(actorUserId: 'user-1', now: clock()),
      outbox.claimReady(actorUserId: 'user-1', now: clock()),
    ]);

    expect(claims.expand((rows) => rows), hasLength(1));
  });

  test('bloklu ilk aday arkadaki bağımsız operasyonu aç bırakmaz', () async {
    final now = clock();
    await outbox.enqueue(
      operationId: 'parent-op',
      businessId: 'biz-1',
      actorUserId: 'user-1',
      deviceId: 'device-1',
      aggregateType: 'customer',
      aggregateId: 'parent',
      operationType: SyncOperationType.createCustomer,
      idempotencyKey: 'parent-key',
      payload: const <String, Object?>{},
      now: now,
    );
    final parent = (await outbox.claimReady(
      actorUserId: 'user-1',
      now: now,
      limit: 1,
    )).single;
    await outbox.markTerminal(parent, status: SyncStatus.rejected);

    await outbox.enqueue(
      operationId: 'blocked-op',
      businessId: 'biz-1',
      actorUserId: 'user-1',
      deviceId: 'device-1',
      aggregateType: 'customer',
      aggregateId: 'a-blocked',
      operationType: SyncOperationType.createCustomer,
      idempotencyKey: 'blocked-key',
      payload: const <String, Object?>{},
      now: now,
      dependsOnOperationId: 'parent-op',
    );
    await outbox.enqueue(
      operationId: 'independent-op',
      businessId: 'biz-1',
      actorUserId: 'user-1',
      deviceId: 'device-1',
      aggregateType: 'customer',
      aggregateId: 'z-independent',
      operationType: SyncOperationType.createCustomer,
      idempotencyKey: 'independent-key',
      payload: const <String, Object?>{},
      now: now,
    );

    final claimed = await outbox.claimReady(
      actorUserId: 'user-1',
      now: now,
      limit: 1,
    );

    expect(claimed, hasLength(1));
    expect(claimed.single.operationId, 'independent-op');
  });

  test('süresi dolan eski worker yeni worker sonucunu ezemez', () async {
    final api = _FakeCustomerApi([_applied]);
    final repo = buildRepo(
      buildEngine(api, sessionProblem: SyncResultType.authRequired),
    );
    await repo.createCustomer(input, actorUserId: 'user-1');

    final oldClaim = (await outbox.claimReady(
      actorUserId: 'user-1',
      now: clock().subtract(const Duration(minutes: 6)),
    )).single;
    await outbox.recoverStaleProcessing(now: clock());
    final newClaim = (await outbox.claimReady(
      actorUserId: 'user-1',
      now: clock(),
    )).single;

    expect(
      await outbox.applySuccess(
        newClaim,
        _applied(),
        now: clock(),
        submittedByUserId: 'user-1',
      ),
      isTrue,
    );
    expect(
      await outbox.markRetrying(
        oldClaim,
        attemptCount: 1,
        nextAttemptAt: clock().add(const Duration(minutes: 1)),
      ),
      isFalse,
    );
    expect(
      (await db.select(db.syncOutbox).get()).single.status,
      SyncStatus.synced.wireName,
    );
  });

  test('kalıcı ret kaydı silmez, conflicted işaretler', () async {
    final api = _FakeCustomerApi([
      () => const SyncPushResult(
        type: SyncResultType.conflict,
        errorCode: 'CUSTOMER_ID_CONFLICT',
      ),
    ]);
    final engine = buildEngine(api);
    final repo = buildRepo(engine);
    await repo.createCustomer(input, actorUserId: 'user-1');

    final summary = await engine.push();

    expect(summary.failed, 1);
    final out = (await db.select(db.syncOutbox).get()).single;
    expect(out.status, SyncStatus.conflicted.wireName);
    expect(out.lastErrorCode, 'CUSTOMER_ID_CONFLICT');
    // Müşteri kaybolmadı.
    expect((await db.select(db.localCustomers).get()), hasLength(1));
  });

  test(
    'başka kullanıcının bekleyen kaydı farklı oturumda gönderilmez',
    () async {
      // user-A offline müşteri oluşturur (push auth engelli → gönderilmez).
      final repoA = buildRepo(
        buildEngine(
          _FakeCustomerApi([_applied]),
          sessionProblem: SyncResultType.authRequired,
        ),
      );
      await repoA.createCustomer(input, actorUserId: 'user-A');

      // user-B oturumu push eder; A'nın kaydını CLAIM ETMEMELİ.
      final apiB = _FakeCustomerApi([_applied]);
      final summaryB = await buildEngine(apiB, actor: 'user-B').push();
      expect(summaryB.pushed, 0);
      expect(apiB.calls, isEmpty);

      // Oturumsuz (logout) da hiçbir şey göndermez.
      final apiNone = _FakeCustomerApi([_applied]);
      final summaryNone = await buildEngine(apiNone, actor: null).push();
      expect(summaryNone.pushed, 0);
      expect(apiNone.calls, isEmpty);

      // Kayıt korundu (silinmedi).
      final out = (await db.select(db.syncOutbox).get()).single;
      expect(out.status, SyncStatus.pending.wireName);
      expect(out.originalActorUserId, 'user-A');

      // user-A tekrar girince gönderilir.
      final apiA = _FakeCustomerApi([_applied]);
      final summaryA = await buildEngine(apiA, actor: 'user-A').push();
      expect(summaryA.pushed, 1);
    },
  );
}
