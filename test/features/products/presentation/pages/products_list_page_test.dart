import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/businesses/domain/entities/business_capabilities.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/products/presentation/pages/products_list_page.dart';

void main() {
  testWidgets('boş liste Türkçe yönlendirme metnini gösterir', (tester) async {
    await _pump(tester, products: const []);

    expect(
      find.text(
        'Eşleşen ürün bulunamadı. Aramayı değiştirin veya Yeni Ürün düğmesiyle kayıt ekleyin.',
      ),
      findsOneWidget,
    );
    expect(find.text('Yeni Ürün'), findsOneWidget);
  });

  testWidgets(
    'ürün bilgileri, minor-unit fiyatı ve erişilebilir anahtar görünür',
    (tester) async {
      await _pump(
        tester,
        products: [
          _product(),
          _product(
            id: 'product-2',
            name: 'Pasif Kola',
            sku: null,
            isActive: false,
            trackStock: false,
            // Varsayılan fiyattan farklı: aynı olsaydı fiyat metni iki kez
            // eşleşir ve findsOneWidget belirsizleşirdi.
            unitPriceMinor: 5000,
          ),
        ],
      );

      expect(find.text('Maden Suyu'), findsOneWidget);
      expect(find.text('Kod: MS-01'), findsOneWidget);
      expect(find.text('₺123,45'), findsOneWidget);
      expect(find.text('Stok: 8'), findsOneWidget);
      expect(find.text('Stok takibi kapalı'), findsOneWidget);
      expect(find.bySemanticsLabel('Maden Suyu aktif durumu'), findsOneWidget);
      expect(
        tester.getSize(find.byType(Switch).first).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester
            .getSize(find.widgetWithText(FloatingActionButton, 'Yeni Ürün'))
            .height,
        greaterThanOrEqualTo(48),
      );
    },
  );

  testWidgets('arama stok koduna göre daraltır ve pasif filtreyi uygular', (
    tester,
  ) async {
    final listController = _ProductsListController([
      _product(),
      _product(
        id: 'product-2',
        name: 'Pasif Kola',
        sku: 'PK-02',
        isActive: false,
      ),
    ]);
    await _pump(tester, listController: listController);

    await tester.enterText(find.byType(TextField), 'MS-01');
    await tester.pump();

    expect(find.text('Maden Suyu'), findsOneWidget);
    expect(find.text('Pasif Kola'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pasif'));
    await tester.pump();

    expect(listController.selectedFilter, ProductStatusFilter.inactive);
    expect(find.text('Maden Suyu'), findsNothing);
    expect(find.text('Pasif Kola'), findsOneWidget);
  });

  testWidgets('durum anahtarı ürün kimliği ve yeni durumu iletir', (
    tester,
  ) async {
    final formController = _ProductFormController();
    await _pump(tester, products: [_product()], formController: formController);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(formController.productId, 'product-1');
    expect(formController.isActive, isFalse);
  });

  testWidgets('yükleme hatası metni ve Tekrar Dene aksiyonu görünür', (
    tester,
  ) async {
    final listController = _ProductsListController.error();
    await _pump(tester, listController: listController);

    expect(
      find.text('Ürünler yüklenemedi. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
    final retry = find.widgetWithText(OutlinedButton, 'Tekrar Dene');
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pump();

    expect(listController.refreshCount, 1);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  List<Product>? products,
  _ProductsListController? listController,
  _ProductFormController? formController,
}) async {
  final effectiveList = listController ?? _ProductsListController(products!);
  final effectiveForm = formController ?? _ProductFormController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessCapabilitiesProvider.overrideWithValue(_managerCapabilities),
        productsListControllerProvider.overrideWith(() => effectiveList),
        productFormControllerProvider.overrideWith(() => effectiveForm),
      ],
      child: const MaterialApp(home: ProductsListPage()),
    ),
  );
  await tester.pumpAndSettle();
}

const _managerCapabilities = AsyncData(
  BusinessCapabilities(
    canManageCatalog: true,
    canManageMembers: true,
    canEditBusinessSettings: true,
    canCancelCompletedSession: true,
  ),
);

class _ProductsListController extends ProductsListController {
  _ProductsListController(this.products) : error = null;

  _ProductsListController.error()
    : products = const [],
      error = StateError('ürün hatası');

  final List<Product> products;
  final Object? error;
  ProductStatusFilter? selectedFilter;
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
  Future<void> setFilter(ProductStatusFilter filter) async {
    selectedFilter = filter;
    state = AsyncData(ProductsListState(products: products, filter: filter));
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

class _ProductFormController extends ProductFormController {
  String? productId;
  bool? isActive;

  @override
  Future<void> build() async {}

  @override
  Future<bool> setActive(String productId, {required bool isActive}) async {
    this.productId = productId;
    this.isActive = isActive;
    return true;
  }
}

Product _product({
  String id = 'product-1',
  String name = 'Maden Suyu',
  String? sku = 'MS-01',
  bool isActive = true,
  bool trackStock = true,
  int unitPriceMinor = 12345,
}) => Product(
  id: id,
  businessId: 'business-1',
  name: name,
  sku: sku,
  unitPriceMinor: unitPriceMinor,
  currencyCode: 'TRY',
  trackStock: trackStock,
  stockQuantity: 8,
  isActive: isActive,
  archivedAt: isActive ? null : DateTime.utc(2026, 7, 18),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 7, 18),
);
