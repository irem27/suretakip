import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/businesses/domain/entities/onboarding_input.dart';

class OnboardingRequest {
  const OnboardingRequest({
    required this.businessName,
    required this.currencyCode,
    required this.timezone,
    required this.serviceName,
    required this.servicePricePerMinuteMinor,
    required this.includeProduct,
    required this.productName,
    required this.productPriceMinor,
  });

  final String businessName;
  final String currencyCode;
  final String timezone;
  final String serviceName;
  final int servicePricePerMinuteMinor;
  final bool includeProduct;
  final String productName;
  final int productPriceMinor;
}

class OnboardingController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> complete(OnboardingRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // İşletme + ilk hizmet + opsiyonel ürün TEK atomik RPC'de oluşur.
      // Böylece yarım kalma (hizmetsiz işletme) durumu imkansızdır; ayrı
      // idempotency bayrağına gerek kalmaz.
      await ref
          .read(businessesRepositoryProvider)
          .completeOnboarding(
            OnboardingInput(
              businessName: request.businessName.trim(),
              timezone: request.timezone,
              serviceName: request.serviceName.trim(),
              servicePricePerMinute: Money(
                minorUnits: request.servicePricePerMinuteMinor,
                currencyCode: request.currencyCode,
              ),
              roundingIntervalMinutes:
                  AppConstants.defaultRoundingIntervalMinutes,
              minimumChargeMinutes: AppConstants.defaultMinimumChargeMinutes,
              productName: request.includeProduct
                  ? request.productName.trim()
                  : null,
              productPrice: request.includeProduct
                  ? Money(
                      minorUnits: request.productPriceMinor,
                      currencyCode: request.currencyCode,
                    )
                  : null,
            ),
          );

      ref.invalidate(userBusinessesProvider);
    });
    return !state.hasError;
  }
}

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, void>(OnboardingController.new);
