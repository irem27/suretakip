import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/products/domain/entities/inventory_movement.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';
import 'package:suretakip/features/products/domain/repositories/products_repository.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

void main() {
  test('işletme yoksa boş liste döner', () async {
    final container = ProviderContainer(
      overrides: [activeBusinessProvider.overrideWithValue(_business())],
    );
    addTearDown(container.dispose);
    const scope = (businessId: null, generation: 0);

    final state = await container.read(
      productsListControllerProvider(scope).future,
    );

    expect(state.products, isEmpty);
  });

  test('refresh liste yeniden yüklenir', () async {
    final repository = _FakeProductsRepository(products: [_product()]);
    final container = ProviderContainer(
      overrides: [
        productsRepositoryProvider.overrideWithValue(repository),
        activeBusinessProvider.overrideWithValue(_business()),
      ],
    );
    addTearDown(container.dispose);
    final provider = productsListControllerProvider(_scope);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);

    await container.read(provider.notifier).refresh();

    expect(repository.loadCount, 2);
  });

  test('aynı filtre tekrar uygulanırsa erken döner', () async {
    final repository = _FakeProductsRepository(products: [_product()]);
    final container = ProviderContainer(
      overrides: [
        productsRepositoryProvider.overrideWithValue(repository),
        activeBusinessProvider.overrideWithValue(_business()),
      ],
    );
    addTearDown(container.dispose);
    final provider = productsListControllerProvider(_scope);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    expect(repository.loadCount, 1);

    await container.read(provider.notifier).setFilter(ProductStatusFilter.all);

    expect(repository.loadCount, 1);
  });

  test('form controller ürünü günceller', () async {
    final repository = _FakeProductsRepository(products: [_product()]);
    final container = ProviderContainer(
      overrides: [
        productsRepositoryProvider.overrideWithValue(repository),
        activeBusinessProvider.overrideWithValue(_business()),
      ],
    );
    addTearDown(container.dispose);

    final updated = await container
        .read(productFormControllerProvider.notifier)
        .updateProduct(_product().copyWith(name: 'Kola Zero'));

    expect(updated?.name, 'Kola Zero');
    expect(repository.updatedProduct?.name, 'Kola Zero');
  });
}

Business _business() => Business(
  id: 'business-1',
  name: 'Test İşletmesi',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Product _product({String id = 'product-1', bool isActive = true}) => Product(
  id: id,
  businessId: 'business-1',
  name: 'Kola',
  sku: 'K-1',
  unitPriceMinor: 5000,
  currencyCode: 'TRY',
  trackStock: true,
  stockQuantity: 12,
  isActive: isActive,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _FakeProductsRepository implements ProductsRepository {
  _FakeProductsRepository({List<Product>? products})
    : products = products ?? [_product()];

  final List<Product> products;
  Product? updatedProduct;
  var loadCount = 0;

  @override
  Future<Product> createProduct(ProductInput input) =>
      throw UnimplementedError();

  @override
  Future<Product> getProduct(String productId) async =>
      products.firstWhere((product) => product.id == productId);

  @override
  Future<List<Product>> getProducts({
    required String businessId,
    bool includeInactive = false,
  }) async {
    loadCount++;
    return includeInactive
        ? products
        : products.where((product) => product.isActive).toList();
  }

  @override
  Future<Product> updateProduct(Product product) async {
    updatedProduct = product;
    return product;
  }

  @override
  Future<Product> setProductActive(
    String productId, {
    required bool isActive,
  }) => throw UnimplementedError();

  @override
  Future<InventoryMovement> createInventoryMovement(
    InventoryMovement movement,
  ) async => movement;

  @override
  Future<List<InventoryMovement>> getInventoryMovements({
    required String businessId,
    String? productId,
  }) async => const [];
}
