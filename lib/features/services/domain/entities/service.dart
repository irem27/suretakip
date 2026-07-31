import 'package:freezed_annotation/freezed_annotation.dart';

part 'service.freezed.dart';

@freezed
abstract class Service with _$Service {
  const factory Service({
    required String id,
    required String businessId,
    required String name,
    required int pricePerMinuteMinor,
    required int roundingIntervalMinutes,
    required int minimumChargeMinutes,
    required String currencyCode,
    required bool isActive,
    required DateTime? archivedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Service;
}
