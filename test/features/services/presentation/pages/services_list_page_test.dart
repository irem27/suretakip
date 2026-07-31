import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/businesses/domain/entities/business_capabilities.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';
import 'package:suretakip/features/services/presentation/pages/services_list_page.dart';

void main() {
  testWidgets('boş liste Türkçe yönlendirme metinlerini gösterir', (
    tester,
  ) async {
    await _pump(tester, services: const []);

    expect(
      find.text(
        'Eşleşen hizmet bulunamadı. Aramayı değiştirin veya Yeni Hizmet düğmesiyle kayıt ekleyin.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Filtreyi değiştirin veya yeni bir hizmet ekleyin.'),
      findsOneWidget,
    );
  });

  testWidgets('hizmet kartı alanları, fiyat ve erişilebilir hedefler görünür', (
    tester,
  ) async {
    await _pump(tester, services: [_service()]);

    expect(find.text('Bilardo Masası'), findsOneWidget);
    expect(find.text('₺3,50 / dakika'), findsOneWidget);
    expect(find.text('15 dk.'), findsOneWidget);
    expect(find.text('5 dk. yukarı yuvarla'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Bilardo Masası aktif durumu'),
      findsOneWidget,
    );
    // Tooltip'i DEĞİL IconButton'ı ölç: Material 3'te ikon görsel olarak 40px
    // çizilir, dokunma hedefini IconButton'ın tap-target dolgusu 48px'e
    // tamamlar. Tooltip yalnızca görsel kısmı sarar (ölçüldü: 40 vs 48).
    expect(
      tester
          .getSize(
            find.ancestor(
              of: find.byTooltip('Geri'),
              matching: find.byType(IconButton),
            ),
          )
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(Switch)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('arama listeyi daraltır ve pasif filtre görünümü değiştirir', (
    tester,
  ) async {
    final listController = _ServicesListController([
      _service(),
      _service(id: 'service-2', name: 'Eski Konsol', isActive: false),
    ]);
    await _pump(tester, listController: listController);

    await tester.enterText(find.byType(TextField), 'konsol');
    await tester.pump();

    expect(find.text('Bilardo Masası'), findsNothing);
    expect(find.text('Eski Konsol'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pasif'));
    await tester.pump();

    expect(listController.selectedFilter, ServiceStatusFilter.inactive);
    expect(find.text('Bilardo Masası'), findsNothing);
    expect(find.text('Eski Konsol'), findsOneWidget);
  });

  testWidgets('durum anahtarı hizmet kimliği ve yeni durumu iletir', (
    tester,
  ) async {
    final formController = _ServiceFormController();
    await _pump(tester, services: [_service()], formController: formController);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(formController.serviceId, 'service-1');
    expect(formController.isActive, isFalse);
  });

  testWidgets('yükleme hatası metni ve Tekrar Dene aksiyonu görünür', (
    tester,
  ) async {
    final listController = _ServicesListController.error();
    await _pump(tester, listController: listController);

    expect(
      find.text('Hizmetler yüklenemedi. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
    final retry = find.widgetWithText(OutlinedButton, 'Tekrar Dene');
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pump();

    expect(listController.refreshCount, 1);
  });

  for (final role in [MemberRole.owner, MemberRole.admin]) {
    testWidgets('${role.name} katalog yazma aksiyonlarını görür', (
      tester,
    ) async {
      await _pump(tester, services: [_service()], role: role);

      expect(find.text('Yeni Hizmet'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    });
  }

  testWidgets('staff ekleme aksiyonunu görmez ve anahtar devre dışıdır', (
    tester,
  ) async {
    await _pump(tester, services: [_service()], role: MemberRole.staff);

    expect(find.text('Yeni Hizmet'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  List<Service>? services,
  _ServicesListController? listController,
  _ServiceFormController? formController,
  MemberRole role = MemberRole.owner,
}) async {
  final effectiveList = listController ?? _ServicesListController(services!);
  final effectiveForm = formController ?? _ServiceFormController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessCapabilitiesProvider.overrideWithValue(
          AsyncData(BusinessCapabilities.forRole(role)),
        ),
        servicesListControllerProvider.overrideWith(() => effectiveList),
        serviceFormControllerProvider.overrideWith(() => effectiveForm),
      ],
      child: const MaterialApp(home: ServicesListPage()),
    ),
  );
  await tester.pumpAndSettle();
}

class _ServicesListController extends ServicesListController {
  _ServicesListController(this.services) : error = null;

  _ServicesListController.error()
    : services = const [],
      error = StateError('hizmet hatası');

  final List<Service> services;
  final Object? error;
  ServiceStatusFilter? selectedFilter;
  int refreshCount = 0;

  @override
  Future<ServicesListState> build(BusinessScope scope) async {
    if (error != null) throw error!;
    return ServicesListState(
      services: services,
      filter: ServiceStatusFilter.all,
    );
  }

  @override
  Future<void> setFilter(ServiceStatusFilter filter) async {
    selectedFilter = filter;
    state = AsyncData(ServicesListState(services: services, filter: filter));
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

class _ServiceFormController extends ServiceFormController {
  String? serviceId;
  bool? isActive;

  @override
  Future<void> build() async {}

  @override
  Future<bool> setActive(String serviceId, {required bool isActive}) async {
    this.serviceId = serviceId;
    this.isActive = isActive;
    return true;
  }
}

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
