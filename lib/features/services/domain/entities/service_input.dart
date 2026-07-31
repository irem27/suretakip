import 'package:suretakip/core/value_objects/money.dart';

/// Yeni hizmet oluşturma girdisi. Yalnızca kullanıcının sağladığı alanları
/// taşır; id, timestamp ve is_active DB tarafından üretilir. Fiyat [Money]
/// olarak alınır — ISO 4217 doğrulaması constructor'da zorlanır.
final class ServiceInput {
  const ServiceInput({
    required this.businessId,
    required this.name,
    required this.pricePerMinute,
    required this.roundingIntervalMinutes,
    required this.minimumChargeMinutes,
  });

  final String businessId;
  final String name;
  final Money pricePerMinute;
  final int roundingIntervalMinutes;
  final int minimumChargeMinutes;
}
