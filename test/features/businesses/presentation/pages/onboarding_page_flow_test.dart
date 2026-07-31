import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/features/businesses/presentation/controllers/onboarding_controller.dart';
import 'package:suretakip/features/businesses/presentation/pages/onboarding_page.dart';

void main() {
  testWidgets('tüm adımları geçip ürünsüz kurulumu tamamlar', (tester) async {
    final controller = _FakeOnboardingController();
    await _pump(tester, controller: controller);

    await tester.enterText(find.byType(TextField).first, 'Yeni İşletme');
    await _continue(tester);

    // Para birimi adımı: varsayılan seçimle devam.
    await _continue(tester);

    // Saat dilimi adımı: varsayılan seçimle devam.
    await _continue(tester);

    // Hizmet adımı: eksik alanlarla hata göster, sonra doldur.
    await _continue(tester);
    expect(find.text('Hizmet adı zorunlu.'), findsWidgets);

    await tester.enterText(_fieldByLabel('Hizmet adı'), 'Bilardo');
    await tester.enterText(_fieldByLabel('Dakika ücreti (TRY)'), '3.50');
    await _continue(tester);

    // Ürün adımı: eklemeden tamamla.
    await _continue(tester);
    await tester.pumpAndSettle();

    expect(controller.lastRequest, isNotNull);
    expect(controller.lastRequest!.businessName, 'Yeni İşletme');
    expect(controller.lastRequest!.serviceName, 'Bilardo');
    expect(controller.lastRequest!.servicePricePerMinuteMinor, 350);
    expect(controller.lastRequest!.includeProduct, isFalse);
  });

  testWidgets(
    'ürün ekle anahtarı açılınca ürün alanları görünür ve doğrulanır',
    (tester) async {
      final controller = _FakeOnboardingController();
      await _pump(tester, controller: controller);

      await tester.enterText(find.byType(TextField).first, 'İşletmem');
      await _continue(tester);
      await _continue(tester);
      await _continue(tester);
      await tester.enterText(_fieldByLabel('Hizmet adı'), 'Servis');
      await tester.enterText(_fieldByLabel('Dakika ücreti (TRY)'), '5');
      await _continue(tester);

      expect(find.text('Ürün adı'), findsNothing);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(find.text('Ürün adı'), findsOneWidget);

      await _continue(tester);
      expect(find.text('Ürün adı zorunlu.'), findsWidgets);

      await tester.enterText(_fieldByLabel('Ürün adı'), 'Kola');
      await tester.enterText(_fieldByLabel('Satış fiyatı (TRY)'), '25');
      await _continue(tester);
      await tester.pumpAndSettle();

      expect(controller.lastRequest!.includeProduct, isTrue);
      expect(controller.lastRequest!.productName, 'Kola');
      expect(controller.lastRequest!.productPriceMinor, 2500);
    },
  );

  testWidgets('geri butonu önceki adıma döner', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'İşletmem');
    await _continue(tester);

    expect(find.text('Para birimi'), findsWidgets);
    await _cancel(tester);

    expect(find.text('İşletme adı'), findsWidgets);
  });

  testWidgets('para birimi ve saat dilimi seçimi güncellenir', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'İşletmem');
    await _continue(tester);

    _dropdownField(tester, 'TRY').onChanged?.call('USD');
    await tester.pump();

    await _continue(tester);

    _dropdownField(tester, 'Europe/Istanbul').onChanged?.call('Europe/London');
    await tester.pump();

    expect(find.textContaining('Dakika ücreti (USD)'), findsOneWidget);
  });

  testWidgets('kurulum sırasında buton yükleniyor göstergesi gösterir', (
    tester,
  ) async {
    final controller = _FakeOnboardingController()..holdLoading = true;
    await _pump(tester, controller: controller);

    await tester.enterText(find.byType(TextField).first, 'İşletmem');
    await _continue(tester);
    await _continue(tester);
    await _continue(tester);
    await tester.enterText(_fieldByLabel('Hizmet adı'), 'Servis');
    await tester.enterText(_fieldByLabel('Dakika ücreti (TRY)'), '5');
    controller.setLoading();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('domain hatası snackbar ile gösterilir', (tester) async {
    final controller = _FakeOnboardingController()
      ..failure = const ValidationException('Kurulum reddedildi.');
    await _pump(tester, controller: controller);

    await tester.enterText(find.byType(TextField).first, 'İşletmem');
    await _continue(tester);
    await _continue(tester);
    await _continue(tester);
    await tester.enterText(_fieldByLabel('Hizmet adı'), 'Servis');
    await tester.enterText(_fieldByLabel('Dakika ücreti (TRY)'), '5');
    await _continue(tester);
    await _continue(tester);
    await tester.pumpAndSettle();

    expect(find.text('Kurulum reddedildi.'), findsOneWidget);
  });

  testWidgets('genel hata varsayılan Türkçe mesajla gösterilir', (
    tester,
  ) async {
    final controller = _FakeOnboardingController()
      ..failure = StateError('beklenmeyen');
    await _pump(tester, controller: controller);

    await tester.enterText(find.byType(TextField).first, 'İşletmem');
    await _continue(tester);
    await _continue(tester);
    await _continue(tester);
    await tester.enterText(_fieldByLabel('Hizmet adı'), 'Servis');
    await tester.enterText(_fieldByLabel('Dakika ücreti (TRY)'), '5');
    await _continue(tester);
    await _continue(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Kurulum tamamlanamadı. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
  });
}

/// Stepper her adım için ayrı FilledButton üretir ve hepsi aynı boyutta
/// olduğundan (hiçbiri gerçekten "offstage" değildir) `tester.tap` gerçek
/// hedefi doğru seçemeyebilir. Bunun yerine Stepper widget'ının açığa
/// çıkardığı `onStepContinue` geri çağrısı doğrudan tetiklenir; bu, gerçek
/// bir dokunuşla aynı davranışı (aktif adımın Devam Et butonuna basmak)
/// hiçbir hit-test belirsizliği olmadan üretir.
Future<void> _continue(WidgetTester tester) async {
  final stepper = tester.widget<Stepper>(find.byType(Stepper));
  stepper.onStepContinue?.call();
  await tester.pumpAndSettle();
}

Future<void> _cancel(WidgetTester tester) async {
  final stepper = tester.widget<Stepper>(find.byType(Stepper));
  stepper.onStepCancel?.call();
  await tester.pumpAndSettle();
}

Finder _fieldByLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

DropdownButtonFormField<String> _dropdownField(
  WidgetTester tester,
  String initialValue,
) => tester.widget<DropdownButtonFormField<String>>(
  find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.initialValue == initialValue,
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  _FakeOnboardingController? controller,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onboardingControllerProvider.overrideWith(
          () => controller ?? _FakeOnboardingController(),
        ),
      ],
      child: const MaterialApp(home: OnboardingPage()),
    ),
  );
  await tester.pump();
}

class _FakeOnboardingController extends OnboardingController {
  OnboardingRequest? lastRequest;
  Object? failure;
  bool holdLoading = false;

  @override
  Future<void> build() async {}

  void setLoading() {
    state = const AsyncLoading();
  }

  @override
  Future<bool> complete(OnboardingRequest request) async {
    lastRequest = request;
    if (failure != null) {
      state = AsyncError<void>(failure!, StackTrace.current);
      return false;
    }
    state = const AsyncData(null);
    return true;
  }
}
