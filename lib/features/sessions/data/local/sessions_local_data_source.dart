import 'package:drift/drift.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';

/// Offline seans başlatma girdisi. Hizmet snapshot'ı başlangıçta dondurulur.
final class StartSessionLocally {
  const StartSessionLocally({
    required this.sessionId,
    required this.timeEntryId,
    required this.businessId,
    required this.serviceId,
    required this.openedByMemberId,
    required this.serviceName,
    required this.pricePerMinuteMinor,
    required this.roundingIntervalMinutes,
    required this.minimumChargeMinutes,
    required this.currencyCode,
    required this.startedAt,
    required this.startedOffline,
    this.customerId,
    this.notes,
  });

  final String sessionId;
  final String timeEntryId;
  final String businessId;
  final String serviceId;
  final String openedByMemberId;
  final String serviceName;
  final int pricePerMinuteMinor;
  final int roundingIntervalMinutes;
  final int minimumChargeMinutes;
  final String currencyCode;
  final DateTime startedAt;
  final bool startedOffline;
  final String? customerId;
  final String? notes;
}

/// Seansların ve zaman aralıklarının cihazda kalıcı yönetimi (Faz C, C1).
/// Süre bu tablolardan hesaplanır; uygulama kapansa da veriler kalır.
class SessionsLocalDataSource {
  const SessionsLocalDataSource(this._db);

  final AppDatabase _db;

  Stream<List<LocalSessionRow>> watchActiveSessions(String businessId) {
    return (_db.select(_db.localSessions)
          ..where(
            (t) =>
                t.businessId.equals(businessId) &
                t.isDeleted.equals(false) &
                t.status.isIn([
                  SessionStatus.active.name,
                  SessionStatus.paused.name,
                ]),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt)]))
        .watch();
  }

  Future<LocalSessionRow?> findSession(String id) => (_db.select(
    _db.localSessions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<LocalSessionTimeEntryRow>> timeEntries(String sessionId) =>
      (_db.select(_db.localSessionTimeEntries)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm(expression: t.startedAt)]))
          .get();

  Stream<List<LocalSessionTimeEntryRow>> watchTimeEntries(String sessionId) =>
      (_db.select(_db.localSessionTimeEntries)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm(expression: t.startedAt)]))
          .watch();

  /// Seansı ve ilk `active` zaman aralığını tek transaction'da yazar.
  Future<LocalSessionRow> startSession(StartSessionLocally command) {
    return _db.transaction(() async {
      await _db
          .into(_db.localSessions)
          .insert(
            LocalSessionsCompanion.insert(
              id: command.sessionId,
              businessId: command.businessId,
              customerId: Value(command.customerId),
              serviceId: command.serviceId,
              openedByMemberId: command.openedByMemberId,
              status: SessionStatus.active.name,
              startedAt: command.startedAt,
              serviceNameSnapshot: command.serviceName,
              pricePerMinuteMinorSnapshot: command.pricePerMinuteMinor,
              roundingIntervalMinutesSnapshot: command.roundingIntervalMinutes,
              minimumChargeMinutesSnapshot: command.minimumChargeMinutes,
              currencyCodeSnapshot: command.currencyCode,
              notes: Value(command.notes),
              syncStatus: SyncStatus.localOnly.wireName,
              startedOffline: Value(command.startedOffline),
              createdAtLocal: command.startedAt,
              updatedAtLocal: command.startedAt,
            ),
          );
      await _insertEntry(
        id: command.timeEntryId,
        businessId: command.businessId,
        sessionId: command.sessionId,
        type: TimeEntryType.active,
        startedAt: command.startedAt,
      );
      return (await findSession(command.sessionId))!;
    });
  }

  /// Açık aralığı kapatır, yeni bir `paused` aralık açar ve durumu günceller.
  Future<void> pauseSession({
    required String sessionId,
    required String newEntryId,
    required DateTime now,
  }) => _transitionEntry(
    sessionId: sessionId,
    newEntryId: newEntryId,
    now: now,
    from: SessionStatus.active,
    to: SessionStatus.paused,
    newType: TimeEntryType.paused,
  );

  /// Duraklama aralığını kapatır, yeni `active` aralık açar ve devam ettirir.
  Future<void> resumeSession({
    required String sessionId,
    required String newEntryId,
    required DateTime now,
  }) => _transitionEntry(
    sessionId: sessionId,
    newEntryId: newEntryId,
    now: now,
    from: SessionStatus.paused,
    to: SessionStatus.active,
    newType: TimeEntryType.active,
  );

  Future<void> _transitionEntry({
    required String sessionId,
    required String newEntryId,
    required DateTime now,
    required SessionStatus from,
    required SessionStatus to,
    required TimeEntryType newType,
  }) {
    return _db.transaction(() async {
      final session = await findSession(sessionId);
      if (session == null) {
        throw StateError('session_not_found');
      }
      if (session.status != from.name) {
        throw StateError('invalid_session_state');
      }

      await (_db.update(_db.localSessionTimeEntries)
            ..where((t) => t.sessionId.equals(sessionId) & t.endedAt.isNull()))
          .write(LocalSessionTimeEntriesCompanion(endedAt: Value(now)));

      await _insertEntry(
        id: newEntryId,
        businessId: session.businessId,
        sessionId: sessionId,
        type: newType,
        startedAt: now,
      );

      await (_db.update(
        _db.localSessions,
      )..where((t) => t.id.equals(sessionId))).write(
        LocalSessionsCompanion(
          status: Value(to.name),
          updatedAtLocal: Value(now),
        ),
      );
    });
  }

  Future<void> _insertEntry({
    required String id,
    required String businessId,
    required String sessionId,
    required TimeEntryType type,
    required DateTime startedAt,
  }) {
    return _db
        .into(_db.localSessionTimeEntries)
        .insert(
          LocalSessionTimeEntriesCompanion.insert(
            id: id,
            businessId: businessId,
            sessionId: sessionId,
            entryType: type.name,
            startedAt: startedAt,
            createdAtLocal: startedAt,
            syncStatus: SyncStatus.localOnly.wireName,
          ),
        );
  }
}
