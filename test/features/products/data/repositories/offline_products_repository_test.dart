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
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/products/data/local/products_local_data_source.dart';
import 'package:suretakip/features/products/data/repositories/offline_products_repository.dart';
import 'package:suretakip/features/products/domain/entities/inventory_movement.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';
import 'package:suretakip/features/products/domain/repositories/products_repository.dart';

void main() {
  late AppDatabase db;
  late ProductsLocalDataSource local;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    local = ProductsLocalDataSource(db);
  });

  tearDown(() => db.close());

  test(
    'oturum açık kullanıcı yokken createProduct StateError fırlatır',
    () async {
      final repository = _repository(
        db: db,
        local: local,
        actorUserId: () => null,
      );

      await expectLater(
        repository.createProduct(_input()),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('createProduct ürünü yerelde beklemede olarak kalıcı yazar', () async {
    final repository = _repository(db: db, local: local);

    final created = await repository.createProduct(_input());

    expect(created.name, 'Kola');
    expect(created.stockQuantity, 24);
    final row = await local.findProductRow(created.id);
    expect(row?.syncStatus, SyncStatus.pending.wireName);
  });

  test('updateProduct, yerelde kayıt yoksa StateError fırlatır', () async {
    final repository = _repository(db: db, local: local);

    await expectLater(
      repository.updateProduct(_product(id: 'yok')),
      throwsA(isA<StateError>()),
    );
  });

  test('setProductActive, yerelde kayıt yoksa StateError fırlatır', () async {
    final repository = _repository(db: db, local: local);

    await expectLater(
      repository.setProductActive('yok', isActive: false),
      throwsA(isA<StateError>()),
    );
  });

  test('updateProduct var olan ürünü yerelde günceller', () async {
    final repository = _repository(db: db, local: local);
    final created = await repository.createProduct(_input());

    final updated = await repository.updateProduct(
      _product(id: created.id).copyWith(name: 'Güncel Kola'),
    );

    expect(updated.name, 'Güncel Kola');
  });

  test('setProductActive ürünü yerelde pasif yapar', () async {
    final repository = _repository(db: db, local: local);
    final created = await repository.createProduct(_input());

    final updated = await repository.setProductActive(
      created.id,
      isActive: false,
    );

    expect(updated.isActive, isFalse);
  });

  test(
    'getProducts, önbellek boşsa sunucudan tam katalogu çekip önbelleğe yazar',
    () async {
      final remote = _FakeProductsRemote([_remoteProduct(id: 'server-1')]);
      final repository = _repository(db: db, local: local, remote: remote);

      final products = await repository.getProducts(businessId: 'business-1');

      expect(products.single.id, 'server-1');
      expect((await local.getProduct('server-1'))?.id, 'server-1');
    },
  );

  test('getInventoryMovements her zaman sunucudan (remote) okunur', () async {
    final remote = _FakeProductsRemote([]);
    final repository = _repository(db: db, local: local, remote: remote);

    final movements = await repository.getInventoryMovements(
      businessId: 'business-1',
    );

    expect(movements, isEmpty);
    expect(remote.getInventoryMovementsCalled, isTrue);
  });

  test('createInventoryMovement doğrudan uzak depoya iletilir', () async {
    final remote = _FakeProductsRemote([]);
    final repository = _repository(db: db, local: local, remote: remote);

    await repository.createInventoryMovement(_movement());

    expect(remote.createInventoryMovementCalled, isTrue);
  });

  test('pullFromServer tam katalogu yerele yazar', () async {
    final remote = _FakeProductsRemote([_remoteProduct(id: 'server-2')]);
    final repository = _repository(db: db, local: local, remote: remote);

    await repository.pullFromServer('business-1');

    expect((await local.getProduct('server-2'))?.id, 'server-2');
  });
}

OfflineProductsRepository _repository({
  required AppDatabase db,
  required ProductsLocalDataSource local,
  ProductsRepository? remote,
  String? Function()? actorUserId,
}) => OfflineProductsRepository(
  local: local,
  remote: remote ?? _FakeProductsRemote(const []),
  deviceIdentity: DeviceIdentity(db),
  syncEngine: SyncEngine(
    outbox: OutboxRepository(db),
    customerRpc: _NoopCustomerApi(),
    sessionRpc: _NoopSessionApi(),
    sessionGuard: _AuthRequiredGuard(),
  ),
  currentActorUserId: actorUserId ?? () => 'user-1',
);

ProductInput _input() => ProductInput(
  businessId: 'business-1',
  name: 'Kola',
  sku: 'KOLA-1',
  unitPrice: Money(minorUnits: 3000, currencyCode: 'TRY'),
  trackStock: true,
  stockQuantity: 24,
);

Product _product({required String id}) => Product(
  id: id,
  businessId: 'business-1',
  name: 'Kola',
  sku: 'KOLA-1',
  unitPriceMinor: 3000,
  currencyCode: 'TRY',
  trackStock: true,
  stockQuantity: 24,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Product _remoteProduct({required String id}) => _product(id: id);

InventoryMovement _movement() => InventoryMovement(
  id: 'movement-1',
  businessId: 'business-1',
  productId: 'product-1',
  sessionItemId: null,
  movementType: InventoryMovementType.manualAdjustment,
  quantityDelta: 1,
  note: null,
  createdByMemberId: null,
  createdAt: DateTime.utc(2026),
);

class _FakeProductsRemote implements ProductsRepository {
  _FakeProductsRemote(this.products);

  final List<Product> products;
  bool getInventoryMovementsCalled = false;
  bool createInventoryMovementCalled = false;

  @override
  Future<List<Product>> getProducts({
    required String businessId,
    bool includeInactive = false,
  }) async => products;

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
  }) async {
    getInventoryMovementsCalled = true;
    return const [];
  }

  @override
  Future<InventoryMovement> createInventoryMovement(
    InventoryMovement movement,
  ) async {
    createInventoryMovementCalled = true;
    return movement;
  }
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
