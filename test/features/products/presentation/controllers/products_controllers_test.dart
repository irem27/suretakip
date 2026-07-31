import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/products/domain/entities/inventory_movement.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';
import 'package:suretakip/features/products/domain/repositories/products_repository.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';

void main() {
  test('liste controller aktif işletmenin tüm ürünlerini yükler', () async {
    final repository = _FakeProductsRepository(products: [_product()]);
    final container = _container(repository);
    addTearDown(container.dispose);

    final state = await container.read(
      productsListControllerProvider(_scope).future,
    );

    expect(state.products, hasLength(1));
    expect(repository.businessId, 'business-1');
    expect(repository.includeInactive, isTrue);
  });

  test('pasif filtre immutable state ile uygulanır', () async {
    final repository = _FakeProductsRepository(
      products: [
        _product(),
        _product(id: 'product-2', isActive: false),
      ],
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final provider = productsListControllerProvider(_scope);
    final subscription = container.listen(
      provider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(provider.future);

    await container
        .read(provider.notifier)
        .setFilter(ProductStatusFilter.inactive);

    final state = container.read(provider).requireValue;
    expect(state.visibleProducts.single.id, 'product-2');
  });

  test('form controller ProductInput ile ürün oluşturur', () async {
    final repository = _FakeProductsRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final input = ProductInput(
      businessId: 'business-1',
      name: 'Kola',
      sku: 'K-1',
      unitPrice: Money(minorUnits: 5000, currencyCode: 'TRY'),
      trackStock: true,
      stockQuantity: 12,
    );

    final created = await container
        .read(productFormControllerProvider.notifier)
        .create(input);

    expect(created?.id, 'product-1');
    expect(repository.createdInput, same(input));
  });

  test('setActive yalnız id ve durumu iletir', () async {
    final repository = _FakeProductsRepository(products: [_product()]);
    final container = _container(repository);
    addTearDown(container.dispose);

    final ok = await container
        .read(productFormControllerProvider.notifier)
        .setActive('product-1', isActive: false);

    expect(ok, isTrue);
    expect(repository.toggledId, 'product-1');
    expect(repository.toggledActive, isFalse);
    expect(repository.updatedProduct, isNull);
  });

  test(
    'setActive sırasında productUpdatingIdProvider yalnız o id olur, sonra null',
    () async {
      final repository = _FakeProductsRepository(products: [_product()])
        ..toggleGate = Completer<void>();
      final container = _container(repository);
      addTearDown(container.dispose);

      final future = container
          .read(productFormControllerProvider.notifier)
          .setActive('product-1', isActive: false);
      expect(container.read(productUpdatingIdProvider), 'product-1');

      repository.toggleGate!.complete();
      await future;
      expect(container.read(productUpdatingIdProvider), isNull);
    },
  );
}

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

ProviderContainer _container(_FakeProductsRepository repository) =>
    ProviderContainer(
      overrides: [
        productsRepositoryProvider.overrideWithValue(repository),
        activeBusinessProvider.overrideWithValue(_business()),
      ],
    );

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
  String? businessId;
  bool? includeInactive;
  ProductInput? createdInput;
  Product? updatedProduct;
  String? toggledId;
  bool? toggledActive;
  Completer<void>? toggleGate;

  @override
  Future<Product> createProduct(ProductInput input) async {
    createdInput = input;
    return _product().copyWith(
      name: input.name,
      sku: input.sku,
      unitPriceMinor: input.unitPrice.minorUnits,
      currencyCode: input.unitPrice.currencyCode,
      trackStock: input.trackStock,
      stockQuantity: input.stockQuantity,
    );
  }

  @override
  Future<Product> getProduct(String productId) async =>
      products.firstWhere((product) => product.id == productId);

  @override
  Future<List<Product>> getProducts({
    required String businessId,
    bool includeInactive = false,
  }) async {
    this.businessId = businessId;
    this.includeInactive = includeInactive;
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
  }) async {
    toggledId = productId;
    toggledActive = isActive;
    if (toggleGate != null) await toggleGate!.future;
    return products
        .firstWhere((product) => product.id == productId)
        .copyWith(isActive: isActive);
  }

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
