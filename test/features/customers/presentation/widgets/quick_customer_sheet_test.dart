import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/customers/presentation/widgets/quick_customer_sheet.dart';

void main() {
  testWidgets('boş ad ile kaydet denenince doğrulama mesajı gösterilir', (
    tester,
  ) async {
    await _pumpSheet(tester, _FakeCustomerFormController());

    await tester.tap(find.text('Kaydet ve Seç'));
    await tester.pump();

    expect(find.text('Müşteri adı zorunlu.'), findsOneWidget);
  });

  testWidgets('geçerli ad ile kaydedince oluşturulan müşteri döner', (
    tester,
  ) async {
    final controller = _FakeCustomerFormController(
      result: _customer(name: 'Ayşe Yılmaz'),
    );
    Customer? popped;
    await _pumpSheet(tester, controller, onPopped: (value) => popped = value);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ad soyad'),
      'Ayşe Yılmaz',
    );
    await tester.tap(find.text('Kaydet ve Seç'));
    await tester.pumpAndSettle();

    expect(popped?.name, 'Ayşe Yılmaz');
    expect(controller.createdInput?.name, 'Ayşe Yılmaz');
  });

  testWidgets('telefon alanı onFieldSubmitted ile kaydı tetikler', (
    tester,
  ) async {
    final controller = _FakeCustomerFormController(
      result: _customer(name: 'Can Demir'),
    );
    Customer? popped;
    await _pumpSheet(tester, controller, onPopped: (value) => popped = value);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ad soyad'),
      'Can Demir',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Telefon (isteğe bağlı)'),
      '5551234567',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(popped?.name, 'Can Demir');
    expect(controller.createdInput?.phone, '5551234567');
  });

  testWidgets('aktif işletme yoksa kaydetmeden hata mesajı gösterir', (
    tester,
  ) async {
    final controller = _FakeCustomerFormController();
    await _pumpSheet(tester, controller, businessId: null);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ad soyad'),
      'Ayşe Yılmaz',
    );
    await tester.tap(find.text('Kaydet ve Seç'));
    await tester.pump();

    expect(
      find.text('Aktif işletme bulunamadı. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
    expect(controller.createCalls, 0);
  });

  testWidgets('kayıt sürerken buton yükleniyor göstergesine döner', (
    tester,
  ) async {
    final controller = _FakeCustomerFormController(loading: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerFormControllerProvider.overrideWith(() => controller),
          activeBusinessScopeProvider.overrideWithValue((
            businessId: 'business-1',
            generation: 0,
          )),
        ],
        child: const MaterialApp(home: Scaffold(body: QuickCustomerSheet())),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('controller hata verince snackbar Türkçe mesaj gösterir', (
    tester,
  ) async {
    final controller = _FakeCustomerFormController();
    await _pumpSheet(tester, controller);

    controller.emitError(const ValidationException('Geçersiz veri.'));
    await tester.pump();

    expect(find.text('Geçersiz veri.'), findsOneWidget);
  });
}

Future<void> _pumpSheet(
  WidgetTester tester,
  _FakeCustomerFormController controller, {
  String? businessId = 'business-1',
  void Function(Customer?)? onPopped,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerFormControllerProvider.overrideWith(() => controller),
        activeBusinessScopeProvider.overrideWithValue((
          businessId: businessId,
          generation: 0,
        )),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                final result = await showModalBottomSheet<Customer>(
                  context: context,
                  builder: (_) => const QuickCustomerSheet(),
                );
                onPopped?.call(result);
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Aç'));
  await tester.pumpAndSettle();
}

Customer _customer({required String name}) => Customer(
  id: 'customer-1',
  businessId: 'business-1',
  name: name,
  phone: null,
  email: null,
  notes: null,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _FakeCustomerFormController extends CustomerFormController {
  _FakeCustomerFormController({this.result, this.loading = false});

  final Customer? result;
  final bool loading;
  CustomerInput? createdInput;
  var createCalls = 0;

  @override
  Future<void> build() async {
    if (loading) return Completer<void>().future;
  }

  @override
  Future<Customer?> create(CustomerInput input) async {
    createCalls++;
    createdInput = input;
    return result;
  }

  void emitError(Object error) {
    state = AsyncError(error, StackTrace.current);
  }
}
