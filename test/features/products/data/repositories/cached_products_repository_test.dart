import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
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

  test('çevrimiçi getProducts sunucudan döner ve önbelleğe yazar', () async {
    remote.products = [_product('p1'), _product('p2')];
    final result = await repo.getProducts(businessId: 'b1');
    expect(result.map((p) => p.id), ['p1', 'p2']);
  });

  test('ağ hatasında getProducts önbellekten okur', () async {
    remote.products = [_product('p1')];
    await repo.getProducts(businessId: 'b1');

    remote.throwNetwork = true;
    final cached = await repo.getProducts(businessId: 'b1');
    expect(cached.single.id, 'p1');
  });

  test('önbellek boşken ağ hatasında getProducts hatayı yükseltir', () async {
    // Boş önbellek + çevrimdışı: boş liste "ürün yok" gibi maskelenmemeli.
    remote.throwNetwork = true;
    expect(
      repo.getProducts(businessId: 'b1'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('önbellek varsa ürünleri uzak yanıtı beklemeden döndürür', () async {
    await local.replaceProducts('b1', [_product('cached')]);
    remote.productsCompleter = Completer<List<Product>>();

    final result = await repo
        .getProducts(businessId: 'b1')
        .timeout(const Duration(milliseconds: 100));

    expect(result.single.id, 'cached');
    remote.productsCompleter!.complete([_product('fresh')]);
    await Future<void>.delayed(Duration.zero);
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

class _FakeRemote implements ProductsRepository {
  List<Product> products = const [];
  bool throwNetwork = false;
  Completer<List<Product>>? productsCompleter;

  @override
  Future<List<Product>> getProducts({
    required String businessId,
    bool includeInactive = false,
  }) async {
    if (throwNetwork) throw const NetworkException('çevrimdışı');
    final completer = productsCompleter;
    if (completer != null) return completer.future;
    return products;
  }

  @override
  Future<Product> getProduct(String productId) async {
    if (throwNetwork) throw const NetworkException('çevrimdışı');
    return products.firstWhere((p) => p.id == productId);
  }

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
  }) => throw UnimplementedError();

  @override
  Future<InventoryMovement> createInventoryMovement(
    InventoryMovement movement,
  ) => throw UnimplementedError();
}
