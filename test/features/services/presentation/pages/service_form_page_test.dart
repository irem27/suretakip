import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/domain/entities/service_input.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';
import 'package:suretakip/features/services/presentation/pages/service_form_page.dart';

void main() {
  testWidgets('boş form gönderilince Türkçe doğrulama mesajları çıkar', (
    tester,
  ) async {
    await _pump(tester, formController: _FakeServiceFormController());

    await tester.tap(find.text('Hizmeti Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Hizmet adı zorunlu.'), findsOneWidget);
    expect(find.text('Dakika ücreti zorunlu.'), findsOneWidget);
  });

  testWidgets('sıfır dakika ücreti reddedilir', (tester) async {
    await _pump(tester, formController: _FakeServiceFormController());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hizmet adı'),
      'Bilardo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Dakika ücreti'),
      '0',
    );
    await tester.tap(find.text('Hizmeti Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Dakika ücreti sıfırdan büyük olmalı.'), findsOneWidget);
  });

  testWidgets('aktif işletme yoksa hata mesajı gösterir ve kaydetmez', (
    tester,
  ) async {
    final controller = _FakeServiceFormController();
    await _pump(tester, formController: controller, useBusiness: false);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hizmet adı'),
      'Bilardo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Dakika ücreti'),
      '3,50',
    );
    await tester.tap(find.text('Hizmeti Kaydet'));
    await tester.pump();

    expect(
      find.text('Aktif işletme bulunamadı. Lütfen tekrar giriş yapın.'),
      findsOneWidget,
    );
    expect(controller.createCalls, 0);
  });

  testWidgets(
    'geçerli girişte yeni hizmet oluşturulur ve detay hedefine gider',
    (tester) async {
      final controller = _FakeServiceFormController(
        result: _service(id: 'service-42'),
      );
      await _pump(tester, formController: controller);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hizmet adı'),
        'Bilardo',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dakika ücreti'),
        '3,50',
      );
      await tester.tap(find.text('Hizmeti Kaydet'));
      await tester.pumpAndSettle();

      expect(controller.createdInput?.name, 'Bilardo');
      expect(controller.createdInput?.pricePerMinute.minorUnits, 350);
      expect(find.text('Hizmet detay hedefi: service-42'), findsOneWidget);
    },
  );

  testWidgets('yuvarlama ve minimum süre dropdown seçimi state günceller', (
    tester,
  ) async {
    final controller = _FakeServiceFormController(result: _service());
    await _pump(tester, formController: controller);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hizmet adı'),
      'Bilardo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Dakika ücreti'),
      '3,50',
    );

    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 dakika').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hizmeti Kaydet'));
    await tester.pumpAndSettle();

    expect(controller.createdInput?.minimumChargeMinutes, 30);
  });

  testWidgets('düzenleme modunda mevcut hizmet alanları önceden dolu gelir', (
    tester,
  ) async {
    final service = _service(name: 'Masa Tenisi', isActive: false);
    final controller = _FakeServiceFormController(result: service);
    await _pump(
      tester,
      formController: controller,
      serviceId: service.id,
      detailAsync: AsyncData(service),
    );

    expect(find.text('Hizmeti Düzenle'), findsOneWidget);
    expect(find.text('Masa Tenisi'), findsOneWidget);
    expect(find.text('Hizmet pasif', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Değişiklikleri Kaydet'));
    await tester.pumpAndSettle();

    expect(controller.updatedService?.name, 'Masa Tenisi');
  });

  testWidgets('düzenleme yükleniyor durumunda ilerleme göstergesi görünür', (
    tester,
  ) async {
    await _pump(
      tester,
      formController: _FakeServiceFormController(),
      serviceId: 'service-1',
      detailAsync: const AsyncLoading(),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('düzenleme yükleme hatasında hata mesajı görünür', (
    tester,
  ) async {
    await _pump(
      tester,
      formController: _FakeServiceFormController(),
      serviceId: 'service-1',
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
    final controller = _FakeServiceFormController();
    await _pump(tester, formController: controller);

    controller.emitError(const ValidationException('Geçersiz hizmet.'));
    await tester.pump();

    expect(find.text('Geçersiz hizmet.'), findsOneWidget);
  });

  testWidgets('kaydet sürerken buton devre dışı ve göstergeli olur', (
    tester,
  ) async {
    final controller = _FakeServiceFormController(loading: true);
    await _pump(tester, formController: controller);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    final cancel = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(cancel.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('iptal düğmesi geri döner', (tester) async {
    await _pump(tester, formController: _FakeServiceFormController());

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();

    expect(find.text('Hizmetler hedefi'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeServiceFormController formController,
  bool useBusiness = true,
  String? serviceId,
  AsyncValue<Service>? detailAsync,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.services,
    routes: [
      GoRoute(
        path: AppRoutes.serviceCreate,
        builder: (_, _) => const ServiceFormPage(),
      ),
      GoRoute(
        path: '/services/:serviceId/edit',
        builder: (_, state) =>
            ServiceFormPage(serviceId: state.pathParameters['serviceId']),
      ),
      GoRoute(
        name: AppRouteNames.services,
        path: AppRoutes.services,
        builder: (_, _) => const Scaffold(body: Text('Hizmetler hedefi')),
      ),
      GoRoute(
        name: AppRouteNames.serviceDetail,
        path: AppRoutes.serviceDetail,
        builder: (_, state) => Scaffold(
          body: Text(
            'Hizmet detay hedefi: ${state.pathParameters['serviceId']}',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  final overrides = <Override>[
    serviceFormControllerProvider.overrideWith(() => formController),
    activeBusinessProvider.overrideWithValue(useBusiness ? _business() : null),
  ];
  if (serviceId != null && detailAsync != null) {
    overrides.add(
      serviceDetailProvider(serviceId).overrideWith((ref) {
        return switch (detailAsync) {
          AsyncData(:final value) => Future.value(value),
          AsyncError(:final error, :final stackTrace) => Future<Service>.error(
            error,
            stackTrace,
          ),
          _ => Completer<Service>().future,
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
    serviceId == null ? AppRoutes.serviceCreate : '/services/$serviceId/edit',
  );
  final hasPendingLoading =
      formController.loading || detailAsync is AsyncLoading<Service>;
  if (hasPendingLoading) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
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

Service _service({
  String id = 'service-1',
  String name = 'Bilardo Masası',
  bool isActive = true,
}) => Service(
  id: id,
  businessId: 'business-1',
  name: name,
  pricePerMinuteMinor: 350,
  roundingIntervalMinutes: 5,
  minimumChargeMinutes: 15,
  currencyCode: 'TRY',
  isActive: isActive,
  archivedAt: isActive ? null : DateTime.utc(2026, 7, 18),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 7, 18),
);

class _FakeServiceFormController extends ServiceFormController {
  _FakeServiceFormController({this.result, this.loading = false});

  final Service? result;
  final bool loading;
  ServiceInput? createdInput;
  Service? updatedService;
  var createCalls = 0;

  @override
  Future<void> build() async {
    if (loading) return Completer<void>().future;
  }

  @override
  Future<Service?> create(ServiceInput input) async {
    createCalls++;
    createdInput = input;
    return result;
  }

  @override
  Future<Service?> updateService(Service service) async {
    updatedService = service;
    return result;
  }

  void emitError(Object error) {
    state = AsyncError(error, StackTrace.current);
  }
}
