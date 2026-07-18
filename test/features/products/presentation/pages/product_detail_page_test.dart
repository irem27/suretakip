import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/businesses/domain/entities/business_capabilities.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/products/presentation/pages/product_detail_page.dart';

void main() {
  testWidgets('ürün alanları ve minor-unit fiyatı gösterilir', (tester) async {
    await _pump(tester, product: _product());

    expect(find.text('Ürün Detayı'), findsOneWidget);
    expect(find.text('Maden Suyu'), findsOneWidget);
    expect(find.text('₺123,45'), findsOneWidget);
    expect(find.text('Stok kodu'), findsOneWidget);
    expect(find.text('MS-01'), findsOneWidget);
    expect(find.text('Stok takibi'), findsOneWidget);
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Stok miktarı'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(OutlinedButton, 'Pasife Al')).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('pasif ürün aktifleştirilirken doğru kimlik ve durum iletilir', (
    tester,
  ) async {
    final formController = _ProductFormController();
    await _pump(
      tester,
      product: _product(isActive: false, sku: null, trackStock: false),
      formController: formController,
    );

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Kapalı'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Aktifleştir'));
    await tester.pump();

    expect(formController.productId, 'product-1');
    expect(formController.isActive, isTrue);
    expect(find.text('Ürün yeniden aktifleştirildi.'), findsOneWidget);
  });

  testWidgets('detay yükleme hatası yeniden deneme ile providerı yeniler', (
    tester,
  ) async {
    var loadCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessCapabilitiesProvider.overrideWithValue(_managerCapabilities),
          productDetailProvider('product-1').overrideWith((ref) {
            loadCount++;
            throw StateError('ürün detay hatası');
          }),
        ],
        child: const MaterialApp(
          home: ProductDetailPage(productId: 'product-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Ürün detayı yüklenemedi. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
    final retry = find.widgetWithText(OutlinedButton, 'Tekrar Dene');
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(loadCount, 2);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Product product,
  _ProductFormController? formController,
}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final effectiveForm = formController ?? _ProductFormController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessCapabilitiesProvider.overrideWithValue(_managerCapabilities),
        productDetailProvider('product-1').overrideWith((ref) => product),
        productFormControllerProvider.overrideWith(() => effectiveForm),
      ],
      child: const MaterialApp(home: ProductDetailPage(productId: 'product-1')),
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
  bool isActive = true,
  String? sku = 'MS-01',
  bool trackStock = true,
}) => Product(
  id: 'product-1',
  businessId: 'business-1',
  name: 'Maden Suyu',
  sku: sku,
  unitPriceMinor: 12345,
  currencyCode: 'TRY',
  trackStock: trackStock,
  stockQuantity: 8,
  isActive: isActive,
  archivedAt: isActive ? null : DateTime.utc(2026, 7, 18),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 7, 18, 10, 30),
);
