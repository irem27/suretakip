import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/domain/entities/product_input.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/products/presentation/pages/product_form_page.dart';

void main() {
  testWidgets('yeni üründe boş form Türkçe doğrulama mesajı verir', (
    tester,
  ) async {
    await _pump(tester, formController: _FakeProductFormController());

    await tester.tap(find.text('Ürünü Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Ürün adı zorunlu.'), findsOneWidget);
  });

  testWidgets('geçersiz stok girildiğinde doğrulama mesajı gösterir', (
    tester,
  ) async {
    await _pump(tester, formController: _FakeProductFormController());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ürün adı'),
      'Kola',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Satış fiyatı'),
      '3,00',
    );
    tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(true);
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Başlangıç stoğu'),
      '',
    );
    await tester.tap(find.text('Ürünü Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Stok sıfır veya daha büyük olmalı.'), findsOneWidget);
  });

  testWidgets('aktif işletme yoksa hata mesajı gösterir ve kaydetmez', (
    tester,
  ) async {
    final controller = _FakeProductFormController();
    await _pump(tester, formController: controller, useBusiness: false);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ürün adı'),
      'Kola',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Satış fiyatı'),
      '3,00',
    );
    await tester.tap(find.text('Ürünü Kaydet'));
    await tester.pump();

    expect(
      find.text('Aktif işletme bulunamadı. Lütfen tekrar giriş yapın.'),
      findsOneWidget,
    );
    expect(controller.createCalls, 0);
  });

  testWidgets('geçerli girişte yeni ürün oluşturulur ve detay hedefine gider', (
    tester,
  ) async {
    final controller = _FakeProductFormController(
      result: _product(id: 'product-42'),
    );
    await _pump(tester, formController: controller);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ürün adı'),
      'Kola',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Stok kodu (isteğe bağlı)'),
      'KOLA-1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Satış fiyatı'),
      '3,00',
    );
    await tester.tap(find.text('Ürünü Kaydet'));
    await tester.pumpAndSettle();

    expect(controller.createdInput?.name, 'Kola');
    expect(controller.createdInput?.sku, 'KOLA-1');
    expect(controller.createdInput?.unitPrice.minorUnits, 300);
    expect(controller.createdInput?.trackStock, isFalse);
    expect(find.text('Ürün detay hedefi: product-42'), findsOneWidget);
  });

  testWidgets('stok takibi açılınca stok alanı etkinleşir', (tester) async {
    final controller = _FakeProductFormController(result: _product());
    await _pump(tester, formController: controller);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ürün adı'),
      'Kola',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Satış fiyatı'),
      '3,00',
    );
    tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(true);
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Başlangıç stoğu'),
      '25',
    );

    await tester.tap(find.text('Ürünü Kaydet'));
    await tester.pumpAndSettle();

    expect(controller.createdInput?.trackStock, isTrue);
    expect(controller.createdInput?.stockQuantity, 25);
  });

  testWidgets('düzenlemede stok alanı salt okunur ve uyarı gösterir', (
    tester,
  ) async {
    final controller = _FakeProductFormController(result: _product());
    await _pump(
      tester,
      formController: controller,
      productId: 'product-1',
      detailAsync: AsyncData(_product()),
    );

    expect(find.text('Mevcut stok'), findsOneWidget);
    expect(
      find.text('Stok, stok hareketleriyle değişir; buradan düzenlenmez.'),
      findsOneWidget,
    );
    expect(find.text('Başlangıç stoğu'), findsNothing);

    final stockField = tester.widget<TextFormField>(
      find.ancestor(
        of: find.text('Mevcut stok'),
        matching: find.byType(TextFormField),
      ),
    );
    expect(stockField.controller?.text, '8');

    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();

    expect(controller.updatedProduct?.name, 'Kola');
  });

  testWidgets('düzenleme yükleniyor durumunda ilerleme göstergesi görünür', (
    tester,
  ) async {
    await _pump(
      tester,
      formController: _FakeProductFormController(),
      productId: 'product-1',
      detailAsync: const AsyncLoading(),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('düzenleme yükleme hatasında hata mesajı görünür', (
    tester,
  ) async {
    await _pump(
      tester,
      formController: _FakeProductFormController(),
      productId: 'product-1',
      detailAsync: const AsyncError(
        ValidationException('yüklenemedi'),
        StackTrace.empty,
      ),
    );

    expect(find.text('yüklenemedi'), findsOneWidget);
  });

  testWidgets('controller hata verince snackbar mesajı gösterir', (
    tester,
  ) async {
    final controller = _FakeProductFormController();
    await _pump(tester, formController: controller);

    controller.emitError(const ValidationException('Geçersiz ürün.'));
    await tester.pump();

    expect(find.text('Geçersiz ürün.'), findsOneWidget);
  });

  testWidgets('kaydet sürerken buton devre dışı ve göstergeli olur', (
    tester,
  ) async {
    final controller = _FakeProductFormController(loading: true);
    await _pump(tester, formController: controller);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeProductFormController formController,
  bool useBusiness = true,
  String? productId,
  AsyncValue<Product>? detailAsync,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.products,
    routes: [
      GoRoute(
        path: AppRoutes.productCreate,
        builder: (_, _) => const ProductFormPage(),
      ),
      GoRoute(
        path: '/products/:productId/edit',
        builder: (_, state) =>
            ProductFormPage(productId: state.pathParameters['productId']),
      ),
      GoRoute(
        name: AppRouteNames.products,
        path: AppRoutes.products,
        builder: (_, _) => const Scaffold(body: Text('Ürünler hedefi')),
      ),
      GoRoute(
        name: AppRouteNames.productDetail,
        path: AppRoutes.productDetail,
        builder: (_, state) => Scaffold(
          body: Text('Ürün detay hedefi: ${state.pathParameters['productId']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  final overrides = <Override>[
    productFormControllerProvider.overrideWith(() => formController),
    activeBusinessProvider.overrideWithValue(useBusiness ? _business() : null),
  ];
  if (productId != null && detailAsync != null) {
    overrides.add(
      productDetailProvider(productId).overrideWith((ref) {
        return switch (detailAsync) {
          AsyncData(:final value) => Future.value(value),
          AsyncError(:final error, :final stackTrace) => Future<Product>.error(
            error,
            stackTrace,
          ),
          _ => Completer<Product>().future,
        };
      }),
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  router.push(
    productId == null ? AppRoutes.productCreate : '/products/$productId/edit',
  );
  final hasPendingLoading =
      formController.loading || detailAsync is AsyncLoading<Product>;
  if (hasPendingLoading) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
}

Product _product({
  String id = 'product-1',
  String name = 'Kola',
  bool trackStock = true,
}) => Product(
  id: id,
  businessId: 'business-1',
  name: name,
  sku: 'KOLA-1',
  unitPriceMinor: 3000,
  currencyCode: 'TRY',
  trackStock: trackStock,
  stockQuantity: 8,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
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

class _FakeProductFormController extends ProductFormController {
  _FakeProductFormController({this.result, this.loading = false});

  final Product? result;
  final bool loading;
  ProductInput? createdInput;
  Product? updatedProduct;
  var createCalls = 0;

  @override
  Future<void> build() async {
    if (loading) return Completer<void>().future;
  }

  @override
  Future<Product?> create(ProductInput input) async {
    createCalls++;
    createdInput = input;
    return result;
  }

  @override
  Future<Product?> updateProduct(Product product) async {
    updatedProduct = product;
    return result;
  }

  void emitError(Object error) {
    state = AsyncError(error, StackTrace.current);
  }
}
