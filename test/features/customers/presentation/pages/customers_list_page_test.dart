import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/customers/presentation/pages/customers_list_page.dart';

void main() {
  testWidgets('boş liste Türkçe yönlendirme metnini gösterir', (tester) async {
    await _pump(tester, customers: const []);

    expect(
      find.text(
        'Eşleşen müşteri bulunamadı. Aramayı değiştirin veya Yeni Müşteri düğmesiyle kayıt ekleyin.',
      ),
      findsOneWidget,
    );
    expect(find.text('Yeni Müşteri'), findsOneWidget);
  });

  testWidgets(
    'aktif ve pasif müşteri alanları ile erişilebilir anahtar görünür',
    (tester) async {
      await _pump(
        tester,
        customers: [
          _customer(),
          _customer(
            id: 'customer-2',
            name: 'Bora Kaya',
            phone: null,
            email: 'bora@example.com',
            isActive: false,
          ),
        ],
      );

      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('05551234567'), findsOneWidget);
      expect(find.text('ayse@firma.test'), findsOneWidget);
      expect(find.text('Bora Kaya'), findsOneWidget);
      // CustomerStatusChip metni büyük harf yazar: 'AKTİF' / 'PASİF'.
      expect(find.text('AKTİF'), findsOneWidget);
      expect(find.text('PASİF'), findsOneWidget);
      expect(find.bySemanticsLabel('Ayşe Yılmaz aktif durumu'), findsOneWidget);
      expect(
        tester.getSize(find.byType(Switch).first).height,
        greaterThanOrEqualTo(48),
      );
    },
  );

  testWidgets('arama adı, telefon ve e-posta için görünümü günceller', (
    tester,
  ) async {
    final listController = _CustomersListController([
      _customer(),
      _customer(
        id: 'customer-2',
        name: 'Bora Kaya',
        phone: '05321112233',
        email: 'bora@example.com',
      ),
    ]);
    await _pump(tester, listController: listController);

    await tester.enterText(find.byType(TextField), 'example');
    await tester.pump();

    expect(listController.query, 'example');
    expect(find.text('Ayşe Yılmaz'), findsNothing);
    expect(find.text('Bora Kaya'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0532');
    await tester.pump();

    expect(find.text('Ayşe Yılmaz'), findsNothing);
    expect(find.text('Bora Kaya'), findsOneWidget);
  });

  testWidgets('durum anahtarı müşteri kimliği ve yeni durumu iletir', (
    tester,
  ) async {
    final formController = _CustomerFormController();
    await _pump(
      tester,
      customers: [_customer()],
      formController: formController,
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(formController.customerId, 'customer-1');
    expect(formController.isActive, isFalse);
  });

  testWidgets('yükleme hatası metni ve Tekrar Dene aksiyonu görünür', (
    tester,
  ) async {
    final listController = _CustomersListController.error();
    await _pump(tester, listController: listController);

    expect(
      find.text('Müşteriler yüklenemedi. Lütfen tekrar deneyin.'),
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
  List<Customer>? customers,
  _CustomersListController? listController,
  _CustomerFormController? formController,
}) async {
  final effectiveList = listController ?? _CustomersListController(customers!);
  final effectiveForm = formController ?? _CustomerFormController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customersListControllerProvider.overrideWith(() => effectiveList),
        customerFormControllerProvider.overrideWith(() => effectiveForm),
      ],
      child: const MaterialApp(home: CustomersListPage()),
    ),
  );
  await tester.pumpAndSettle();
}

class _CustomersListController extends CustomersListController {
  _CustomersListController(this.customers) : error = null;

  _CustomersListController.error()
    : customers = const [],
      error = StateError('müşteri hatası');

  final List<Customer> customers;
  final Object? error;
  String query = '';
  int refreshCount = 0;

  @override
  Future<CustomersListState> build(BusinessScope scope) async {
    if (error != null) throw error!;
    return CustomersListState(customers: customers, query: query);
  }

  @override
  void setQuery(String query) {
    this.query = query;
    state = AsyncData(CustomersListState(customers: customers, query: query));
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
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
  String id = 'customer-1',
  String name = 'Ayşe Yılmaz',
  String? phone = '05551234567',
  String? email = 'ayse@firma.test',
  bool isActive = true,
}) => Customer(
  id: id,
  businessId: 'business-1',
  name: name,
  phone: phone,
  email: email,
  notes: null,
  isActive: isActive,
  archivedAt: isActive ? null : DateTime.utc(2026, 7, 18),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 7, 18),
);
