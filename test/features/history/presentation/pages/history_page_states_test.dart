import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/history/presentation/controllers/history_controller.dart';
import 'package:suretakip/features/history/presentation/pages/history_page.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';

void main() {
  testWidgets('geçmiş yüklenirken ilerleme göstergesi gösterir', (
    tester,
  ) async {
    final controller = _FakeHistoryController()..hold = true;
    await _pump(tester, controller: controller);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('geçmiş hatası tekrar dene ile yenilenir', (tester) async {
    final controller = _FakeHistoryController()
      ..failure = const DatabaseException('Veritabanı hatası.');
    await _pump(tester, controller: controller);

    expect(find.text('İşlem geçmişi yüklenemedi.'), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, 'Tekrar Dene');
    await tester.tap(retry);
    await tester.pump();

    expect(controller.refreshCount, 1);
  });

  testWidgets('yenile ikonuna dokununca geçmiş yenilenir', (tester) async {
    final controller = _FakeHistoryController();
    await _pump(tester, controller: controller);

    await tester.tap(find.byTooltip('Geçmişi yenile'));
    await tester.pump();

    expect(controller.refreshCount, 1);
  });

  testWidgets('limit dolduğunda bilgilendirme kartı gösterilir', (
    tester,
  ) async {
    final sessions = List.generate(
      AppConstants.historyQueryLimit,
      (i) => _session('session-$i'),
    );
    final controller = _FakeHistoryController()..sessions = sessions;
    await _pump(tester, controller: controller);

    expect(
      find.textContaining('gösteriliyor. Tümünü görmek için'),
      findsOneWidget,
    );
  });

  testWidgets('müşteri, hizmet ve durum filtreleri controller çağırır', (
    tester,
  ) async {
    final controller = _FakeHistoryController()
      ..customers = [_customer('customer-1', 'Ahmet')]
      ..services = [_service('service-1', 'Bilardo')];
    await _pump(tester, controller: controller);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String?> &&
            widget.decoration.labelText == 'Müşteri',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahmet').last);
    await tester.pumpAndSettle();
    expect(controller.lastCustomerId, 'customer-1');

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String?> &&
            widget.decoration.labelText == 'Hizmet',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bilardo').last);
    await tester.pumpAndSettle();
    expect(controller.lastServiceId, 'service-1');

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<HistoryStatusFilter>,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamamlanan').last);
    await tester.pumpAndSettle();
    expect(controller.lastStatus, HistoryStatusFilter.completed);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeHistoryController controller,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.history,
    routes: [
      GoRoute(
        name: AppRouteNames.history,
        path: AppRoutes.history,
        builder: (_, _) => const HistoryPage(),
      ),
      GoRoute(
        name: AppRouteNames.dashboard,
        path: AppRoutes.dashboard,
        builder: (_, _) => const Scaffold(body: Text('dashboard-hedef')),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      activeBusinessProvider.overrideWithValue(_business()),
      historyControllerProvider.overrideWith(() => controller),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
}

class _FakeHistoryController extends HistoryController {
  bool hold = false;
  Object? failure;
  List<Session> sessions = const [];
  List<Customer> customers = const [];
  List<Service> services = const [];
  int refreshCount = 0;
  String? lastCustomerId;
  String? lastServiceId;
  HistoryStatusFilter? lastStatus;

  @override
  Future<HistoryState> build(BusinessScope scope) async {
    if (hold) return Completer<HistoryState>().future;
    if (failure != null) throw failure!;
    final now = DateTime.utc(2026, 7, 18);
    return HistoryState(
      sessions: sessions,
      customers: customers,
      services: services,
      firstDate: DateTime(2026, 7),
      lastDate: now,
      customerId: null,
      serviceId: null,
      status: HistoryStatusFilter.all,
      serverLocalDate: now,
      paymentStatuses: const {},
    );
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
  }

  @override
  Future<void> setCustomer(String? customerId) async {
    lastCustomerId = customerId;
  }

  @override
  Future<void> setService(String? serviceId) async {
    lastServiceId = serviceId;
  }

  @override
  Future<void> setStatus(HistoryStatusFilter status) async {
    lastStatus = status;
  }
}

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

Customer _customer(String id, String name) => Customer(
  id: id,
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

Service _service(String id, String name) => Service(
  id: id,
  businessId: 'business-1',
  name: name,
  pricePerMinuteMinor: 100,
  roundingIntervalMinutes: 1,
  minimumChargeMinutes: 0,
  currencyCode: 'TRY',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Session _session(String id) => Session(
  id: id,
  businessId: 'business-1',
  customerId: null,
  serviceId: 'service-1',
  openedByMemberId: 'member-1',
  closedByMemberId: 'member-1',
  status: SessionStatus.completed,
  startedAt: DateTime.utc(2026, 7, 18, 8),
  endedAt: DateTime.utc(2026, 7, 18, 9),
  chargedMinutes: 60,
  serviceNameSnapshot: id,
  pricePerMinuteMinorSnapshot: 100,
  roundingIntervalMinutesSnapshot: 1,
  minimumChargeMinutesSnapshot: 0,
  currencyCodeSnapshot: 'TRY',
  serviceSubtotalMinor: 6000,
  productsSubtotalMinor: 0,
  discountMinor: 0,
  taxMinor: 0,
  grandTotalMinor: 6000,
  notes: null,
  createdAt: DateTime.utc(2026, 7, 18, 8),
  updatedAt: DateTime.utc(2026, 7, 18, 9),
);
