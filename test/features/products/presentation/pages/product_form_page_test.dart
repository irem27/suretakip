import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/products/presentation/pages/product_form_page.dart';

void main() {
  testWidgets('yeni üründe boş form Türkçe doğrulama mesajı verir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeBusinessProvider.overrideWithValue(_business())],
        child: const MaterialApp(home: ProductFormPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ürünü Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Ürün adı zorunlu.'), findsOneWidget);
  });

  testWidgets('düzenlemede stok alanı salt okunur ve uyarı gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBusinessProvider.overrideWithValue(_business()),
          productDetailProvider(
            'product-1',
          ).overrideWith((ref) async => _product()),
        ],
        child: const MaterialApp(home: ProductFormPage(productId: 'product-1')),
      ),
    );
    await tester.pumpAndSettle();

    // Stok bir cache'tir; yalnız stok hareketleriyle değişir. Düzenleme
    // ekranı bunu yazmamalı, kullanıcıya da bunu söylemeli.
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
  });
}

Product _product() => Product(
  id: 'product-1',
  businessId: 'business-1',
  name: 'Kola',
  sku: 'KOLA-1',
  unitPriceMinor: 3000,
  currencyCode: 'TRY',
  trackStock: true,
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
