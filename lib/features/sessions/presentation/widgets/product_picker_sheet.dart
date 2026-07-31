import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/utils/session_presentation_utils.dart';

Future<void> showProductPickerSheet(
  BuildContext context, {
  required String sessionId,
  required String currencyCode,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      ProductPickerSheet(sessionId: sessionId, currencyCode: currencyCode),
);

class ProductPickerSheet extends ConsumerStatefulWidget {
  const ProductPickerSheet({
    required this.sessionId,
    required this.currencyCode,
    super.key,
  });

  final String sessionId;
  final String currencyCode;

  @override
  ConsumerState<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<ProductPickerSheet> {
  String _query = '';
  Product? _selectedProduct;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(activeBusinessScopeProvider);
    final productsProvider = productsListControllerProvider(scope);
    final productsAsync = ref.watch(productsProvider);
    final action = ref.watch(sessionActionsControllerProvider);
    final selected = _selectedProduct;
    // Client-side ön kontrol; kesin doğrulama yine DB'de (insufficient_stock).
    final exceedsStock =
        selected != null &&
        selected.trackStock &&
        _quantity > selected.stockQuantity;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Ürün ekle', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Ürün ara',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (error, _) => AppErrorState(
                  error: error,
                  fallbackMessage: 'Ürünler yüklenemedi.',
                  onRetry: () => ref.read(productsProvider.notifier).refresh(),
                  padding: const EdgeInsets.all(16),
                  iconSize: 40,
                ),
                data: (state) {
                  final normalized = _query.trim().toLowerCase();
                  final products = state.products
                      .where((product) {
                        if (!product.isActive ||
                            product.currencyCode != widget.currencyCode) {
                          return false;
                        }
                        return normalized.isEmpty ||
                            product.name.toLowerCase().contains(normalized) ||
                            (product.sku?.toLowerCase().contains(normalized) ??
                                false);
                      })
                      .toList(growable: false);
                  if (products.isEmpty) {
                    return const _PickerMessage(
                      message:
                          'Uygun ürün bulunamadı. Arama metnini değiştirin veya ürün tanımlarını kontrol edin.',
                    );
                  }
                  return ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _ProductTile(
                      product: products[index],
                      selected: _selectedProduct?.id == products[index].id,
                      onTap: () => setState(() {
                        _selectedProduct = products[index];
                        _quantity = 1;
                      }),
                    ),
                  );
                },
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed: _quantity == 1
                        ? null
                        : () => setState(() => _quantity--),
                    icon: const Icon(Icons.remove),
                    tooltip: 'Adedi azalt',
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton.outlined(
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    onPressed:
                        selected.trackStock &&
                            _quantity >= selected.stockQuantity
                        ? null
                        : () => setState(() => _quantity++),
                    icon: const Icon(Icons.add),
                    tooltip: 'Adedi artır',
                  ),
                ],
              ),
              if (exceedsStock) ...[
                const SizedBox(height: 8),
                Text(
                  'Stokta yalnızca ${selected.stockQuantity} adet var.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: action.isLoading || exceedsStock
                    ? null
                    : _addProduct,
                icon: action.isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.add_shopping_cart_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('İşleme Ekle'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addProduct() async {
    final product = _selectedProduct;
    if (product == null) return;
    final success = await ref
        .read(sessionActionsControllerProvider.notifier)
        .addProduct(
          sessionId: widget.sessionId,
          product: product,
          quantity: _quantity,
        );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      return;
    }
    final error = ref.read(sessionActionsControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is DomainException
              ? error.message
              : 'Ürün eklenemedi. Lütfen tekrar deneyin.',
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  final Product product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      selected: selected,
      onTap: onTap,
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text(product.name),
      subtitle: Text(
        '${product.trackStock ? 'Stok: ${product.stockQuantity}' : 'Stok takibi yok'} · '
        '${formatSessionMoney(product.unitPriceMinor, product.currencyCode)}',
      ),
    ),
  );
}

class _PickerMessage extends StatelessWidget {
  const _PickerMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Text(message, textAlign: TextAlign.center)],
      ),
    ),
  );
}
