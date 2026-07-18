import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';

abstract interface class SessionsRepository {
  Future<List<Session>> getSessions({
    required String businessId,
    String? customerId,
  });

  Future<Session> getSession(String sessionId);

  Future<List<Session>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  });

  Future<List<SessionItem>> getSessionItems(String sessionId);

  Future<List<SessionTimeEntry>> getSessionTimeEntries(String sessionId);

  Future<String> startSession({
    required String businessId,
    required String serviceId,
    String? customerId,
    String? notes,
  });

  Future<String> pauseSession({required String sessionId});

  Future<String> resumeSession({required String sessionId});

  Future<String> addProductToSession({
    required String sessionId,
    required String productId,
    required int quantity,
    int discountMinor = 0,
    int taxMinor = 0,
  });

  Future<String> completeSession({
    required String sessionId,
    int discountMinor = 0,
    int taxMinor = 0,
  });

  Future<String> cancelSession({required String sessionId});

  /// Sunucunun o anki zamanı (UTC). Canlı sayacı cihaz saatinden bağımsız
  /// kılmak için fetch anında çapa olarak alınır.
  Future<DateTime> serverNow();
}
