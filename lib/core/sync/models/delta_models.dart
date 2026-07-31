import 'package:suretakip/features/customers/data/local/customers_local_data_source.dart';

/// Change feed'den gelen tek bir değişiklik (Bölüm 15.1).
final class SyncChange {
  const SyncChange({
    required this.changeSeq,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.serverVersion,
    this.payload,
  });

  final int changeSeq;
  final String entityType;
  final String entityId;

  /// 'upsert' | 'delete'
  final String operation;
  final int serverVersion;
  final Map<String, dynamic>? payload;

  bool get isDelete => operation == 'delete';
}

/// `get_changes` sonucu. `cursorTooOld` true ise istemci full resync yapmalıdır.
final class ChangesPage {
  const ChangesPage({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
    this.cursorTooOld = false,
    this.authRequired = false,
  });

  const ChangesPage.cursorTooOld()
    : changes = const [],
      nextCursor = 0,
      hasMore = false,
      cursorTooOld = true,
      authRequired = false;

  const ChangesPage.authRequired()
    : changes = const [],
      nextCursor = 0,
      hasMore = false,
      cursorTooOld = false,
      authRequired = true;

  final List<SyncChange> changes;
  final int nextCursor;
  final bool hasMore;
  final bool cursorTooOld;
  final bool authRequired;
}

/// `get_customers_snapshot` sayfası (keyset pagination).
///
/// [ok] false ise sunucu auth/forbidden/rejected döndürmüştür ve istemci
/// KESİNLİKLE merge/tombstone yapmamalıdır (aksi halde boş sanılan snapshot
/// yerel önbelleği siler — veri kaybı).
final class CustomerSnapshotPage {
  const CustomerSnapshotPage({
    required this.customers,
    required this.nextAfterId,
    required this.hasMore,
    required this.serverCursor,
    this.ok = true,
    this.authRequired = false,
  });

  const CustomerSnapshotPage.authRequired()
    : customers = const [],
      nextAfterId = null,
      hasMore = false,
      serverCursor = 0,
      ok = false,
      authRequired = true;

  const CustomerSnapshotPage.rejected()
    : customers = const [],
      nextAfterId = null,
      hasMore = false,
      serverCursor = 0,
      ok = false,
      authRequired = false;

  final List<ServerCustomerSnapshot> customers;
  final String? nextAfterId;
  final bool hasMore;

  /// Çağrı anındaki max change_seq. İlk sayfadaki değer snapshot-öncesi cursor
  /// olarak kullanılır (Bölüm 15.1.1, "cursor'ı snapshot'tan ÖNCE yakala").
  final int serverCursor;

  final bool ok;
  final bool authRequired;
}
