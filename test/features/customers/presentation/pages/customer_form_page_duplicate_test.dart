import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/customers/presentation/pages/customer_form_page.dart';

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

Business _business() => Business(
  id: 'business-1',
  name: 'Test',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Customer _customer(String name, {String? phone, String id = 'c1'}) => Customer(
  id: id,
  businessId: 'business-1',
  name: name,
  phone: phone,
  email: null,
  notes: null,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _FakeCustomersListController extends CustomersListController {
  _FakeCustomersListController(this._customers);
  final List<Customer> _customers;

  @override
  Future<CustomersListState> build(BusinessScope scope) async =>
      CustomersListState(customers: _customers, query: '');
}

class _ThrowingCustomersListController extends CustomersListController {
  @override
  Future<CustomersListState> build(BusinessScope scope) async =>
      throw StateError('liste yüklenemedi');
}

class _RecordingFormController extends CustomerFormController {
  int createCalls = 0;

  @override
  Future<void> build() async {}

  @override
  Future<Customer?> create(CustomerInput input) async {
    createCalls++;
    return _customer(input.name, id: 'new-id');
  }
}

Widget _harness({
  required List<Customer> existing,
  required _RecordingFormController formController,
}) {
  final router = GoRouter(
    initialLocation: '/new',
    routes: [
      GoRoute(path: '/new', builder: (_, _) => const CustomerFormPage()),
      GoRoute(
        path: '/customers/:customerId',
        name: 'customer-detail',
        builder: (_, _) => const Scaffold(body: Text('Müşteri Detayı')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      activeBusinessProvider.overrideWithValue(_business()),
      activeBusinessScopeProvider.overrideWithValue(_scope),
      customersListControllerProvider.overrideWith(
        () => _FakeCustomersListController(existing),
      ),
      customerFormControllerProvider.overrideWith(() => formController),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _enterNameAndSave(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextFormField).first, name);
  await tester.tap(find.text('Müşteriyi Kaydet'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('aynı isimde müşteri varsa kayıtta uyarı diyaloğu çıkar', (
    tester,
  ) async {
    final form = _RecordingFormController();
    await tester.pumpWidget(
      _harness(
        existing: [_customer('Ali Veli', phone: '0532')],
        formController: form,
      ),
    );
    await tester.pump();

    await _enterNameAndSave(tester, 'Ali Veli');

    expect(find.textContaining('Aynı isimde'), findsOneWidget);
    expect(form.createCalls, 0, reason: 'Onaydan önce kayıt yapılmamalı');
  });

  testWidgets('uyarıda Vazgeç kaydı iptal eder', (tester) async {
    final form = _RecordingFormController();
    await tester.pumpWidget(
      _harness(existing: [_customer('Ali Veli')], formController: form),
    );
    await tester.pump();

    await _enterNameAndSave(tester, 'Ali Veli');
    await tester.tap(find.text('Vazgeç'));
    await tester.pump();

    expect(form.createCalls, 0);
  });

  testWidgets('uyarıda Yine de kaydet kaydı sürdürür', (tester) async {
    final form = _RecordingFormController();
    await tester.pumpWidget(
      _harness(existing: [_customer('Ali Veli')], formController: form),
    );
    await tester.pump();

    await _enterNameAndSave(tester, 'Ali Veli');
    await tester.tap(find.text('Yine de kaydet'));
    await tester.pump();
    await tester.pump();

    expect(form.createCalls, 1);
  });

  testWidgets('farklı isimde uyarı çıkmaz, doğrudan kaydeder', (tester) async {
    final form = _RecordingFormController();
    await tester.pumpWidget(
      _harness(existing: [_customer('Ali Veli')], formController: form),
    );
    await tester.pump();

    await _enterNameAndSave(tester, 'Veli Ali');

    expect(find.textContaining('Aynı isimde'), findsNothing);
    expect(form.createCalls, 1);
  });

  testWidgets('liste yüklenemezse mükerrer kontrolü kaydı engellemez', (
    tester,
  ) async {
    final form = _RecordingFormController();
    final router = GoRouter(
      initialLocation: '/new',
      routes: [
        GoRoute(path: '/new', builder: (_, _) => const CustomerFormPage()),
        GoRoute(
          path: '/customers/:customerId',
          name: 'customer-detail',
          builder: (_, _) => const Scaffold(body: Text('Müşteri Detayı')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBusinessProvider.overrideWithValue(_business()),
          activeBusinessScopeProvider.overrideWithValue(_scope),
          customersListControllerProvider.overrideWith(
            _ThrowingCustomersListController.new,
          ),
          customerFormControllerProvider.overrideWith(() => form),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    await _enterNameAndSave(tester, 'Ali Veli');

    expect(find.textContaining('Aynı isimde'), findsNothing);
    expect(form.createCalls, 1);
  });
}
