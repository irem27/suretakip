import 'package:suretakip/core/value_objects/money.dart';

/// Onboarding girdisi: işletme + zorunlu ilk hizmet + opsiyonel ilk ürün.
/// `complete_onboarding` RPC'sine tek atomik çağrıda gönderilir. Para birimi
/// tek kaynaktan gelir ([servicePricePerMinute] üzerinden); varsa ürün fiyatı
/// da aynı para biriminde olmalıdır.
final class OnboardingInput {
  OnboardingInput({
    required this.businessName,
    required this.timezone,
    required this.serviceName,
    required this.servicePricePerMinute,
    required this.roundingIntervalMinutes,
    required this.minimumChargeMinutes,
    this.productName,
    this.productPrice,
  }) {
    if (productPrice != null &&
        productPrice!.currencyCode != servicePricePerMinute.currencyCode) {
      throw ArgumentError(
        'Ürün ve hizmet fiyatları aynı para biriminde olmalıdır.',
      );
    }
  }

  final String businessName;
  final String timezone;
  final String serviceName;
  final Money servicePricePerMinute;
  final int roundingIntervalMinutes;
  final int minimumChargeMinutes;
  final String? productName;
  final Money? productPrice;

  bool get includeProduct => productPrice != null;
  String get currencyCode => servicePricePerMinute.currencyCode;
}
