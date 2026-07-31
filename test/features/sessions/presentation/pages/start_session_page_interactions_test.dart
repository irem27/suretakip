import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/pages/start_session_page.dart';

void main() {
  testWidgets('müşteri ve hizmet seçilince Süreyi Başlat aktif olur', (
    tester,
  ) async {
    final start = _FakeStartSessionController()..sessionId = 'session-9';
    await _pump(tester, start: start);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Süreyi Başlat'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Ayşe'));
    await tester.tap(find.text('Bilardo'));
    await tester.pump();

    final enabledButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Süreyi Başlat'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets('başlatma başarılı olunca detay sayfasına yönlendirir', (
    tester,
  ) async {
    final start = _FakeStartSessionController()..sessionId = 'session-9';
    final router = GoRouter(
      initialLocation: '/sessions/new',
      routes: [
        GoRoute(
          path: '/sessions/new',
          name: AppRouteNames.sessionStart,
          builder: (context, state) => const StartSessionPage(),
        ),
        GoRoute(
          path: '/sessions/:sessionId',
          name: AppRouteNames.sessionDetail,
          builder: (context, state) =>
              Text('Detay ${state.pathParameters['sessionId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(start: start),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bilardo'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Süreyi Başlat'));
    await tester.pumpAndSettle();

    expect(find.text('Detay session-9'), findsOneWidget);
  });

  testWidgets('başlatma başarısız olunca hata mesajı gösterir', (tester) async {
    final start = _FakeStartSessionController()
      ..sessionId = null
      ..failure = const ValidationException('Hizmet seçilmedi.');
    await _pump(tester, start: start);

    await tester.tap(find.text('Bilardo'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Süreyi Başlat'));
    await tester.pumpAndSettle();

    expect(find.text('Hizmet seçilmedi.'), findsOneWidget);
  });

  testWidgets('müşteri yükleme hatasında tekrar dene çağrılır', (tester) async {
    final customers = _FailingCustomersListController();
    await _pump(tester, customers: customers);

    expect(find.text('Müşteriler yüklenemedi.'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tekrar Dene'));
    await tester.pump();

    expect(customers.refreshCount, 1);
  });

  testWidgets('hizmet yükleme hatasında tekrar dene çağrılır', (tester) async {
    final services = _FailingServicesListController();
    await _pump(tester, services: services);

    expect(find.text('Hizmetler yüklenemedi.'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tekrar Dene'));
    await tester.pump();

    expect(services.refreshCount, 1);
  });

  testWidgets('aktif hizmet yoksa Hizmet Ekle mesajı ve düğmesi görünür', (
    tester,
  ) async {
    await _pump(tester, services: _FakeServicesListController(services: []));

    expect(
      find.text(
        'Aktif hizmet bulunamadı. İşlem başlatmak için önce bir hizmet ekleyin.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Hizmet Ekle'), findsOneWidget);
  });

  testWidgets('nota metin girilebilir', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'Test notu');
    await tester.pump();

    expect(find.text('Test notu'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  _FakeStartSessionController? start,
  CustomersListController? customers,
  ServicesListController? services,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(
        start: start,
        customers: customers,
        services: services,
      ),
      child: const MaterialApp(home: StartSessionPage()),
    ),
  );
  await tester.pumpAndSettle();
}

List<Override> _overrides({
  _FakeStartSessionController? start,
  CustomersListController? customers,
  ServicesListController? services,
}) => [
  customersListControllerProvider.overrideWith(
    () => customers ?? _FakeCustomersListController(),
  ),
  servicesListControllerProvider.overrideWith(
    () => services ?? _FakeServicesListController(),
  ),
  startSessionControllerProvider.overrideWith(
    () => start ?? _FakeStartSessionController(),
  ),
];

class _FakeCustomersListController extends CustomersListController {
  @override
  Future<CustomersListState> build(BusinessScope scope) async =>
      CustomersListState(customers: [_customer()], query: '');
}

class _FailingCustomersListController extends CustomersListController {
  int refreshCount = 0;

  @override
  Future<CustomersListState> build(BusinessScope scope) async =>
      throw StateError('boom');

  @override
  Future<void> refresh() async => refreshCount++;
}

class _FakeServicesListController extends ServicesListController {
  _FakeServicesListController({List<Service>? services})
    : _services = services ?? [_service()];

  final List<Service> _services;

  @override
  Future<ServicesListState> build(BusinessScope scope) async =>
      ServicesListState(services: _services, filter: ServiceStatusFilter.all);
}

class _FailingServicesListController extends ServicesListController {
  int refreshCount = 0;

  @override
  Future<ServicesListState> build(BusinessScope scope) async =>
      throw StateError('boom');

  @override
  Future<void> refresh() async => refreshCount++;
}

class _FakeStartSessionController extends StartSessionController {
  String? sessionId;
  Object? failure;

  @override
  Future<void> build() async {}

  @override
  Future<String?> start({
    required Service service,
    String? customerId,
    String? notes,
  }) async {
    if (failure != null) {
      state = AsyncError(failure!, StackTrace.current);
      return null;
    }
    return sessionId;
  }
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
