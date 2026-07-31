import 'package:drift/drift.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';

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

  /// İşletmenin cihazda bilinen tüm işlemleri. Ekranlar bu akışı izler;
  /// internet yalnızca arka plandaki snapshot'ı günceller.
  Stream<List<LocalSessionRow>> watchSessions(String businessId) {
    return _sessionsQuery(businessId).watch();
  }

  Future<List<LocalSessionRow>> getSessions(String businessId) =>
      _sessionsQuery(businessId).get();

  SimpleSelectStatement<$LocalSessionsTable, LocalSessionRow> _sessionsQuery(
    String businessId,
  ) {
    return _db.select(_db.localSessions)
      ..where(
        (t) => t.businessId.equals(businessId) & t.isDeleted.equals(false),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc),
      ]);
  }

  Future<LocalSessionRow?> findSession(String id) => (_db.select(
    _db.localSessions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<String>> activeSessionIds(String businessId) async {
    final rows =
        await (_db.selectOnly(_db.localSessions)
              ..addColumns([_db.localSessions.id])
              ..where(
                _db.localSessions.businessId.equals(businessId) &
                    _db.localSessions.isDeleted.equals(false) &
                    _db.localSessions.status.isIn([
                      SessionStatus.active.name,
                      SessionStatus.paused.name,
                    ]),
              ))
            .get();
    return rows
        .map((row) => row.read(_db.localSessions.id))
        .whereType<String>()
        .toList(growable: false);
  }

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

  Future<Map<String, List<LocalSessionItemRow>>> itemsForSessions(
    List<String> sessionIds,
  ) async {
    if (sessionIds.isEmpty) return const {};
    final rows =
        await (_db.select(_db.localSessionItems)
              ..where((t) => t.sessionId.isIn(sessionIds))
              ..orderBy([(t) => OrderingTerm(expression: t.createdAtServer)]))
            .get();
    final grouped = <String, List<LocalSessionItemRow>>{};
    for (final row in rows) {
      (grouped[row.sessionId] ??= <LocalSessionItemRow>[]).add(row);
    }
    return grouped;
  }

  Stream<Map<String, List<LocalSessionItemRow>>> watchItemsForSessions(
    List<String> sessionIds,
  ) {
    if (sessionIds.isEmpty) return Stream.value(const {});
    return (_db.select(_db.localSessionItems)
          ..where((t) => t.sessionId.isIn(sessionIds))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAtServer)]))
        .watch()
        .map((rows) {
          final grouped = <String, List<LocalSessionItemRow>>{};
          for (final row in rows) {
            (grouped[row.sessionId] ??= <LocalSessionItemRow>[]).add(row);
          }
          return grouped;
        });
  }

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

  /// Offline tamamla/iptal: açık zaman aralığını ve seans durumunu atomik
  /// kapatır. Sunucu kabulü gelene kadar kayıt `pending` kalır.
  Future<void> finalizeSessionLocally({
    required String sessionId,
    required SessionStatus status,
    required DateTime endedAt,
  }) {
    if (status != SessionStatus.completed &&
        status != SessionStatus.cancelled) {
      throw ArgumentError.value(status, 'status', 'Terminal durum olmalıdır.');
    }
    return _db.transaction(() async {
      final session = await findSession(sessionId);
      if (session == null) throw StateError('session_not_found');
      if (session.status != SessionStatus.active.name &&
          session.status != SessionStatus.paused.name) {
        throw StateError('invalid_session_state');
      }
      await (_db.update(_db.localSessionTimeEntries)
            ..where((t) => t.sessionId.equals(sessionId) & t.endedAt.isNull()))
          .write(LocalSessionTimeEntriesCompanion(endedAt: Value(endedAt)));
      await (_db.update(
        _db.localSessions,
      )..where((t) => t.id.equals(sessionId))).write(
        LocalSessionsCompanion(
          status: Value(status.name),
          endedAt: Value(endedAt),
          syncStatus: Value(SyncStatus.pending.wireName),
          updatedAtLocal: Value(endedAt),
        ),
      );
    });
  }

  /// Offline eklenen ürün kalemini fiyat snapshot'ıyla saklar ve seansı
  /// senkronizasyon bekliyor olarak işaretler.
  Future<void> addPendingSessionItem({
    required SessionItem item,
    required DateTime now,
  }) {
    return _db.transaction(() async {
      final session = await findSession(item.sessionId);
      if (session == null) throw StateError('session_not_found');
      if (session.status != SessionStatus.active.name &&
          session.status != SessionStatus.paused.name) {
        throw StateError('invalid_session_state');
      }
      await _db
          .into(_db.localSessionItems)
          .insert(
            LocalSessionItemsCompanion.insert(
              id: item.id,
              businessId: item.businessId,
              sessionId: item.sessionId,
              productId: Value(item.productId),
              productNameSnapshot: item.productNameSnapshot,
              skuSnapshot: Value(item.skuSnapshot),
              unitPriceMinorSnapshot: item.unitPriceMinorSnapshot,
              currencyCodeSnapshot: item.currencyCodeSnapshot,
              quantity: item.quantity,
              discountMinor: item.discountMinor,
              taxMinor: item.taxMinor,
              lineTotalMinor: item.lineTotalMinor,
              createdAtServer: item.createdAt.toUtc(),
              updatedAtServer: item.updatedAt.toUtc(),
            ),
          );
      await (_db.update(
        _db.localSessions,
      )..where((t) => t.id.equals(item.sessionId))).write(
        LocalSessionsCompanion(
          syncStatus: Value(SyncStatus.pending.wireName),
          updatedAtLocal: Value(now),
        ),
      );
    });
  }

  /// Sunucuda tamamlanan/iptal edilen bir seansı yerel operasyonel kopyada da
  /// kapatır. Açık zaman aralığı ve seans durumu aynı transaction'da değişir.
  Future<void> reconcileTerminalState({
    required String sessionId,
    required SessionStatus status,
    required DateTime endedAt,
  }) {
    if (status != SessionStatus.completed &&
        status != SessionStatus.cancelled) {
      throw ArgumentError.value(status, 'status', 'Terminal durum olmalıdır.');
    }
    return _db.transaction(() async {
      final session = await findSession(sessionId);
      if (session == null) return;
      await (_db.update(_db.localSessionTimeEntries)
            ..where((t) => t.sessionId.equals(sessionId) & t.endedAt.isNull()))
          .write(LocalSessionTimeEntriesCompanion(endedAt: Value(endedAt)));
      await (_db.update(
        _db.localSessions,
      )..where((t) => t.id.equals(sessionId))).write(
        LocalSessionsCompanion(
          status: Value(status.name),
          endedAt: Value(endedAt),
          updatedAtLocal: Value(endedAt),
        ),
      );
    });
  }

  /// Sunucudaki kanonik seans görünümünü yerel operasyonel kopyaya uygular.
  /// Pending/local-only kayıtlar outbox tamamlanana kadar korunur.
  Future<void> reconcileServerSessions({
    required List<Session> sessions,
    required Map<String, List<SessionTimeEntry>> timeEntriesBySession,
  }) {
    return _db.transaction(() async {
      for (final session in sessions) {
        final existing = await findSession(session.id);
        if (existing != null &&
            existing.syncStatus != SyncStatus.synced.wireName) {
          continue;
        }

        await _db
            .into(_db.localSessions)
            .insertOnConflictUpdate(
              LocalSessionsCompanion.insert(
                id: session.id,
                businessId: session.businessId,
                customerId: Value(session.customerId),
                serviceId: session.serviceId,
                openedByMemberId: session.openedByMemberId,
                closedByMemberId: Value(session.closedByMemberId),
                status: session.status.name,
                startedAt: session.startedAt.toUtc(),
                endedAt: Value(session.endedAt?.toUtc()),
                serviceNameSnapshot: session.serviceNameSnapshot,
                pricePerMinuteMinorSnapshot:
                    session.pricePerMinuteMinorSnapshot,
                roundingIntervalMinutesSnapshot:
                    session.roundingIntervalMinutesSnapshot,
                minimumChargeMinutesSnapshot:
                    session.minimumChargeMinutesSnapshot,
                currencyCodeSnapshot: session.currencyCodeSnapshot,
                notes: Value(session.notes),
                syncStatus: SyncStatus.synced.wireName,
                startedOffline: const Value(false),
                createdAtLocal: session.createdAt.toUtc(),
                updatedAtLocal: session.updatedAt.toUtc(),
              ),
            );

        if ((session.status == SessionStatus.completed ||
                session.status == SessionStatus.cancelled) &&
            session.endedAt != null) {
          await (_db.update(_db.localSessionTimeEntries)..where(
                (t) => t.sessionId.equals(session.id) & t.endedAt.isNull(),
              ))
              .write(
                LocalSessionTimeEntriesCompanion(
                  endedAt: Value(session.endedAt!.toUtc()),
                ),
              );
        }

        final serverEntries = timeEntriesBySession[session.id];
        if (serverEntries == null) continue;
        await (_db.delete(
          _db.localSessionTimeEntries,
        )..where((t) => t.sessionId.equals(session.id))).go();
        for (final entry in serverEntries) {
          await _db
              .into(_db.localSessionTimeEntries)
              .insert(
                LocalSessionTimeEntriesCompanion.insert(
                  id: entry.id,
                  businessId: entry.businessId,
                  sessionId: entry.sessionId,
                  entryType: entry.entryType.name,
                  startedAt: entry.startedAt.toUtc(),
                  endedAt: Value(entry.endedAt?.toUtc()),
                  createdAtLocal: entry.createdAt.toUtc(),
                  syncStatus: SyncStatus.synced.wireName,
                ),
              );
        }
      }
    });
  }

  /// Sunucunun kanonik ürün kalemi snapshot'ını tek seans için atomik değiştirir.
  Future<void> reconcileServerItems({
    required String sessionId,
    required List<SessionItem> items,
  }) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.localSessionItems,
      )..where((t) => t.sessionId.equals(sessionId))).go();
      for (final item in items) {
        if (item.sessionId != sessionId) {
          throw ArgumentError.value(
            item.sessionId,
            'items',
            'Ürün kalemi farklı bir seansa ait.',
          );
        }
        await _db
            .into(_db.localSessionItems)
            .insert(
              LocalSessionItemsCompanion.insert(
                id: item.id,
                businessId: item.businessId,
                sessionId: item.sessionId,
                productId: Value(item.productId),
                productNameSnapshot: item.productNameSnapshot,
                skuSnapshot: Value(item.skuSnapshot),
                unitPriceMinorSnapshot: item.unitPriceMinorSnapshot,
                currencyCodeSnapshot: item.currencyCodeSnapshot,
                quantity: item.quantity,
                discountMinor: item.discountMinor,
                taxMinor: item.taxMinor,
                lineTotalMinor: item.lineTotalMinor,
                createdAtServer: item.createdAt.toUtc(),
                updatedAtServer: item.updatedAt.toUtc(),
              ),
            );
      }
    });
  }

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
