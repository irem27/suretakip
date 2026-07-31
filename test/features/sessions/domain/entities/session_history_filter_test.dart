import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';

void main() {
  group('SessionHistoryFilter', () {
    test('varsayılanlar completed+cancelled ve tanımlı limit', () {
      const filter = SessionHistoryFilter();

      expect(filter.endedAtOrAfter, isNull);
      expect(filter.endedBefore, isNull);
      expect(filter.customerId, isNull);
      expect(filter.serviceId, isNull);
      expect(filter.statuses, const [
        SessionStatus.completed,
        SessionStatus.cancelled,
      ]);
      expect(filter.limit, AppConstants.historyQueryLimit);
    });

    test('copyWith verilen alanları değiştirir, kalanı korur', () {
      final base = SessionHistoryFilter(
        endedAtOrAfter: DateTime.utc(2026, 1, 1),
        customerId: 'c1',
        serviceId: 's1',
      );

      final updated = base.copyWith(
        endedBefore: DateTime.utc(2026, 2, 1),
        statuses: const [SessionStatus.active],
        limit: 5,
      );

      expect(updated.endedAtOrAfter, DateTime.utc(2026, 1, 1));
      expect(updated.endedBefore, DateTime.utc(2026, 2, 1));
      expect(updated.customerId, 'c1');
      expect(updated.serviceId, 's1');
      expect(updated.statuses, const [SessionStatus.active]);
      expect(updated.limit, 5);
    });

    test('clearCustomer ve clearService null yapar', () {
      const base = SessionHistoryFilter(customerId: 'c1', serviceId: 's1');

      final cleared = base.copyWith(clearCustomer: true, clearService: true);

      expect(cleared.customerId, isNull);
      expect(cleared.serviceId, isNull);
    });

    test('clear bayrağı yeni değeri ezer (clear önceliklidir)', () {
      const base = SessionHistoryFilter(customerId: 'c1');

      final result = base.copyWith(customerId: 'c2', clearCustomer: true);

      expect(result.customerId, isNull);
    });
  });

  group('sessionStatusDatabaseValue', () {
    test('her durum için doğru veritabanı değeri', () {
      expect(sessionStatusDatabaseValue(SessionStatus.draft), 'draft');
      expect(sessionStatusDatabaseValue(SessionStatus.active), 'active');
      expect(sessionStatusDatabaseValue(SessionStatus.paused), 'paused');
      expect(sessionStatusDatabaseValue(SessionStatus.completed), 'completed');
      expect(sessionStatusDatabaseValue(SessionStatus.cancelled), 'cancelled');
    });
  });
}
