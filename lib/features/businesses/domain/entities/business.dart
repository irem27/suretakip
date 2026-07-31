import 'package:freezed_annotation/freezed_annotation.dart';

part 'business.freezed.dart';

@freezed
abstract class Business with _$Business {
  const factory Business({
    required String id,
    required String name,
    required String currencyCode,
    required String timezone,
    required bool isActive,
    required DateTime? archivedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Business;
}
