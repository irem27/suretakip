import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/widgets/product_picker_sheet.dart';

void main() {
  testWidgets('yalnız aktif ve aynı para birimindeki ürünleri gösterir', (
    tester,
  ) async {
    await _openSheet(
      tester,
      products: [
        _product(),
        _product(id: 'product-4', name: 'Jeton', trackStock: false),
        _product(id: 'product-2', name: 'Pasif Ürün', isActive: false),
        _product(id: 'product-3', name: 'Dolar Ürün', currencyCode: 'USD'),
      ],
    );

    expect(find.text('Maden Suyu'), findsOneWidget);
    expect(find.text('Stok: 2 · ₺12,50'), findsOneWidget);
    expect(find.text('Stok takibi yok · ₺12,50'), findsOneWidget);
    expect(find.text('Pasif Ürün'), findsNothing);
    expect(find.text('Dolar Ürün'), findsNothing);

    await tester.enterText(find.byType(TextField), 'MS-01');
    await tester.pump();
    expect(find.text('Maden Suyu'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'eşleşmez');
    await tester.pump();
    expect(
      find.text(
        'Uygun ürün bulunamadı. Arama metnini değiştirin veya ürün tanımlarını kontrol edin.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('adet kontrolleri erişilebilir ve ekleme girdilerini iletir', (
    tester,
  ) async {
    final actions = _SessionActionsController();
    await _openSheet(
      tester,
      products: [_product()],
      actionsController: actions,
    );

    await tester.tap(find.text('Maden Suyu'));
    await tester.pump();

    final decrease = find.byTooltip('Adedi azalt');
    final increase = find.byTooltip('Adedi artır');
    expect(decrease, findsOneWidget);
    expect(increase, findsOneWidget);
    expect(tester.getSize(decrease), const Size(48, 48));
    expect(tester.getSize(increase), const Size(48, 48));
    expect(find.text('1'), findsOneWidget);

    await tester.tap(increase);
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'İşleme Ekle'));
    await tester.pumpAndSettle();

    expect(actions.sessionId, 'session-1');
    expect(actions.product?.id, 'product-1');
    expect(actions.quantity, 2);
    expect(find.text('Ürün ekle'), findsNothing);
  });

  testWidgets('ürün olmadığında yönlendirici boş durum görünür', (
    tester,
  ) async {
    await _openSheet(tester, products: const []);

    expect(
      find.text(
        'Uygun ürün bulunamadı. Arama metnini değiştirin veya ürün tanımlarını kontrol edin.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('yükleme hatası Tekrar Dene aksiyonu sunar', (tester) async {
    final productsController = _ProductsListController.error();
    await _openSheet(tester, productsController: productsController);

    expect(find.text('Ürünler yüklenemedi.'), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, 'Tekrar Dene');
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pump();

    expect(productsController.refreshCount, 1);
  });

  testWidgets('ekleme hatası kullanıcı mesajını snackbar içinde gösterir', (
    tester,
  ) async {
    final actions = _SessionActionsController(
      error: const ValidationException('Stok yetersiz.'),
    );
    await _openSheet(
      tester,
      products: [_product()],
      actionsController: actions,
    );
    await tester.tap(find.text('Maden Suyu'));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'İşleme Ekle'));
    await tester.pump();

    expect(find.text('Stok yetersiz.'), findsOneWidget);
  });
}

Future<void> _openSheet(
  WidgetTester tester, {
  List<Product>? products,
  _ProductsListController? productsController,
  _SessionActionsController? actionsController,
}) async {
  final effectiveProducts =
      productsController ?? _ProductsListController(products!);
  final effectiveActions = actionsController ?? _SessionActionsController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productsListControllerProvider.overrideWith(() => effectiveProducts),
        sessionActionsControllerProvider.overrideWith(() => effectiveActions),
      ],
      child: const MaterialApp(home: _Host()),
    ),
  );
  await tester.tap(find.text('Ürün seçiciyi aç'));
  await tester.pumpAndSettle();
}

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => showProductPickerSheet(
          context,
          sessionId: 'session-1',
          currencyCode: 'TRY',
        ),
        child: const Text('Ürün seçiciyi aç'),
      ),
    ),
  );
}

class _ProductsListController extends ProductsListController {
  _ProductsListController(this.products) : error = null;

  _ProductsListController.error()
    : products = const [],
      error = StateError('ürün yükleme hatası');

  final List<Product> products;
  final Object? error;
  int refreshCount = 0;

  @override
  Future<ProductsListState> build(BusinessScope scope) async {
    if (error != null) throw error!;
    return ProductsListState(
      products: products,
      filter: ProductStatusFilter.all,
    );
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

class _SessionActionsController extends SessionActionsController {
  _SessionActionsController({this.error});

  final Object? error;
  String? sessionId;
  Product? product;
  int? quantity;

  @override
  Future<void> build() async {}

  @override
  Future<bool> addProduct({
    required String sessionId,
    required Product product,
    required int quantity,
    int discountMinor = 0,
    int taxMinor = 0,
  }) async {
    this.sessionId = sessionId;
    this.product = product;
    this.quantity = quantity;
    if (error == null) return true;
    state = AsyncError(error!, StackTrace.empty);
    return false;
  }
}

Product _product({
  String id = 'product-1',
  String name = 'Maden Suyu',
  String currencyCode = 'TRY',
  bool isActive = true,
  bool trackStock = true,
}) => Product(
  id: id,
  businessId: 'business-1',
  name: name,
  sku: 'MS-01',
  unitPriceMinor: 1250,
  currencyCode: currencyCode,
  trackStock: trackStock,
  stockQuantity: 2,
  isActive: isActive,
  archivedAt: isActive ? null : DateTime.utc(2026, 7, 18),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 7, 18),
);
