import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:suretakip/core/sync/outbox_repository.dart';
import 'package:suretakip/core/sync/payment_sync_rpc.dart';
import 'package:suretakip/core/sync/product_sync_rpc.dart';
import 'package:suretakip/core/sync/service_sync_rpc.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/core/sync/sync_engine.dart';

/// Bu dosya, mevcut offline_*_sync_test.dart dosyalarında müşteri odaklı
/// senaryolarla kapsanmayan SyncEngine dallarını hedefler: ürün/hizmet/ödeme
/// RPC fabrikalarının tembel çözümlenmesi, seans event dispatch yönlendirmesi
/// ve oturum bekçisinin geçici hata dalı.

class _UnusedCustomerApi implements CustomerSyncApi {
  @override
  Future<SyncPushResult> createCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int payloadVersion,
  }) => throw UnimplementedError();

  @override
  Future<SyncPushResult> updateCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int expectedVersion,
    required int payloadVersion,
  }) => throw UnimplementedError();

  @override
  Future<SyncPushResult> setCustomerActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String customerId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) => throw UnimplementedError();
}

class _FakeSessionApi implements SessionSyncApi {
  final calls = <String>[];
  FutureOr<SyncPushResult> Function()? behavior;

  @override
  Future<SyncPushResult> startSession({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> session,
    required int payloadVersion,
  }) async {
    calls.add('startSession');
    return (behavior ?? _applied)();
  }

  @override
  Future<SyncPushResult> sessionEvent({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> event,
    required int payloadVersion,
  }) async {
    calls.add('sessionEvent:${event['kind']}');
    return (behavior ?? _applied)();
  }
}

class _FakeProductApi implements ProductSyncApi {
  var buildCount = 0;
  FutureOr<SyncPushResult> Function() behavior = _applied;

  @override
  Future<SyncPushResult> createProduct({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> product,
    required int payloadVersion,
  }) async => behavior();

  @override
  Future<SyncPushResult> updateProduct({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> product,
    required int expectedVersion,
    required int payloadVersion,
  }) async => behavior();

  @override
  Future<SyncPushResult> setProductActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String productId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async => behavior();
}

class _FakeServiceApi implements ServiceSyncApi {
  FutureOr<SyncPushResult> Function() behavior = _applied;

  @override
  Future<SyncPushResult> createService({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> service,
    required int payloadVersion,
  }) async => behavior();

  @override
  Future<SyncPushResult> updateService({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> service,
    required int expectedVersion,
    required int payloadVersion,
  }) async => behavior();

  @override
  Future<SyncPushResult> setServiceActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String serviceId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async => behavior();
}

class _FakePaymentApi implements PaymentSyncApi {
  FutureOr<SyncPushResult> Function() behavior = _applied;

  @override
  Future<SyncPushResult> recordSessionPayment({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> payment,
    required int payloadVersion,
  }) async => behavior();
}

class _FakeSessionGuard implements SyncSessionGuard {
  _FakeSessionGuard([this.problem]);
  final SyncResultType? problem;
  var callCount = 0;

  @override
  Future<SyncResultType?> ensureValidSession() async {
    callCount++;
    return problem;
  }
}

SyncPushResult _applied() => SyncPushResult(
  type: SyncResultType.applied,
  serverVersion: 1,
  createdAtServer: DateTime.utc(2026),
  updatedAtServer: DateTime.utc(2026),
);

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;

  DateTime clock() => DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    outbox = OutboxRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> enqueue({
    required String operationId,
    required SyncOperationType type,
    required Map<String, Object?> payload,
    String aggregateId = 'aggregate-1',
  }) => outbox.enqueue(
    operationId: operationId,
    businessId: 'biz-1',
    actorUserId: 'user-1',
    deviceId: 'device-1',
    aggregateType: type.wireName,
    aggregateId: aggregateId,
    operationType: type,
    idempotencyKey: 'biz-1:device-1:$operationId',
    payload: payload,
    now: clock(),
  );

  group('ürün/hizmet/ödeme RPC fabrikalarının tembel çözümlenmesi', () {
    test(
      'productRpc yapılandırılmadan createProduct dispatch edilirse '
      'StateError yeniden denenebilir sayılır',
      () async {
        await enqueue(
          operationId: 'op-1',
          type: SyncOperationType.createProduct,
          payload: const {'name': 'Ürün'},
        );
        final engine = SyncEngine(
          outbox: outbox,
          customerRpc: _UnusedCustomerApi(),
          sessionRpc: _FakeSessionApi(),
          sessionGuard: _FakeSessionGuard(),
          clock: clock,
          currentActorUserId: () => 'user-1',
          currentBusinessId: () => 'biz-1',
        );

        final summary = await engine.push();

        expect(summary.retried, 1);
        final out = (await db.select(db.syncOutbox).get()).single;
        expect(out.status, SyncStatus.retrying.wireName);
      },
    );

    test(
      'serviceRpc yapılandırılmadan createService dispatch edilirse '
      'StateError yeniden denenebilir sayılır',
      () async {
        await enqueue(
          operationId: 'op-1',
          type: SyncOperationType.createService,
          payload: const {'name': 'Hizmet'},
        );
        final engine = SyncEngine(
          outbox: outbox,
          customerRpc: _UnusedCustomerApi(),
          sessionRpc: _FakeSessionApi(),
          sessionGuard: _FakeSessionGuard(),
          clock: clock,
          currentActorUserId: () => 'user-1',
          currentBusinessId: () => 'biz-1',
        );

        final summary = await engine.push();

        expect(summary.retried, 1);
      },
    );

    test(
      'paymentRpc yapılandırılmadan recordSessionPayment dispatch edilirse '
      'StateError yeniden denenebilir sayılır',
      () async {
        await enqueue(
          operationId: 'op-1',
          type: SyncOperationType.recordSessionPayment,
          payload: const {'amount': 100},
        );
        final engine = SyncEngine(
          outbox: outbox,
          customerRpc: _UnusedCustomerApi(),
          sessionRpc: _FakeSessionApi(),
          sessionGuard: _FakeSessionGuard(),
          clock: clock,
          currentActorUserId: () => 'user-1',
          currentBusinessId: () => 'biz-1',
        );

        final summary = await engine.push();

        expect(summary.retried, 1);
      },
    );

    test('productRpc fabrikası yalnız dispatch anında çağrılır ve başarır', () async {
      await enqueue(
        operationId: 'op-1',
        type: SyncOperationType.createProduct,
        payload: const {'name': 'Ürün'},
      );
      final productApi = _FakeProductApi();
      var factoryCalls = 0;
      final engine = SyncEngine(
        outbox: outbox,
        customerRpc: _UnusedCustomerApi(),
        sessionRpc: _FakeSessionApi(),
        sessionGuard: _FakeSessionGuard(),
        clock: clock,
        currentActorUserId: () => 'user-1',
        currentBusinessId: () => 'biz-1',
        productRpc: () {
          factoryCalls++;
          return productApi;
        },
      );

      final summary = await engine.push();

      expect(summary.pushed, 1);
      expect(factoryCalls, 1);
    });

    test('serviceRpc fabrikası dispatch anında çağrılır ve başarır', () async {
      await enqueue(
        operationId: 'op-1',
        type: SyncOperationType.createService,
        payload: const {'name': 'Hizmet'},
      );
      final engine = SyncEngine(
        outbox: outbox,
        customerRpc: _UnusedCustomerApi(),
        sessionRpc: _FakeSessionApi(),
        sessionGuard: _FakeSessionGuard(),
        clock: clock,
        currentActorUserId: () => 'user-1',
        currentBusinessId: () => 'biz-1',
        serviceRpc: () => _FakeServiceApi(),
      );

      final summary = await engine.push();

      expect(summary.pushed, 1);
    });

    test('paymentRpc fabrikası dispatch anında çağrılır ve başarır', () async {
      await enqueue(
        operationId: 'op-1',
        type: SyncOperationType.recordSessionPayment,
        payload: const {'amount': 100},
      );
      final engine = SyncEngine(
        outbox: outbox,
        customerRpc: _UnusedCustomerApi(),
        sessionRpc: _FakeSessionApi(),
        sessionGuard: _FakeSessionGuard(),
        clock: clock,
        currentActorUserId: () => 'user-1',
        currentBusinessId: () => 'biz-1',
        paymentRpc: () => _FakePaymentApi(),
      );

      final summary = await engine.push();

      expect(summary.pushed, 1);
    });
  });

  group('seans event dispatch yönlendirmesi', () {
    test(
      'pause/resume/addSessionProduct/complete/cancel tümü sessionEvent'
      ' üzerinden gönderilir',
      () async {
        final sessionApi = _FakeSessionApi();
        final types = [
          SyncOperationType.pauseSession,
          SyncOperationType.resumeSession,
          SyncOperationType.addSessionProduct,
          SyncOperationType.completeSession,
          SyncOperationType.cancelSession,
        ];
        for (final type in types) {
          await enqueue(
            operationId: 'op-${type.wireName}',
            type: type,
            payload: {'kind': type.wireName},
          );
        }
        final engine = SyncEngine(
          outbox: outbox,
          customerRpc: _UnusedCustomerApi(),
          sessionRpc: sessionApi,
          sessionGuard: _FakeSessionGuard(),
          clock: clock,
          currentActorUserId: () => 'user-1',
          currentBusinessId: () => 'biz-1',
        );

        final summary = await engine.push();

        expect(summary.pushed, types.length);
        expect(sessionApi.calls, hasLength(types.length));
        expect(
          sessionApi.calls,
          containsAll(types.map((t) => 'sessionEvent:${t.wireName}')),
        );
      },
    );
  });

  group('oturum bekçisi geçici hata dalı', () {
    test(
      'retryableFailure döndüğünde push hiçbir kaydı claim etmeden durur',
      () async {
        await enqueue(
          operationId: 'op-1',
          type: SyncOperationType.createProduct,
          payload: const {'name': 'Ürün'},
        );
        final guard = _FakeSessionGuard(SyncResultType.retryableFailure);
        final engine = SyncEngine(
          outbox: outbox,
          customerRpc: _UnusedCustomerApi(),
          sessionRpc: _FakeSessionApi(),
          sessionGuard: guard,
          clock: clock,
          currentActorUserId: () => 'user-1',
          currentBusinessId: () => 'biz-1',
        );

        final summary = await engine.push();

        expect(summary.pushed, 0);
        expect(summary.retried, 0);
        expect(summary.failed, 0);
        expect(summary.authRequired, isFalse);
        expect(guard.callCount, 1);
        final out = (await db.select(db.syncOutbox).get()).single;
        expect(out.status, SyncStatus.pending.wireName);
      },
    );
  });

  group('sonuç bazlı retryableFailure ve rejected dalları', () {
    test(
      'RPC açıkça retryableFailure döndürürse markRetrying çağrılır',
      () async {
        await enqueue(
          operationId: 'op-1',
          type: SyncOperationType.createProduct,
          payload: const {'name': 'Ürün'},
        );
        final productApi = _FakeProductApi()
          ..behavior = () => const SyncPushResult(
            type: SyncResultType.retryableFailure,
            errorCode: 'SERVER_BUSY',
          );
        final engine = SyncEngine(
          outbox: outbox,
          customerRpc: _UnusedCustomerApi(),
          sessionRpc: _FakeSessionApi(),
          sessionGuard: _FakeSessionGuard(),
          clock: clock,
          currentActorUserId: () => 'user-1',
          currentBusinessId: () => 'biz-1',
          productRpc: () => productApi,
        );

        final summary = await engine.push();

        expect(summary.retried, 1);
        final out = (await db.select(db.syncOutbox).get()).single;
        expect(out.status, SyncStatus.retrying.wireName);
        expect(out.lastErrorCode, 'SERVER_BUSY');
      },
    );

    test(
      'RPC rejected döndürürse kayıt silinmez, rejected işaretlenir',
      () async {
        await enqueue(
          operationId: 'op-1',
          type: SyncOperationType.createService,
          payload: const {'name': 'Hizmet'},
        );
        final engine = SyncEngine(
          outbox: outbox,
          customerRpc: _UnusedCustomerApi(),
          sessionRpc: _FakeSessionApi(),
          sessionGuard: _FakeSessionGuard(),
          clock: clock,
          currentActorUserId: () => 'user-1',
          currentBusinessId: () => 'biz-1',
          serviceRpc: () => _FakeServiceApi()
            ..behavior = () => const SyncPushResult(
              type: SyncResultType.rejected,
              errorCode: 'VALIDATION_FAILED',
            ),
        );

        final summary = await engine.push();

        expect(summary.failed, 1);
        final out = (await db.select(db.syncOutbox).get()).single;
        expect(out.status, SyncStatus.rejected.wireName);
        expect(out.lastErrorCode, 'VALIDATION_FAILED');
      },
    );

    test(
      'RPC authRequired döndürürse kayıt pending durumuna geri döner',
      () async {
        await enqueue(
          operationId: 'op-1',
          type: SyncOperationType.createProduct,
          payload: const {'name': 'Ürün'},
        );
        final engine = SyncEngine(
          outbox: outbox,
          customerRpc: _UnusedCustomerApi(),
          sessionRpc: _FakeSessionApi(),
          sessionGuard: _FakeSessionGuard(),
          clock: clock,
          currentActorUserId: () => 'user-1',
          currentBusinessId: () => 'biz-1',
          productRpc: () => _FakeProductApi()
            ..behavior = () =>
                const SyncPushResult(type: SyncResultType.authRequired),
        );

        final summary = await engine.push();

        expect(summary.authRequired, isTrue);
        final out = (await db.select(db.syncOutbox).get()).single;
        expect(out.status, SyncStatus.pending.wireName);
      },
    );
  });
}
