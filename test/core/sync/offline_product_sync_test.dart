import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
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
import 'package:suretakip/features/products/data/local/products_local_data_source.dart';
import 'package:suretakip/features/products/data/repositories/offline_products_repository.dart';
import 'package:suretakip/features/products/domain/entities/inventory_movement.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';
import 'package:suretakip/features/products/domain/repositories/products_repository.dart';

/// Sunucuyu taklit eden sahte RPC. Sırayla verilen davranışları uygular.
class _FakeProductApi implements ProductSyncApi {
  _FakeProductApi(this.behaviors);

  final List<FutureOr<SyncPushResult> Function()> behaviors;
  final calls = <Map<String, Object?>>[];
  var _index = 0;

  SyncPushResult _next() {
    final behavior = behaviors[_index.clamp(0, behaviors.length - 1)];
    _index++;
    return behavior() as SyncPushResult;
  }

  @override
  Future<SyncPushResult> createProduct({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> product,
    required int payloadVersion,
  }) async {
    calls.add({'operationId': operationId, 'businessId': businessId});
    return _next();
  }

  @override
  Future<SyncPushResult> updateProduct({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> product,
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
  Future<SyncPushResult> setProductActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String productId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async {
    calls.add({
      'operationId': operationId,
      'businessId': businessId,
      'productId': productId,
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

class _UnusedServiceApi implements ServiceSyncApi {
  @override
  Future<SyncPushResult> createService({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> service,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> updateService({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> service,
    required int expectedVersion,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> setServiceActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String serviceId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);
}

class _UnusedProductsRemoteRepository implements ProductsRepository {
  @override
  Future<List<Product>> getProducts({
    required String businessId,
    bool includeInactive = false,
  }) async => const [];

  @override
  Future<Product> getProduct(String productId) => throw UnimplementedError();

  @override
  Future<Product> createProduct(ProductInput input) =>
      throw UnimplementedError();

  @override
  Future<Product> updateProduct(Product product) => throw UnimplementedError();

  @override
  Future<Product> setProductActive(
    String productId, {
    required bool isActive,
  }) => throw UnimplementedError();

  @override
  Future<List<InventoryMovement>> getInventoryMovements({
    required String businessId,
    String? productId,
  }) async => const [];

  @override
  Future<InventoryMovement> createInventoryMovement(
    InventoryMovement movement,
  ) => throw UnimplementedError();
}

SyncPushResult _applied() => SyncPushResult(
  type: SyncResultType.applied,
  serverVersion: 1,
  createdAtServer: DateTime.utc(2026),
  updatedAtServer: DateTime.utc(2026),
);

final _input = ProductInput(
  businessId: 'biz-1',
  name: 'Şampuan',
  sku: 'SKU-1',
  unitPrice: Money(minorUnits: 1000, currencyCode: 'TRY'),
  trackStock: false,
  stockQuantity: 0,
);

void main() {
  late AppDatabase db;
  late ProductsLocalDataSource local;
  late OutboxRepository outbox;

  DateTime clock() => DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    local = ProductsLocalDataSource(db);
    outbox = OutboxRepository(db);
  });

  tearDown(() async => db.close());

  OfflineProductsRepository buildRepo(SyncEngine engine) =>
      OfflineProductsRepository(
        local: local,
        remote: _UnusedProductsRemoteRepository(),
        deviceIdentity: DeviceIdentity(db, clock: clock),
        syncEngine: engine,
        currentActorUserId: () => 'user-1',
        clock: clock,
      );

  SyncEngine buildEngine(
    _FakeProductApi api, {
    SyncResultType? sessionProblem,
    DateTime Function()? engineClock,
    String? actor = 'user-1',
  }) => SyncEngine(
    outbox: outbox,
    customerRpc: _UnusedCustomerApi(),
    sessionRpc: _UnusedSessionApi(),
    productRpc: () => api,
    serviceRpc: () => _UnusedServiceApi(),
    sessionGuard: _FakeSessionGuard(sessionProblem),
    retryPolicy: RetryPolicy(),
    clock: engineClock ?? clock,
    currentActorUserId: () => actor,
  );

  test('ürün + outbox aynı transaction ile pending yazılır', () async {
    final api = _FakeProductApi([_applied]);
    final repo = buildRepo(
      buildEngine(api, sessionProblem: SyncResultType.authRequired),
    );

    final product = await repo.createProduct(_input);

    expect(product.name, 'Şampuan');
    final row = await local.findProductRow(product.id);
    expect(row?.syncStatus, SyncStatus.pending.wireName);

    final outboxRows = await db.select(db.syncOutbox).get();
    expect(outboxRows, hasLength(1));
    expect(outboxRows.single.operationType, 'createProduct');
    expect(outboxRows.single.aggregateType, 'product');
  });

  test('internet gelince push ürünü synced yapar', () async {
    final api = _FakeProductApi([_applied]);
    final engine = buildEngine(api);
    final repo = buildRepo(engine);

    final product = await repo.createProduct(_input);
    final summary = await engine.push();

    expect(summary.pushed, 1);
    final row = await local.findProductRow(product.id);
    expect(row?.syncStatus, SyncStatus.synced.wireName);
    expect(row?.serverVersion, 1);
  });

  test(
    'sync başarısızlığı (offline) çağıranı düşürmez, kayıt korunur',
    () async {
      final api = _FakeProductApi([
        () => throw const SocketException('offline'),
      ]);
      final repo = buildRepo(buildEngine(api));

      final product = await repo.createProduct(_input);

      final row = await local.findProductRow(product.id);
      expect(row?.syncStatus, SyncStatus.pending.wireName);
      expect(product.name, 'Şampuan');
    },
  );

  group('offline update ve setActive', () {
    Future<Product> seedProduct(String id, {int serverVersion = 3}) async {
      await db
          .into(db.localProducts)
          .insert(
            LocalProductsCompanion.insert(
              id: id,
              businessId: 'biz-1',
              name: 'Şampuan',
              sku: const Value('SKU-1'),
              unitPriceMinor: 1000,
              currencyCode: 'TRY',
              syncStatus: const Value('synced'),
              serverVersion: Value(serverVersion),
              createdAt: clock(),
              updatedAt: clock(),
            ),
          );
      return (await local.getProduct(id))!;
    }

    test(
      'offline güncelleme yerelde pending yazar ve outbox oluşturur',
      () async {
        final product = await seedProduct('product-1');
        final api = _FakeProductApi([_applied]);
        final repo = buildRepo(
          buildEngine(api, sessionProblem: SyncResultType.authRequired),
        );

        final updated = await repo.updateProduct(
          product.copyWith(name: 'Güncel Şampuan'),
        );

        expect(updated.name, 'Güncel Şampuan');
        final row = await local.findProductRow('product-1');
        expect(row?.syncStatus, SyncStatus.pending.wireName);
        final outboxRows = await db.select(db.syncOutbox).get();
        expect(outboxRows.single.operationType, 'updateProduct');
        expect(outboxRows.single.expectedServerVersion, 3);
      },
    );

    test(
      'server_version conflict (STALE_VERSION) kaydı korur, çakışma işaretler',
      () async {
        final product = await seedProduct('product-1');
        final api = _FakeProductApi([
          () => const SyncPushResult(
            type: SyncResultType.conflict,
            errorCode: 'STALE_VERSION',
          ),
        ]);
        final engine = buildEngine(api);
        final repo = buildRepo(engine);
        await repo.updateProduct(product.copyWith(name: 'Güncel Şampuan'));

        final summary = await engine.push();

        expect(summary.failed, 1);
        final row = await local.findProductRow('product-1');
        expect(row?.syncStatus, SyncStatus.conflicted.wireName);
        expect(row?.lastSyncError, 'STALE_VERSION');
        expect(row?.name, 'Güncel Şampuan');
      },
    );

    test('offline aktif/pasif değişimi yerelde pending yazar', () async {
      await seedProduct('product-1');
      final api = _FakeProductApi([_applied]);
      final repo = buildRepo(
        buildEngine(api, sessionProblem: SyncResultType.authRequired),
      );

      final updated = await repo.setProductActive('product-1', isActive: false);

      expect(updated.isActive, isFalse);
      final row = await local.findProductRow('product-1');
      expect(row?.syncStatus, SyncStatus.pending.wireName);
      final outboxRows = await db.select(db.syncOutbox).get();
      expect(outboxRows.single.operationType, 'setProductActive');
    });
  });
}
