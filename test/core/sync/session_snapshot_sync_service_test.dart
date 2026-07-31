import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/sync/session_snapshot_sync_service.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';

void main() {
  test(
    'sunucu seanslarını ve açık zaman kayıtlarını yerelde uzlaştırır',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = _SnapshotRepository();
      final service = SessionSnapshotSyncService(
        repository: repository,
        local: SessionsLocalDataSource(db),
      );

      await service.sync('biz-1');

      expect(repository.loadedBusinessId, 'biz-1');
      expect((await db.select(db.localSessions).get()), hasLength(1));
      expect((await db.select(db.localSessionTimeEntries).get()), hasLength(1));
      expect((await db.select(db.localSessionItems).get()), hasLength(1));
    },
  );

  test(
    'tam geçmişi çekmeden yerelde açık kalmış terminal seansı uzlaştırır',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final local = SessionsLocalDataSource(db);
      final active = _SnapshotRepository.baseSession;
      await local.reconcileServerSessions(
        sessions: [active],
        timeEntriesBySession: {
          active.id: [
            SessionTimeEntry(
              id: 'entry-1',
              businessId: active.businessId,
              sessionId: active.id,
              entryType: TimeEntryType.active,
              startedAt: active.startedAt,
              endedAt: null,
              createdAt: active.createdAt,
            ),
          ],
        },
      );
      final endedAt = active.startedAt.add(const Duration(minutes: 45));
      final repository = _SnapshotRepository(
        openSessions: const [],
        sessionsById: [
          active.copyWith(
            status: SessionStatus.completed,
            endedAt: endedAt,
            updatedAt: endedAt,
          ),
        ],
      );

      await SessionSnapshotSyncService(
        repository: repository,
        local: local,
      ).sync('biz-1');

      expect(repository.requestedSessionIds, [active.id]);
      expect(
        (await local.findSession(active.id))!.status,
        SessionStatus.completed.name,
      );
      expect(
        (await local.timeEntries(active.id)).single.endedAt!.toUtc(),
        endedAt,
      );
    },
  );

  test(
    'ürün snapshot sorgusu bozulsa da seans ve zaman kaydını uzlaştırır',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final logger = _RecordingLogger();

      await SessionSnapshotSyncService(
        repository: _SnapshotRepository(failItems: true),
        local: SessionsLocalDataSource(db),
        logger: logger,
      ).sync('biz-1');

      expect((await db.select(db.localSessions).get()), hasLength(1));
      expect((await db.select(db.localSessionTimeEntries).get()), hasLength(1));
      expect((await db.select(db.localSessionItems).get()), isEmpty);
      expect(logger.warningContexts, ['SessionSnapshotItems']);
    },
  );
}

final class _SnapshotRepository implements SessionsRepository {
  _SnapshotRepository({
    List<Session>? openSessions,
    this.sessionsById = const [],
    this.failItems = false,
  }) : openSessions = openSessions ?? [baseSession];

  String? loadedBusinessId;
  List<String> requestedSessionIds = [];
  final List<Session> openSessions;
  final List<Session> sessionsById;
  final bool failItems;

  static final baseSession = Session(
    id: 'session-1',
    businessId: 'biz-1',
    customerId: null,
    serviceId: 'service-1',
    openedByMemberId: 'member-1',
    closedByMemberId: null,
    status: SessionStatus.active,
    startedAt: DateTime.utc(2026, 7, 23, 10),
    endedAt: null,
    chargedMinutes: null,
    serviceNameSnapshot: 'Bilardo',
    pricePerMinuteMinorSnapshot: 200,
    roundingIntervalMinutesSnapshot: 5,
    minimumChargeMinutesSnapshot: 10,
    currencyCodeSnapshot: 'TRY',
    serviceSubtotalMinor: null,
    productsSubtotalMinor: null,
    discountMinor: 0,
    taxMinor: 0,
    grandTotalMinor: null,
    notes: null,
    createdAt: DateTime.utc(2026, 7, 23, 10),
    updatedAt: DateTime.utc(2026, 7, 23, 10),
  );

  @override
  Future<List<Session>> getOpenSessions({required String businessId}) async {
    loadedBusinessId = businessId;
    return openSessions;
  }

  @override
  Future<List<Session>> getSessionsByIds({
    required String businessId,
    required List<String> sessionIds,
  }) async {
    expect(businessId, 'biz-1');
    requestedSessionIds = sessionIds;
    return sessionsById
        .where((session) => sessionIds.contains(session.id))
        .toList(growable: false);
  }

  @override
  Future<Map<String, List<SessionTimeEntry>>> getTimeEntriesForSessions(
    List<String> sessionIds,
  ) async => {
    for (final session in openSessions)
      session.id: [
        SessionTimeEntry(
          id: 'entry-1',
          businessId: 'biz-1',
          sessionId: session.id,
          entryType: TimeEntryType.active,
          startedAt: session.startedAt,
          endedAt: null,
          createdAt: session.createdAt,
        ),
      ],
  };

  @override
  Future<Map<String, List<SessionItem>>> getItemsForSessions(
    List<String> sessionIds,
  ) async {
    if (failItems) throw StateError('item snapshot failed');
    return {
      for (final session in openSessions)
        session.id: [
          SessionItem(
            id: 'item-1',
            businessId: 'biz-1',
            sessionId: session.id,
            productId: 'product-1',
            productNameSnapshot: 'Su',
            skuSnapshot: null,
            unitPriceMinorSnapshot: 300,
            currencyCodeSnapshot: 'TRY',
            quantity: 2,
            discountMinor: 0,
            taxMinor: 0,
            lineTotalMinor: 600,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt,
          ),
        ],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingLogger implements AppLogger {
  final warningContexts = <String?>[];

  @override
  void error(Object error, {StackTrace? stackTrace, String? context}) {}

  @override
  void info(Object message, {String? context}) {}

  @override
  void warn(Object warning, {StackTrace? stackTrace, String? context}) {
    warningContexts.add(context);
  }
}
