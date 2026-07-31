import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/products/data/local/products_local_data_source.dart';
import 'package:suretakip/features/products/data/repositories/cached_products_repository.dart';
import 'package:suretakip/features/products/domain/entities/inventory_movement.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';
import 'package:suretakip/features/products/domain/repositories/products_repository.dart';

void main() {
  late AppDatabase db;
  late CachedProductsRepository repo;
  late _FakeRemote remote;
  late ProductsLocalDataSource local;

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    remote = _FakeRemote();
    local = ProductsLocalDataSource(db);
    repo = CachedProductsRepository(remote: remote, local: local);
  });

  tearDown(() => db.close());

  test('önbellekte varsa getProduct anında döner ve arkada tazeler', () async {
    await local.upsertProduct(_product('cached'));
    remote.products = [_product('cached')];

    final result = await repo.getProduct('cached');

    expect(result.id, 'cached');
  });

  test(
    'önbellek boşken getProduct sunucudan çeker ve önbelleğe yazar',
    () async {
      remote.products = [_product('p1')];

      final result = await repo.getProduct('p1');

      expect(result.id, 'p1');
      expect((await local.getProduct('p1'))?.id, 'p1');
    },
  );

  test('önbellek boşken ağ hatası getProduct için yükseltilir', () async {
    remote.throwNetwork = true;
    expect(repo.getProduct('p1'), throwsA(isA<NetworkException>()));
  });

  test('createProduct sunucuya iletir ve sonucu önbelleğe yazar', () async {
    final input = ProductInput(
      businessId: 'b1',
      name: 'Yeni Ürün',
      sku: null,
      unitPrice: Money(minorUnits: 500, currencyCode: 'TRY'),
      trackStock: false,
      stockQuantity: 0,
    );
    remote.createProductResult = _product('created');

    final result = await repo.createProduct(input);

    expect(result.id, 'created');
    expect(remote.createProductCalls.single, input);
    expect((await local.getProduct('created'))?.id, 'created');
  });

  test('updateProduct sunucuya iletir ve sonucu önbelleğe yazar', () async {
    final updated = _product('p1');

    final result = await repo.updateProduct(updated);

    expect(result.id, 'p1');
    expect(remote.updateProductCalls, [updated]);
    expect((await local.getProduct('p1'))?.id, 'p1');
  });

  test('setProductActive sunucuya iletir ve sonucu önbelleğe yazar', () async {
    remote.setActiveResult = _product('p1').copyWith(isActive: false);

    final result = await repo.setProductActive('p1', isActive: false);

    expect(result.isActive, isFalse);
    expect(remote.setActiveCalls.single, ('p1', false));
    expect((await local.getProduct('p1'))?.isActive, isFalse);
  });

  test('getInventoryMovements doğrudan sunucuya devredilir', () async {
    remote.movements = [_movement('m1')];

    final result = await repo.getInventoryMovements(businessId: 'b1');

    expect(result.single.id, 'm1');
  });

  test('createInventoryMovement doğrudan sunucuya devredilir', () async {
    final movement = _movement('m1');
    remote.createMovementResult = movement;

    final result = await repo.createInventoryMovement(movement);

    expect(result.id, 'm1');
    expect(remote.createMovementCalls.single, movement);
  });
}

Product _product(String id) => Product(
  id: id,
  businessId: 'b1',
  name: 'Ürün $id',
  sku: null,
  unitPriceMinor: 1500,
  currencyCode: 'TRY',
  trackStock: true,
  stockQuantity: 20,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

InventoryMovement _movement(String id) => InventoryMovement(
  id: id,
  businessId: 'b1',
  productId: 'p1',
  sessionItemId: null,
  movementType: InventoryMovementType.manualAdjustment,
  quantityDelta: -1,
  note: null,
  createdByMemberId: null,
  createdAt: DateTime.utc(2026, 7, 1),
);

class _FakeRemote implements ProductsRepository {
  List<Product> products = const [];
  List<InventoryMovement> movements = const [];
  bool throwNetwork = false;

  final List<ProductInput> createProductCalls = [];
  final List<Product> updateProductCalls = [];
  final List<(String, bool)> setActiveCalls = [];
  final List<InventoryMovement> createMovementCalls = [];

  Product? createProductResult;
  Product? setActiveResult;
  InventoryMovement? createMovementResult;

  @override
  Future<List<Product>> getProducts({
    required String businessId,
    bool includeInactive = false,
  }) async {
    if (throwNetwork) throw const NetworkException('çevrimdışı');
    return products;
  }

  @override
  Future<Product> getProduct(String productId) async {
    if (throwNetwork) throw const NetworkException('çevrimdışı');
    return products.firstWhere((p) => p.id == productId);
  }

  @override
  Future<Product> createProduct(ProductInput input) async {
    createProductCalls.add(input);
    return createProductResult!;
  }

  @override
  Future<Product> updateProduct(Product product) async {
    updateProductCalls.add(product);
    return product;
  }

  @override
  Future<Product> setProductActive(
    String productId, {
    required bool isActive,
  }) async {
    setActiveCalls.add((productId, isActive));
    return setActiveResult!;
  }

  @override
  Future<List<InventoryMovement>> getInventoryMovements({
    required String businessId,
    String? productId,
  }) async => movements;

  @override
  Future<InventoryMovement> createInventoryMovement(
    InventoryMovement movement,
  ) async {
    createMovementCalls.add(movement);
    return createMovementResult!;
  }
}
