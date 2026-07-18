import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/customers/presentation/pages/customer_detail_page.dart';

void main() {
  testWidgets('müşteri iletişim alanları ve notları gösterilir', (
    tester,
  ) async {
    await _pump(tester, customer: _customer());

    expect(find.text('Müşteri Detayı'), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Telefon'), findsOneWidget);
    expect(find.text('05551234567'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('ayse@example.com'), findsOneWidget);
    expect(find.text('Notlar'), findsOneWidget);
    expect(find.text('Cam kenarı masa tercih ediyor.'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(OutlinedButton, 'Pasife Al')).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets(
    'pasif müşteri aktifleştirilirken doğru kimlik ve durum iletilir',
    (tester) async {
      final formController = _CustomerFormController();
      await _pump(
        tester,
        customer: _customer(
          isActive: false,
          phone: null,
          email: null,
          notes: null,
        ),
        formController: formController,
      );

      expect(find.text('—'), findsNWidgets(2));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Aktifleştir'));
      await tester.pump();

      expect(formController.customerId, 'customer-1');
      expect(formController.isActive, isTrue);
      expect(find.text('Müşteri yeniden aktifleştirildi.'), findsOneWidget);
    },
  );

  testWidgets('detay yükleme hatası yeniden deneme ile providerı yeniler', (
    tester,
  ) async {
    var loadCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerDetailProvider('customer-1').overrideWith((ref) {
            loadCount++;
            throw StateError('müşteri detay hatası');
          }),
        ],
        child: const MaterialApp(
          home: CustomerDetailPage(customerId: 'customer-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Müşteri detayı yüklenemedi. Lütfen tekrar deneyin.'),
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
  required Customer customer,
  _CustomerFormController? formController,
}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final effectiveForm = formController ?? _CustomerFormController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerDetailProvider('customer-1').overrideWith((ref) => customer),
        customerFormControllerProvider.overrideWith(() => effectiveForm),
      ],
      child: const MaterialApp(
        home: CustomerDetailPage(customerId: 'customer-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _CustomerFormController extends CustomerFormController {
  String? customerId;
  bool? isActive;

  @override
  Future<void> build() async {}

  @override
  Future<bool> setActive(String customerId, {required bool isActive}) async {
    this.customerId = customerId;
    this.isActive = isActive;
    return true;
  }
}

Customer _customer({
  bool isActive = true,
  String? phone = '05551234567',
  String? email = 'ayse@example.com',
  String? notes = 'Cam kenarı masa tercih ediyor.',
}) => Customer(
  id: 'customer-1',
  businessId: 'business-1',
  name: 'Ayşe Yılmaz',
  phone: phone,
  email: email,
  notes: notes,
  isActive: isActive,
  archivedAt: isActive ? null : DateTime.utc(2026, 7, 18),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 7, 18, 10, 30),
);
