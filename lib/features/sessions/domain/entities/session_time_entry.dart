import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:suretakip/core/domain/domain_enums.dart';

part 'session_time_entry.freezed.dart';

@freezed
class SessionTimeEntry with _$SessionTimeEntry {
  const factory SessionTimeEntry({
    required String id,
    required String businessId,
    required String sessionId,
    required TimeEntryType entryType,
    required DateTime startedAt,
    required DateTime? endedAt,
    required DateTime createdAt,
  }) = _SessionTimeEntry;
}
