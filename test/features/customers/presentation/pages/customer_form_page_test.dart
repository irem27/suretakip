import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/domain/entities/customer_input.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/customers/presentation/pages/customer_form_page.dart';

void main() {
  testWidgets('boş müşteri formu Türkçe doğrulama mesajı verir', (
    tester,
  ) async {
    await _pump(tester, formController: _FakeCustomerFormController());

    await tester.tap(find.text('Müşteriyi Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Müşteri adı zorunlu.'), findsOneWidget);
  });

  testWidgets('geçersiz e-posta ile doğrulama mesajı gösterir', (tester) async {
    await _pump(tester, formController: _FakeCustomerFormController());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ad soyad'),
      'Ayşe Yılmaz',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-posta (isteğe bağlı)'),
      'gecersiz-eposta',
    );
    await tester.tap(find.text('Müşteriyi Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
  });

  testWidgets('boş e-posta doğrulamadan geçer', (tester) async {
    final controller = _FakeCustomerFormController(result: _customer());
    await _pump(tester, formController: controller);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ad soyad'),
      'Ayşe Yılmaz',
    );
    await tester.tap(find.text('Müşteriyi Kaydet'));
    await tester.pumpAndSettle();

    expect(controller.createdInput?.email, isNull);
  });

  testWidgets('aktif işletme yoksa hata mesajı gösterir ve kaydetmez', (
    tester,
  ) async {
    final controller = _FakeCustomerFormController();
    await _pump(tester, formController: controller, useBusiness: false);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ad soyad'),
      'Ayşe Yılmaz',
    );
    await tester.tap(find.text('Müşteriyi Kaydet'));
    await tester.pump();

    expect(
      find.text('Aktif işletme bulunamadı. Lütfen tekrar giriş yapın.'),
      findsOneWidget,
    );
    expect(controller.createCalls, 0);
  });

  testWidgets(
    'geçerli girişte yeni müşteri oluşturulur ve detay hedefine gider',
    (tester) async {
      final controller = _FakeCustomerFormController(
        result: _customer(id: 'customer-42'),
      );
      await _pump(tester, formController: controller);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Ad soyad'),
        'Ayşe Yılmaz',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telefon (isteğe bağlı)'),
        '5551234567',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta (isteğe bağlı)'),
        'ayse@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Notlar (isteğe bağlı)'),
        'Sadık müşteri',
      );
      await tester.tap(find.text('Müşteriyi Kaydet'));
      await tester.pumpAndSettle();

      expect(controller.createdInput?.name, 'Ayşe Yılmaz');
      expect(controller.createdInput?.phone, '5551234567');
      expect(controller.createdInput?.email, 'ayse@example.com');
      expect(controller.createdInput?.notes, 'Sadık müşteri');
      expect(find.text('Müşteri detay hedefi: customer-42'), findsOneWidget);
    },
  );

  testWidgets('düzenleme modunda mevcut müşteri alanları önceden dolu gelir', (
    tester,
  ) async {
    final customer = _customer(name: 'Can Demir', phone: '5551112233');
    final controller = _FakeCustomerFormController(result: customer);
    await _pump(
      tester,
      formController: controller,
      customerId: customer.id,
      detailAsync: AsyncData(customer),
    );

    expect(find.text('Müşteriyi Düzenle'), findsOneWidget);
    expect(find.text('Can Demir'), findsOneWidget);
    expect(find.text('5551112233'), findsOneWidget);

    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();

    expect(controller.updatedCustomer?.name, 'Can Demir');
  });

  testWidgets('düzenleme yükleniyor durumunda ilerleme göstergesi görünür', (
    tester,
  ) async {
    await _pump(
      tester,
      formController: _FakeCustomerFormController(),
      customerId: 'customer-1',
      detailAsync: const AsyncLoading(),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('düzenleme yükleme hatasında hata mesajı görünür', (
    tester,
  ) async {
    await _pump(
      tester,
      formController: _FakeCustomerFormController(),
      customerId: 'customer-1',
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
    final controller = _FakeCustomerFormController();
    await _pump(tester, formController: controller);

    controller.emitError(const ValidationException('Geçersiz müşteri.'));
    await tester.pump();

    expect(find.text('Geçersiz müşteri.'), findsOneWidget);
  });

  testWidgets('kaydet sürerken buton devre dışı ve göstergeli olur', (
    tester,
  ) async {
    final controller = _FakeCustomerFormController(loading: true);
    await _pump(tester, formController: controller);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeCustomerFormController formController,
  bool useBusiness = true,
  String? customerId,
  AsyncValue<Customer>? detailAsync,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.customers,
    routes: [
      GoRoute(
        path: AppRoutes.customerCreate,
        builder: (_, _) => const CustomerFormPage(),
      ),
      GoRoute(
        path: '/customers/:customerId/edit',
        builder: (_, state) =>
            CustomerFormPage(customerId: state.pathParameters['customerId']),
      ),
      GoRoute(
        name: AppRouteNames.customers,
        path: AppRoutes.customers,
        builder: (_, _) => const Scaffold(body: Text('Müşteriler hedefi')),
      ),
      GoRoute(
        name: AppRouteNames.customerDetail,
        path: AppRoutes.customerDetail,
        builder: (_, state) => Scaffold(
          body: Text(
            'Müşteri detay hedefi: ${state.pathParameters['customerId']}',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  final overrides = <Override>[
    customerFormControllerProvider.overrideWith(() => formController),
    activeBusinessProvider.overrideWithValue(useBusiness ? _business() : null),
  ];
  if (customerId != null && detailAsync != null) {
    overrides.add(
      customerDetailProvider(customerId).overrideWith((ref) {
        return switch (detailAsync) {
          AsyncData(:final value) => Future.value(value),
          AsyncError(:final error, :final stackTrace) => Future<Customer>.error(
            error,
            stackTrace,
          ),
          _ => Completer<Customer>().future,
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
    customerId == null
        ? AppRoutes.customerCreate
        : '/customers/$customerId/edit',
  );
  final hasPendingLoading =
      formController.loading || detailAsync is AsyncLoading<Customer>;
  if (hasPendingLoading) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
}

Customer _customer({
  String id = 'customer-1',
  String name = 'Ayşe Yılmaz',
  String? phone,
}) => Customer(
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

class _FakeCustomerFormController extends CustomerFormController {
  _FakeCustomerFormController({this.result, this.loading = false});

  final Customer? result;
  final bool loading;
  CustomerInput? createdInput;
  Customer? updatedCustomer;
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

  @override
  Future<Customer?> updateCustomer(Customer customer) async {
    updatedCustomer = customer;
    return result;
  }

  void emitError(Object error) {
    state = AsyncError(error, StackTrace.current);
  }
}
