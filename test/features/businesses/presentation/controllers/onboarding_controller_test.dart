import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/features/businesses/domain/entities/onboarding_input.dart';
import 'package:suretakip/features/businesses/domain/repositories/businesses_repository.dart';
import 'package:suretakip/features/businesses/presentation/controllers/onboarding_controller.dart';

void main() {
  test(
    'işletme, hizmet ve ürün girdilerini immutable inputa dönüştürür',
    () async {
      final repository = _FakeBusinessesRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      final success = await container
          .read(onboardingControllerProvider.notifier)
          .complete(_request(includeProduct: true));

      final input = repository.input!;
      expect(success, isTrue);
      expect(input.businessName, 'Oyun Salonu');
      expect(input.serviceName, 'Bilardo');
      expect(input.servicePricePerMinute.minorUnits, 350);
      expect(input.servicePricePerMinute.currencyCode, 'TRY');
      expect(
        input.roundingIntervalMinutes,
        AppConstants.defaultRoundingIntervalMinutes,
      );
      expect(
        input.minimumChargeMinutes,
        AppConstants.defaultMinimumChargeMinutes,
      );
      expect(input.productName, 'Maden Suyu');
      expect(input.productPrice?.minorUnits, 1250);
    },
  );

  test('ürün istenmediğinde ürün alanlarını atomik inputtan çıkarır', () async {
    final repository = _FakeBusinessesRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    await container
        .read(onboardingControllerProvider.notifier)
        .complete(_request(includeProduct: false));

    expect(repository.input?.productName, isNull);
    expect(repository.input?.productPrice, isNull);
  });

  test('repository hatasında false döner ve hata stateini korur', () async {
    final repository = _FakeBusinessesRepository(error: StateError('hata'));
    final container = _container(repository);
    addTearDown(container.dispose);

    final success = await container
        .read(onboardingControllerProvider.notifier)
        .complete(_request(includeProduct: true));

    expect(success, isFalse);
    expect(container.read(onboardingControllerProvider).hasError, isTrue);
  });
}

ProviderContainer _container(_FakeBusinessesRepository repository) =>
    ProviderContainer(
      overrides: [businessesRepositoryProvider.overrideWithValue(repository)],
    );

OnboardingRequest _request({required bool includeProduct}) => OnboardingRequest(
  businessName: '  Oyun Salonu  ',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  serviceName: '  Bilardo  ',
  servicePricePerMinuteMinor: 350,
  includeProduct: includeProduct,
  productName: '  Maden Suyu  ',
  productPriceMinor: 1250,
);

class _FakeBusinessesRepository implements BusinessesRepository {
  _FakeBusinessesRepository({this.error});

  final Object? error;
  OnboardingInput? input;

  @override
  Future<String> completeOnboarding(OnboardingInput input) async {
    if (error != null) throw error!;
    this.input = input;
    return 'business-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
