import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';

/// Sunucu seans görünümünü Drift operasyonel kopyasıyla uzlaştırır.
///
/// Bu servis, başka cihazda oluşturulan veya kapatılan seansların da yerel
/// açık işlem listesine doğru biçimde yansımasını sağlar. Pending yerel
/// kayıtların korunması [SessionsLocalDataSource] sorumluluğundadır.
final class SessionSnapshotSyncService {
  const SessionSnapshotSyncService({
    required SessionsRepository repository,
    required SessionsLocalDataSource local,
    AppLogger logger = const NoopAppLogger(),
  }) : _repository = repository,
       _local = local,
       _logger = logger;

  final SessionsRepository _repository;
  final SessionsLocalDataSource _local;
  final AppLogger _logger;

  Future<void> sync(String businessId) async {
    final (openSessions, localOpenIds) = await (
      _repository.getOpenSessions(businessId: businessId),
      _local.activeSessionIds(businessId),
    ).wait;
    final openSessionIds = openSessions
        .map((session) => session.id)
        .toList(growable: false);
    final serverOpenIds = openSessionIds.toSet();
    final possiblyClosedIds = localOpenIds
        .where((id) => !serverOpenIds.contains(id))
        .toList(growable: false);
    final closedSessions = await _repository.getSessionsByIds(
      businessId: businessId,
      sessionIds: possiblyClosedIds,
    );
    final itemsSnapshotFuture = _fetchItems(openSessionIds);
    final entriesBySession = await _repository.getTimeEntriesForSessions(
      openSessionIds,
    );
    await _local.reconcileServerSessions(
      sessions: [...openSessions, ...closedSessions],
      timeEntriesBySession: entriesBySession,
    );
    final itemsSnapshot = await itemsSnapshotFuture;
    if (itemsSnapshot case _FailedItemsSnapshot(:final error, :final stack)) {
      _logger.warn(error, stackTrace: stack, context: 'SessionSnapshotItems');
      return;
    }
    final fetchedItemsBySession =
        (itemsSnapshot as _SuccessfulItemsSnapshot).itemsBySession;
    for (final sessionId in openSessionIds) {
      await _local.reconcileServerItems(
        sessionId: sessionId,
        items: fetchedItemsBySession[sessionId] ?? const [],
      );
    }
  }

  Future<_ItemsSnapshot> _fetchItems(List<String> sessionIds) async {
    try {
      return _SuccessfulItemsSnapshot(
        await _repository.getItemsForSessions(sessionIds),
      );
    } catch (error, stackTrace) {
      return _FailedItemsSnapshot(error, stackTrace);
    }
  }
}

sealed class _ItemsSnapshot {
  const _ItemsSnapshot();
}

final class _SuccessfulItemsSnapshot extends _ItemsSnapshot {
  const _SuccessfulItemsSnapshot(this.itemsBySession);

  final Map<String, List<SessionItem>> itemsBySession;
}

final class _FailedItemsSnapshot extends _ItemsSnapshot {
  const _FailedItemsSnapshot(this.error, this.stack);

  final Object error;
  final StackTrace stack;
}
