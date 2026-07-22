import 'package:uuid/uuid.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/logging/noop_app_logger.dart';
import 'package:suretakip/core/sync/customer_delta_store.dart';
import 'package:suretakip/core/sync/sync_pull_rpc.dart';

/// Müşteri delta pull ve bootstrap orkestrasyonu (Bölüm 15). Sunucudan gelen
/// değişiklikleri yerel Drift kopyasına, bekleyen/dirty kayıtları ezmeden,
/// sıralı ve cursor tabanlı biçimde uygular.
class CustomerDeltaSyncService {
  CustomerDeltaSyncService({
    required SyncPullApi pull,
    required CustomerDeltaStore store,
    Uuid? uuid,
    DateTime Function()? clock,
    AppLogger logger = const NoopAppLogger(),
  }) : _pull = pull,
       _store = store,
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _logger = logger;

  final SyncPullApi _pull;
  final CustomerDeltaStore _store;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final AppLogger _logger;

  // İş başına tek tur; farklı işletmeler birbirini bloklamaz ve turları
  // karışmaz (tenant-aware single-flight).
  final Map<String, Future<void>> _inFlight = {};

  /// Aynı işletme için aynı anda tek delta turu çalışır.
  Future<void> sync(String businessId) =>
      _inFlight[businessId] ??= _guarded(businessId);

  Future<void> _guarded(String businessId) async {
    try {
      await _sync(businessId);
    } catch (error, stack) {
      _logger.warn(error, stackTrace: stack, context: 'CustomerDeltaSync');
    } finally {
      _inFlight.remove(businessId);
    }
  }

  Future<void> _sync(String businessId) async {
    // Yarıda kalmış bir snapshot turu varsa önce onu tamamla (resume).
    final pendingGeneration = await _store.readGeneration(businessId);
    if (pendingGeneration != null) {
      await _bootstrap(businessId, pendingGeneration);
      return;
    }

    final cursor = await _store.readCursor(businessId);
    if (cursor == 0) {
      await _bootstrap(businessId, null);
      return;
    }

    final cursorTooOld = await _deltaPull(businessId, cursor);
    if (cursorTooOld) {
      // Kontrollü full resync: bekleyen outbox ve dirty kayıtlar korunur.
      await _bootstrap(businessId, null);
    }
  }

  /// Cursor sonrası değişiklikleri sayfalı çeker ve uygular. `CURSOR_TOO_OLD`
  /// için true döner (çağıran full resync yapar).
  Future<bool> _deltaPull(String businessId, int startCursor) async {
    var cursor = startCursor;
    while (true) {
      final page = await _pull.getChanges(
        businessId: businessId,
        cursor: cursor,
      );
      if (page.authRequired) return false;
      if (page.cursorTooOld) return true;
      if (page.changes.isNotEmpty) {
        await _store.applyChanges(page.changes);
      }
      cursor = page.nextCursor;
      await _store.writeCursor(businessId, cursor, _clock());
      if (!page.hasMore) break;
    }
    return false;
  }

  /// Bootstrap / full resync (Bölüm 15.1.1). Cursor snapshot'tan ÖNCE yakalanır;
  /// snapshot staging'e sayfalanır, kontrollü merge edilir, sonra delta çekilir.
  Future<void> _bootstrap(String businessId, String? existingGeneration) async {
    final generationId = existingGeneration ?? _uuid.v4();
    await _store.writeGeneration(businessId, generationId, _clock());

    var afterId = await _store.stagedMaxId(generationId);
    final persistedCursor = await _store.readSnapshotCursor(businessId);
    var captured = persistedCursor != null;
    var snapshotCursor = persistedCursor ?? 0;

    while (true) {
      final page = await _pull.getCustomersSnapshot(
        businessId: businessId,
        afterId: afterId,
      );
      // Auth/forbidden/rejected: KESİNLİKLE merge/tombstone yapma; generation
      // korunur, bağlantı/oturum düzelince aynı tur devam eder (veri kaybı yok).
      if (!page.ok) return;
      if (!captured) {
        snapshotCursor = page.serverCursor;
        captured = true;
        await _store.writeSnapshotCursor(businessId, snapshotCursor, _clock());
      }
      if (page.customers.isNotEmpty) {
        await _store.stageSnapshot(generationId, page.customers);
      }
      afterId = page.nextAfterId;
      if (!page.hasMore) break;
    }

    final cursor = snapshotCursor;
    await _store.mergeStagedSnapshot(
      generationId: generationId,
      businessId: businessId,
      cursor: cursor,
      now: _clock(),
    );

    // Snapshot sırasında oluşan değişiklikleri delta ile tamamla.
    await _deltaPull(businessId, cursor);
  }
}
