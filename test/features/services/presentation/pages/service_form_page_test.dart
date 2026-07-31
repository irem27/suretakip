import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/services/presentation/pages/service_form_page.dart';

void main() {
  testWidgets('boş form gönderilince Türkçe doğrulama mesajları çıkar', (
    tester,
  ) async {
    await _pumpCreateForm(tester);

    await tester.tap(find.text('Hizmeti Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Hizmet adı zorunlu.'), findsOneWidget);
    expect(find.text('Dakika ücreti zorunlu.'), findsOneWidget);
  });

  testWidgets('sıfır dakika ücreti reddedilir', (tester) async {
    await _pumpCreateForm(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Bilardo');
    await tester.enterText(find.byType(TextFormField).last, '0');
    await tester.tap(find.text('Hizmeti Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Dakika ücreti sıfırdan büyük olmalı.'), findsOneWidget);
  });
}

Future<void> _pumpCreateForm(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeBusinessProvider.overrideWithValue(_business())],
      child: const MaterialApp(home: ServiceFormPage()),
    ),
  );
  await tester.pumpAndSettle();
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
