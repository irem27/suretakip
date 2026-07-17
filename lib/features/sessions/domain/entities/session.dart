import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:suretakip/core/domain/domain_enums.dart';

part 'session.freezed.dart';

@freezed
class Session with _$Session {
  const factory Session({
    required String id,
    required String businessId,
    required String? customerId,
    required String serviceId,
    required String openedByMemberId,
    required String? closedByMemberId,
    required SessionStatus status,
    required DateTime startedAt,
    required DateTime? endedAt,
    required int? chargedMinutes,
    required String serviceNameSnapshot,
    required int pricePerMinuteMinorSnapshot,
    required int roundingIntervalMinutesSnapshot,
    required int minimumChargeMinutesSnapshot,
    required String currencyCodeSnapshot,
    required int? serviceSubtotalMinor,
    required int? productsSubtotalMinor,
    required int discountMinor,
    required int taxMinor,
    required int? grandTotalMinor,
    required String? notes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Session;
}
