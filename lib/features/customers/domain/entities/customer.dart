import 'package:freezed_annotation/freezed_annotation.dart';

part 'customer.freezed.dart';

@freezed
abstract class Customer with _$Customer {
  const factory Customer({
    required String id,
    required String businessId,
    required String name,
    required String? phone,
    required String? email,
    required String? notes,
    required bool isActive,
    required DateTime? archivedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Customer;
}
