import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/pages/start_session_page.dart';

void main() {
  testWidgets('müşteri ve hizmet seçimi Türkçe kullanıcı metinleriyle açılır', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersListControllerProvider.overrideWith(
            _FakeCustomersListController.new,
          ),
          servicesListControllerProvider.overrideWith(
            _FakeServicesListController.new,
          ),
          startSessionControllerProvider.overrideWith(
            _FakeStartSessionController.new,
          ),
        ],
        child: const MaterialApp(home: StartSessionPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Misafir müşteri'), findsOneWidget);
    expect(find.text('Bilardo'), findsOneWidget);
    expect(find.bySemanticsLabel('Hizmet: Bilardo'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Süreyi Başlat'), findsOneWidget);
  });
}

class _FakeCustomersListController extends CustomersListController {
  @override
  Future<CustomersListState> build(BusinessScope scope) async =>
      CustomersListState(customers: [_customer()], query: '');
}

class _FakeServicesListController extends ServicesListController {
  @override
  Future<ServicesListState> build(BusinessScope scope) async =>
      ServicesListState(
        services: [_service()],
        filter: ServiceStatusFilter.all,
      );
}

class _FakeStartSessionController extends StartSessionController {
  @override
  Future<void> build() async {}
}

Customer _customer() => Customer(
  id: 'customer-1',
  businessId: 'business-1',
  name: 'Ayşe',
  phone: null,
  email: null,
  notes: null,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Service _service() => Service(
  id: 'service-1',
  businessId: 'business-1',
  name: 'Bilardo',
  pricePerMinuteMinor: 250,
  roundingIntervalMinutes: 15,
  minimumChargeMinutes: 10,
  currencyCode: 'TRY',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
