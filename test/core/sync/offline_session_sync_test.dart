import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/device_identity.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:suretakip/core/sync/outbox_repository.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/core/sync/sync_engine.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/data/repositories/offline_sessions_repository.dart';

class _RecordingSessionApi implements SessionSyncApi {
  final startCalls = <Map<String, Object?>>[];
  final eventCalls = <Map<String, Object?>>[];
  SyncPushResult eventResult = const SyncPushResult(
    type: SyncResultType.applied,
  );

  @override
  Future<SyncPushResult> startSession({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> session,
    required int payloadVersion,
  }) async {
    startCalls.add(session);
    return const SyncPushResult(type: SyncResultType.applied);
  }

  @override
  Future<SyncPushResult> sessionEvent({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> event,
    required int payloadVersion,
  }) async {
    eventCalls.add(event);
    return eventResult;
  }
}

class _OkGuard implements SyncSessionGuard {
  @override
  Future<SyncResultType?> ensureValidSession() async => null;
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

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;
  late _RecordingSessionApi sessionApi;
  late SyncEngine engine;
  late OfflineSessionsRepository repo;

  DateTime clock() => DateTime.utc(2026, 4, 1, 10);

  const input = StartSessionInput(
    businessId: 'biz-1',
    serviceId: 'svc-1',
    openedByMemberId: 'member-1',
    serviceName: 'Koltuk',
    pricePerMinuteMinor: 250,
    roundingIntervalMinutes: 1,
    minimumChargeMinutes: 0,
    currencyCode: 'TRY',
  );

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    outbox = OutboxRepository(db);
    sessionApi = _RecordingSessionApi();
    engine = SyncEngine(
      outbox: outbox,
      customerRpc: _UnusedCustomerApi(),
      sessionRpc: sessionApi,
      sessionGuard: _OkGuard(),
      clock: clock,
      currentActorUserId: () => 'user-1',
    );
    repo = OfflineSessionsRepository(
      db: db,
      local: SessionsLocalDataSource(db),
      outbox: outbox,
      deviceIdentity: DeviceIdentity(db, clock: clock),
      syncEngine: engine,
      clock: clock,
    );
  });

  tearDown(() async => db.close());

  test('offline seans başlat: yerel seans + outbox start op yazılır', () async {
    final row = await repo.startSession(input, actorUserId: 'user-1');

    expect(row.status, SessionStatus.active.name);
    expect(row.startedOffline, isTrue);

    final ops = await db.select(db.syncOutbox).get();
    expect(ops, hasLength(1));
    expect(ops.single.operationType, SyncOperationType.startSession.wireName);
    expect(ops.single.aggregateId, row.id);
    expect(ops.single.sequenceNumber, 1);
  });

  test('push sonrası seans synced olur', () async {
    await repo.startSession(input, actorUserId: 'user-1');
    final summary = await engine.push();

    expect(summary.pushed, 1);
    expect(sessionApi.startCalls, hasLength(1));
    final session = (await db.select(db.localSessions).get()).single;
    expect(session.syncStatus, SyncStatus.synced.wireName);
    final op = (await db.select(db.syncOutbox).get()).single;
    expect(op.status, SyncStatus.synced.wireName);
  });

  test(
    'pause, start senkronlanmadan gönderilmez (depends_on zinciri)',
    () async {
      final row = await repo.startSession(input, actorUserId: 'user-1');
      // İlk push'u engelle: guard yerine start op'u elle pending bırakmak için
      // engine push'u yapmadan pause ekle.
      await repo.pauseSession(
        sessionId: row.id,
        businessId: 'biz-1',
        actorUserId: 'user-1',
      );

      final ops = await db.select(db.syncOutbox).get()
        ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
      expect(ops, hasLength(2));
      final pauseOp = ops[1];
      expect(pauseOp.operationType, SyncOperationType.pauseSession.wireName);
      // pause, start operasyonuna bağlı olmalı.
      expect(pauseOp.dependsOnOperationId, ops[0].operationId);
    },
  );

  test('start + pause sırayla push edilir ve ikisi de synced olur', () async {
    final row = await repo.startSession(input, actorUserId: 'user-1');
    await repo.pauseSession(
      sessionId: row.id,
      businessId: 'biz-1',
      actorUserId: 'user-1',
    );

    // İki tur: ilk tur start'ı synced yapar, ikinci tur pause'u açar.
    await engine.push();
    await engine.push();

    expect(sessionApi.startCalls, hasLength(1));
    expect(sessionApi.eventCalls, hasLength(1));
    expect(sessionApi.eventCalls.single['event_type'], 'pause');
    final ops = await db.select(db.syncOutbox).get();
    expect(ops.every((o) => o.status == SyncStatus.synced.wireName), isTrue);
    // Yerelde seans duraklatılmış durumda.
    final session = (await db.select(db.localSessions).get()).single;
    expect(session.status, SessionStatus.paused.name);
  });

  test('sonraki olay retry beklerken seans synced işaretlenmez', () async {
    final row = await repo.startSession(input, actorUserId: 'user-1');
    await repo.completeSession(
      sessionId: row.id,
      businessId: 'biz-1',
      actorUserId: 'user-1',
    );
    sessionApi.eventResult = const SyncPushResult(
      type: SyncResultType.retryableFailure,
      errorCode: 'TEMPORARY',
    );

    final summary = await engine.push();

    expect(summary.pushed, 1);
    expect(summary.retried, 1);
    final session = (await db.select(db.localSessions).get()).single;
    expect(session.status, SessionStatus.completed.name);
    expect(session.syncStatus, SyncStatus.retrying.wireName);
  });

  test('tamamlama yerel seansı kapatır ve sıralı outbox olayı yazar', () async {
    final row = await repo.startSession(input, actorUserId: 'user-1');

    await repo.completeSession(
      sessionId: row.id,
      businessId: 'biz-1',
      actorUserId: 'user-1',
    );

    final local = await (db.select(
      db.localSessions,
    )..where((t) => t.id.equals(row.id))).getSingle();
    expect(local.status, SessionStatus.completed.name);

    final ops = await db.select(db.syncOutbox).get()
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    expect(ops.last.operationType, SyncOperationType.completeSession.wireName);
    expect(ops.last.dependsOnOperationId, ops.first.operationId);
  });

  test('iptal yerel seansı kapatır ve sıralı outbox olayı yazar', () async {
    final row = await repo.startSession(input, actorUserId: 'user-1');

    await repo.cancelSession(
      sessionId: row.id,
      businessId: 'biz-1',
      actorUserId: 'user-1',
    );

    final local = await (db.select(
      db.localSessions,
    )..where((t) => t.id.equals(row.id))).getSingle();
    expect(local.status, SessionStatus.cancelled.name);

    final ops = await db.select(db.syncOutbox).get()
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    expect(ops.last.operationType, SyncOperationType.cancelSession.wireName);
  });

  test('ürün ekleme yerel kalem ve sıralı outbox olayı yazar', () async {
    final row = await repo.startSession(input, actorUserId: 'user-1');

    await repo.addProduct(
      sessionId: row.id,
      businessId: 'biz-1',
      actorUserId: 'user-1',
      product: _product(),
      quantity: 2,
    );

    final item = (await db.select(db.localSessionItems).get()).single;
    expect(item.productId, 'product-1');
    expect(item.quantity, 2);
    expect(item.lineTotalMinor, 2500);

    final ops = await db.select(db.syncOutbox).get()
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    expect(
      ops.last.operationType,
      SyncOperationType.addSessionProduct.wireName,
    );
    expect(ops.last.dependsOnOperationId, ops.first.operationId);
  });
}

Product _product() => Product(
  id: 'product-1',
  businessId: 'biz-1',
  name: 'Maden Suyu',
  sku: 'MS-01',
  unitPriceMinor: 1250,
  currencyCode: 'TRY',
  trackStock: true,
  stockQuantity: 10,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
