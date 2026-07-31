import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:suretakip/core/domain/domain_enums.dart';

part 'business_member.freezed.dart';

@freezed
abstract class BusinessMember with _$BusinessMember {
  const factory BusinessMember({
    required String id,
    required String businessId,
    required String userId,
    required MemberRole role,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _BusinessMember;
}
