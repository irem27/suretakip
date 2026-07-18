import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:intl/intl.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/products/presentation/utils/product_presentation_utils.dart';
import 'package:suretakip/features/products/presentation/widgets/product_status_chip.dart';

class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(productDetailProvider(productId));
    final canManageCatalog =
        ref.watch(businessCapabilitiesProvider).valueOrNull?.canManageCatalog ??
        false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Detayı'),
        actions: [
          if (canManageCatalog)
            TextButton.icon(
              onPressed: detail.hasValue
                  ? () => context.pushNamed(
                      AppRouteNames.productEdit,
                      pathParameters: {'productId': productId},
                    )
                  : null,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Düzenle'),
            ),
        ],
      ),
      body: SafeArea(
        child: detail.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => AppErrorState(
            error: error,
            fallbackMessage: productErrorMessage(
              error,
              'Ürün detayı yüklenemedi. Lütfen tekrar deneyin.',
            ),
            onRetry: () => ref.invalidate(productDetailProvider(productId)),
          ),
          data: (product) =>
              _Content(product: product, canManageCatalog: canManageCatalog),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.product, required this.canManageCatalog});

  final Product product;
  final bool canManageCatalog;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final willActivate = !product.isActive;
    final ok = await ref
        .read(productFormControllerProvider.notifier)
        .setActive(product.id, isActive: willActivate);
    if (!context.mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          willActivate
              ? 'Ürün yeniden aktifleştirildi.'
              : 'Ürün pasife alındı.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitState = ref.watch(productFormControllerProvider);
    ref.listen(productFormControllerProvider, (_, next) {
      if (!next.hasError) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            productErrorMessage(next.error, 'Ürün durumu değiştirilemedi.'),
          ),
        ),
      );
    });
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ProductStatusChip(isActive: product.isActive),
                ),
                const SizedBox(height: 16),
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  formatProductMoney(
                    product.unitPriceMinor,
                    product.currencyCode,
                  ),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Divider(height: 36),
                _Row(label: 'Stok kodu', value: product.sku ?? '—'),
                const SizedBox(height: 16),
                _Row(
                  label: 'Stok takibi',
                  value: product.trackStock ? 'Açık' : 'Kapalı',
                ),
                const SizedBox(height: 16),
                _Row(
                  label: 'Stok miktarı',
                  value: product.stockQuantity.toString(),
                ),
                const SizedBox(height: 16),
                _Row(
                  label: 'Son güncelleme',
                  value: DateFormat(
                    'dd.MM.yyyy HH:mm',
                  ).format(product.updatedAt.toLocal()),
                ),
              ],
            ),
          ),
        ),
        if (canManageCatalog) const SizedBox(height: 16),
        if (canManageCatalog)
          OutlinedButton.icon(
            onPressed: submitState.isLoading
                ? null
                : () => _toggle(context, ref),
            icon: Icon(
              product.isActive
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            label: Text(product.isActive ? 'Pasife Al' : 'Aktifleştir'),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}
