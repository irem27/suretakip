import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/domain/domain_enums.dart';

final class SessionHistoryFilter {
  const SessionHistoryFilter({
    this.endedAtOrAfter,
    this.endedBefore,
    this.customerId,
    this.serviceId,
    this.statuses = const [SessionStatus.completed, SessionStatus.cancelled],
    this.limit = AppConstants.historyQueryLimit,
  });

  final DateTime? endedAtOrAfter;
  final DateTime? endedBefore;
  final String? customerId;
  final String? serviceId;
  final List<SessionStatus> statuses;
  final int limit;

  SessionHistoryFilter copyWith({
    DateTime? endedAtOrAfter,
    DateTime? endedBefore,
    String? customerId,
    bool clearCustomer = false,
    String? serviceId,
    bool clearService = false,
    List<SessionStatus>? statuses,
    int? limit,
  }) => SessionHistoryFilter(
    endedAtOrAfter: endedAtOrAfter ?? this.endedAtOrAfter,
    endedBefore: endedBefore ?? this.endedBefore,
    customerId: clearCustomer ? null : customerId ?? this.customerId,
    serviceId: clearService ? null : serviceId ?? this.serviceId,
    statuses: statuses ?? this.statuses,
    limit: limit ?? this.limit,
  );
}

String sessionStatusDatabaseValue(SessionStatus status) => switch (status) {
  SessionStatus.draft => 'draft',
  SessionStatus.active => 'active',
  SessionStatus.paused => 'paused',
  SessionStatus.completed => 'completed',
  SessionStatus.cancelled => 'cancelled',
};
