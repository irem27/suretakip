import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/services/presentation/controllers/services_controllers.dart';
import 'package:suretakip/features/services/presentation/pages/service_detail_page.dart';

void main() {
  testWidgets('hizmet alanları ve minor-unit dakika ücreti gösterilir', (
    tester,
  ) async {
    await _pump(tester, service: _service());

    expect(find.text('Hizmet Detayı'), findsOneWidget);
    expect(find.text('Bilardo Masası'), findsOneWidget);
    expect(find.text('₺3,50 / dakika'), findsOneWidget);
    expect(find.text('Minimum ücretlendirme'), findsOneWidget);
    expect(find.text('15 dakika'), findsOneWidget);
    expect(find.text('Yuvarlama aralığı'), findsOneWidget);
    expect(find.text('5 dakika'), findsOneWidget);
    expect(find.text('TRY'), findsOneWidget);
    expect(find.text('Pasife Al'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(OutlinedButton, 'Pasife Al')).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('pasif hizmeti aktifleştirme doğru kimlik ve durumu iletir', (
    tester,
  ) async {
    final formController = _ServiceFormController();
    await _pump(
      tester,
      service: _service(isActive: false),
      formController: formController,
    );

    expect(find.text('Hizmeti aktifleştir'), findsOneWidget);
    expect(
      find.text('Hizmeti yeniden yeni işlemlerde kullanılabilir yapar.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Aktifleştir'));
    await tester.pump();

    expect(formController.serviceId, 'service-1');
    expect(formController.isActive, isTrue);
    expect(find.text('Hizmet yeniden aktifleştirildi.'), findsOneWidget);
  });

  testWidgets('detay yükleme hatası yeniden deneme ile providerı yeniler', (
    tester,
  ) async {
    var loadCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceDetailProvider('service-1').overrideWith((ref) {
            loadCount++;
            throw StateError('hizmet detay hatası');
          }),
        ],
        child: const MaterialApp(
          home: ServiceDetailPage(serviceId: 'service-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Hizmet detayı yüklenemedi. Lütfen tekrar deneyin.'),
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
  required Service service,
  _ServiceFormController? formController,
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final effectiveForm = formController ?? _ServiceFormController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serviceDetailProvider('service-1').overrideWith((ref) => service),
        serviceFormControllerProvider.overrideWith(() => effectiveForm),
      ],
      child: const MaterialApp(home: ServiceDetailPage(serviceId: 'service-1')),
    ),
  );
  await tester.pumpAndSettle();
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

Service _service({bool isActive = true}) => Service(
  id: 'service-1',
  businessId: 'business-1',
  name: 'Bilardo Masası',
  pricePerMinuteMinor: 350,
  roundingIntervalMinutes: 5,
  minimumChargeMinutes: 15,
  currencyCode: 'TRY',
  isActive: isActive,
  archivedAt: isActive ? null : DateTime.utc(2026, 7, 18),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 7, 18, 10, 30),
);
