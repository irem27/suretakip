import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/core/presentation/widgets/app_back_button.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/utils/form_validators.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/products/presentation/utils/product_presentation_utils.dart';

class ProductFormPage extends ConsumerWidget {
  const ProductFormPage({this.productId, super.key});

  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = productId;
    if (id == null) return const _ProductForm();
    return ref
        .watch(productDetailProvider(id))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(
                fallbackRouteName: AppRouteNames.products,
              ),
              title: const Text('Ürünü Düzenle'),
            ),
            body: const Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(
                fallbackRouteName: AppRouteNames.products,
              ),
              title: const Text('Ürünü Düzenle'),
            ),
            body: _LoadError(error: error, productId: id),
          ),
          data: (product) => _ProductForm(product: product),
        );
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({this.product});

  final Product? product;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late bool _trackStock;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name);
    _skuController = TextEditingController(text: product?.sku);
    _priceController = TextEditingController(
      text: product == null
          ? ''
          : productMinorUnitsToInput(product.unitPriceMinor),
    );
    _stockController = TextEditingController(
      text: (product?.stockQuantity ?? 0).toString(),
    );
    _trackStock = product?.trackStock ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  String? _stockValidator(String? value) {
    final stock = int.tryParse(value?.trim() ?? '');
    if (stock == null || stock < 0) return 'Stok sıfır veya daha büyük olmalı.';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final priceMinor = FormValidators.moneyToMinor(_priceController.text);
    final stock = int.parse(_stockController.text.trim());
    final sku = _skuController.text.trim();
    final controller = ref.read(productFormControllerProvider.notifier);
    final current = widget.product;
    Product? result;
    if (current == null) {
      final business = ref.read(activeBusinessProvider);
      if (business == null) {
        _showMessage('Aktif işletme bulunamadı. Lütfen tekrar giriş yapın.');
        return;
      }
      result = await controller.create(
        ProductInput(
          businessId: business.id,
          name: _nameController.text.trim(),
          sku: sku.isEmpty ? null : sku,
          unitPrice: Money(
            minorUnits: priceMinor,
            currencyCode: business.currencyCode,
          ),
          trackStock: _trackStock,
          stockQuantity: stock,
        ),
      );
    } else {
      result = await controller.updateProduct(
        current.copyWith(
          name: _nameController.text.trim(),
          sku: sku.isEmpty ? null : sku,
          unitPriceMinor: priceMinor,
          trackStock: _trackStock,
          stockQuantity: stock,
        ),
      );
    }
    if (!mounted || result == null) return;
    if (_isEditing) {
      context.pop();
      return;
    }
    context.pushReplacementNamed(
      AppRouteNames.productDetail,
      pathParameters: {'productId': result.id},
    );
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(productFormControllerProvider);
    final business = ref.watch(activeBusinessProvider);
    final currencyCode = widget.product?.currencyCode ?? business?.currencyCode;
    ref.listen(productFormControllerProvider, (_, next) {
      if (!next.hasError) return;
      _showMessage(
        productErrorMessage(
          next.error,
          'Ürün kaydedilemedi. Lütfen tekrar deneyin.',
        ),
      );
    });
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRouteName: AppRouteNames.products),
        title: Text(_isEditing ? 'Ürünü Düzenle' : 'Yeni Ürün'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
            children: [
              _Section(
                title: 'Ürün Bilgileri',
                icon: Icons.inventory_2_outlined,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      maxLength: AppConstants.maximumNameLength,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Ürün adı'),
                      validator: (value) =>
                          FormValidators.requiredName(value, 'Ürün adı'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _skuController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Stok kodu (isteğe bağlı)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Satış fiyatı',
                        helperText: currencyCode == null
                            ? null
                            : 'İşletme para birimi: $currencyCode',
                      ),
                      validator: (value) =>
                          FormValidators.positiveMoney(value, 'Satış fiyatı'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Stok',
                icon: Icons.warehouse_outlined,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _trackStock,
                      onChanged: (value) => setState(() => _trackStock = value),
                      title: const Text('Stok takibi'),
                      subtitle: const Text('Ürün miktarını takip et'),
                    ),
                    TextFormField(
                      controller: _stockController,
                      enabled: _trackStock && !_isEditing,
                      readOnly: _isEditing,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: _isEditing
                            ? 'Mevcut stok'
                            : 'Başlangıç stoğu',
                        helperText: _isEditing
                            ? 'Stok, stok hareketleriyle değişir; buradan düzenlenmez.'
                            : null,
                      ),
                      validator: _isEditing ? null : _stockValidator,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: submitState.isLoading ? null : _submit,
            icon: submitState.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isEditing ? 'Değişiklikleri Kaydet' : 'Ürünü Kaydet'),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const Divider(height: 28),
          child,
        ],
      ),
    ),
  );
}

class _LoadError extends ConsumerWidget {
  const _LoadError({required this.error, required this.productId});

  final Object error;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppErrorState(
    error: error,
    fallbackMessage: productErrorMessage(error, 'Ürün bilgileri yüklenemedi.'),
    onRetry: () => ref.invalidate(productDetailProvider(productId)),
    padding: const EdgeInsets.all(32),
  );
}
