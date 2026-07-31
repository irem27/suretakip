import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/presentation/widgets/app_back_button.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/products/presentation/utils/product_presentation_utils.dart';
import 'package:suretakip/features/products/presentation/widgets/product_status_chip.dart';

class ProductsListPage extends ConsumerStatefulWidget {
  const ProductsListPage({super.key});

  @override
  ConsumerState<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends ConsumerState<ProductsListPage> {
  final _searchController = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(activeBusinessScopeProvider);
    final listProvider = productsListControllerProvider(scope);
    final listState = ref.watch(listProvider);
    final formState = ref.watch(productFormControllerProvider);
    // Yalnızca setActive işlemindeki ürünün anahtarını kilitlemek için.
    final updatingProductId = ref.watch(productUpdatingIdProvider);
    final canManageCatalog =
        ref.watch(businessCapabilitiesProvider).valueOrNull?.canManageCatalog ??
        false;
    ref.listen(productFormControllerProvider, (_, next) {
      if (!next.hasError) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            productErrorMessage(
              next.error,
              'Ürün durumu değiştirilemedi. Lütfen tekrar deneyin.',
            ),
          ),
        ),
      );
    });
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(
          fallbackRouteName: AppRouteNames.definitions,
        ),
        title: const Text('Ürünler'),
      ),
      floatingActionButton: canManageCatalog
          ? FloatingActionButton.extended(
              onPressed: () => context.pushNamed(AppRouteNames.productCreate),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yeni Ürün'),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(listProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  searchController: _searchController,
                  onSearchChanged: (value) => setState(() => _query = value),
                  state: listState.valueOrNull,
                  onFilterChanged: (filter) =>
                      ref.read(listProvider.notifier).setFilter(filter),
                ),
              ),
              ...listState.when(
                loading: () => const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                ],
                error: (error, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppErrorState(
                      error: error,
                      fallbackMessage: productErrorMessage(
                        error,
                        'Ürünler yüklenemedi. Lütfen tekrar deneyin.',
                      ),
                      onRetry: () => ref.read(listProvider.notifier).refresh(),
                      padding: const EdgeInsets.all(32),
                      iconSize: 52,
                    ),
                  ),
                ],
                data: (state) {
                  final query = _query.trim().toLowerCase();
                  final products = state.visibleProducts
                      .where(
                        (product) =>
                            product.name.toLowerCase().contains(query) ||
                            (product.sku?.toLowerCase().contains(query) ??
                                false),
                      )
                      .toList(growable: false);
                  if (products.isEmpty) {
                    return const [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MessageState(
                          icon: Icons.inventory_2_outlined,
                          message:
                              'Eşleşen ürün bulunamadı. Aramayı değiştirin veya Yeni Ürün düğmesiyle kayıt ekleyin.',
                        ),
                      ),
                    ];
                  }
                  return [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                      sliver: SliverList.separated(
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _ProductCard(
                          product: products[index],
                          isUpdating:
                              formState.isLoading &&
                              updatingProductId == products[index].id,
                          onTap: () => context.pushNamed(
                            AppRouteNames.productDetail,
                            pathParameters: {'productId': products[index].id},
                          ),
                          onStatusChanged: canManageCatalog
                              ? (isActive) => ref
                                    .read(
                                      productFormControllerProvider.notifier,
                                    )
                                    .setActive(
                                      products[index].id,
                                      isActive: isActive,
                                    )
                              : null,
                        ),
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.searchController,
    required this.onSearchChanged,
    required this.state,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ProductsListState? state;
  final ValueChanged<ProductStatusFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Ürün adı veya stok kodu ara',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: ProductStatusFilter.values
              .map(
                (filter) => ChoiceChip(
                  label: Text(switch (filter) {
                    ProductStatusFilter.all => 'Tümü',
                    ProductStatusFilter.active => 'Aktif',
                    ProductStatusFilter.inactive => 'Pasif',
                  }),
                  selected:
                      (state?.filter ?? ProductStatusFilter.all) == filter,
                  onSelected: (_) => onFilterChanged(filter),
                ),
              )
              .toList(growable: false),
        ),
      ],
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isUpdating,
    required this.onTap,
    required this.onStatusChanged,
  });

  final Product product;
  final bool isUpdating;
  final VoidCallback onTap;
  final ValueChanged<bool>? onStatusChanged;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: product.isActive ? 1 : 0.68,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (product.sku != null) Text('Kod: ${product.sku}'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: ProductStatusChip(isActive: product.isActive),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    formatProductMoney(
                      product.unitPriceMinor,
                      product.currencyCode,
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    product.trackStock
                        ? 'Stok: ${product.stockQuantity}'
                        : 'Stok takibi kapalı',
                  ),
                  // MergeSemantics şart: onsuz Switch'in kendi düğümü adsız kalır.
                  MergeSemantics(
                    child: Semantics(
                      label: '${product.name} aktif durumu',
                      toggled: product.isActive,
                      child: Switch.adaptive(
                        value: product.isActive,
                        onChanged: isUpdating ? null : onStatusChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
