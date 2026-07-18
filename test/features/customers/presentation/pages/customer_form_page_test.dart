import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/presentation/pages/customer_form_page.dart';

void main() {
  testWidgets('boş müşteri formu Türkçe doğrulama mesajı verir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activeBusinessProvider.overrideWithValue(_business())],
        child: const MaterialApp(home: CustomerFormPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Müşteriyi Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Müşteri adı zorunlu.'), findsOneWidget);
  });
}

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
