import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';

enum ProductStatusFilter { all, active, inactive }

final class ProductsListState {
  const ProductsListState({required this.products, required this.filter});

  final List<Product> products;
  final ProductStatusFilter filter;

  List<Product> get visibleProducts => switch (filter) {
    ProductStatusFilter.all => products,
    ProductStatusFilter.active =>
      products.where((product) => product.isActive).toList(growable: false),
    ProductStatusFilter.inactive =>
      products.where((product) => !product.isActive).toList(growable: false),
  };

  ProductsListState copyWith({
    List<Product>? products,
    ProductStatusFilter? filter,
  }) => ProductsListState(
    products: products ?? this.products,
    filter: filter ?? this.filter,
  );
}

class ProductsListController
    extends AutoDisposeFamilyAsyncNotifier<ProductsListState, BusinessScope> {
  var _filter = ProductStatusFilter.all;
  late BusinessScope _scope;

  @override
  Future<ProductsListState> build(BusinessScope scope) {
    _scope = scope;
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<ProductsListState>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<void> setFilter(ProductStatusFilter filter) async {
    if (_filter == filter && state.hasValue) return;
    _filter = filter;
    state = const AsyncLoading<ProductsListState>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<ProductsListState> _load() async {
    final businessId = _scope.businessId;
    if (businessId == null) {
      return ProductsListState(products: const [], filter: _filter);
    }
    final products = await ref
        .watch(productsRepositoryProvider)
        .getProducts(
          businessId: businessId,
          includeInactive: _filter != ProductStatusFilter.active,
        );
    return ProductsListState(products: products, filter: _filter);
  }
}

class ProductFormController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Product?> create(ProductInput input) async {
    Product? created;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      created = await ref.read(productsRepositoryProvider).createProduct(input);
      ref.invalidate(
        productsListControllerProvider(ref.read(activeBusinessScopeProvider)),
      );
    });
    return state.hasError ? null : created;
  }

  Future<Product?> updateProduct(Product product) async {
    Product? updated;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      updated = await ref
          .read(productsRepositoryProvider)
          .updateProduct(product);
      ref.invalidate(
        productsListControllerProvider(ref.read(activeBusinessScopeProvider)),
      );
      ref.invalidate(productDetailProvider(product.id));
    });
    return state.hasError ? null : updated;
  }

  /// Aktif/pasif toggle. İşlemdeki ürün id'si `productUpdatingIdProvider`'a
  /// yazılır ki liste yalnızca o kartın anahtarını kilitlesin (tüm liste değil).
  Future<bool> setActive(String productId, {required bool isActive}) async {
    ref.read(productUpdatingIdProvider.notifier).state = productId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(productsRepositoryProvider)
          .setProductActive(productId, isActive: isActive);
      ref.invalidate(
        productsListControllerProvider(ref.read(activeBusinessScopeProvider)),
      );
      ref.invalidate(productDetailProvider(productId));
    });
    // AsyncValue.guard rethrow etmez; başarı/hata fark etmeksizin id temizlenir.
    ref.read(productUpdatingIdProvider.notifier).state = null;
    return !state.hasError;
  }
}

/// setActive sırasında güncellenen ürünün id'si; yalnızca ilgili kartın
/// anahtarını devre dışı bırakmak için liste tarafından okunur.
final productUpdatingIdProvider = StateProvider<String?>((ref) => null);

final productsListControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ProductsListController, ProductsListState, BusinessScope>(
      ProductsListController.new,
    );

final productFormControllerProvider =
    AsyncNotifierProvider<ProductFormController, void>(
      ProductFormController.new,
    );

final productDetailProvider = FutureProvider.autoDispose
    .family<Product, String>(
      (ref, productId) =>
          ref.watch(productsRepositoryProvider).getProduct(productId),
    );
