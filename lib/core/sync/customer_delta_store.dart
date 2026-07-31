import 'package:drift/drift.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/sync/models/delta_models.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/features/customers/data/local/customers_local_data_source.dart';

/// Delta pull ve bootstrap'ın tüm yerel (Drift) yan etkilerini kapsüller:
/// cursor saklama, snapshot staging, kontrollü dirty-aware merge ve tombstone.
class CustomerDeltaStore {
  CustomerDeltaStore(this._db, this._local);

  final AppDatabase _db;
  final CustomersLocalDataSource _local;

  // Anahtarlar business'a göre ayrılır; işletme değişince cursor/staging
  // karışmaz (tenant izolasyonu).
  static String _cursorKey(String businessId) =>
      'customers_changes_cursor:$businessId';
  static String _generationKey(String businessId) =>
      'customers_snapshot_generation:$businessId';
  static String _snapshotCursorKey(String businessId) =>
      'customers_snapshot_cursor:$businessId';

  static const _dirtyStatuses = <String>{
    'localOnly',
    'pending',
    'processing',
    'retrying',
    'conflicted',
  };

  // ---- Cursor / durum ----

  Future<int> readCursor(String businessId) async {
    final value = await _readState(_cursorKey(businessId));
    return value == null ? 0 : (int.tryParse(value) ?? 0);
  }

  Future<void> writeCursor(String businessId, int cursor, DateTime now) =>
      _writeState(_cursorKey(businessId), '$cursor', now);

  Future<String?> readGeneration(String businessId) =>
      _readState(_generationKey(businessId));

  Future<void> writeGeneration(
    String businessId,
    String? generationId,
    DateTime now,
  ) => generationId == null
      ? _deleteState(_generationKey(businessId))
      : _writeState(_generationKey(businessId), generationId, now);

  /// Devam eden snapshot turunun snapshot-öncesi cursor'ı (yarıda kalırsa
  /// aynı değerle devam edilir).
  Future<int?> readSnapshotCursor(String businessId) async {
    final value = await _readState(_snapshotCursorKey(businessId));
    return value == null ? null : int.tryParse(value);
  }

  Future<void> writeSnapshotCursor(
    String businessId,
    int cursor,
    DateTime now,
  ) => _writeState(_snapshotCursorKey(businessId), '$cursor', now);

  // ---- Delta uygulama ----

  /// Change feed sayfasını dirty-aware uygular. Bekleyen/çatışmalı yerel
  /// kayıtlar ezilmez; tombstone yalnız temiz kayıtlara işlenir.
  Future<void> applyChanges(Iterable<SyncChange> changes) {
    return _db.transaction(() async {
      for (final change in changes) {
        if (change.entityType != 'customer') continue;
        if (change.isDelete) {
          await _tombstone(change.entityId);
        } else if (change.payload != null) {
          await _local.upsertServerCustomers([
            _snapshotFromPayload(change.payload!, change.serverVersion),
          ]);
        }
      }
    });
  }

  Future<void> _tombstone(String id) async {
    final existing = await _local.findCustomer(id);
    if (existing == null) return;
    if (_dirtyStatuses.contains(existing.syncStatus)) return; // dirty korunur
    await (_db.update(_db.localCustomers)..where((t) => t.id.equals(id))).write(
      const LocalCustomersCompanion(isDeleted: Value(true)),
    );
  }

  // ---- Bootstrap staging ----

  Future<void> stageSnapshot(
    String generationId,
    Iterable<ServerCustomerSnapshot> customers,
  ) {
    return _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.customerSnapshotStaging, [
        for (final c in customers)
          CustomerSnapshotStagingCompanion.insert(
            generationId: generationId,
            id: c.id,
            businessId: c.businessId,
            name: c.name,
            phone: Value(c.phone),
            email: Value(c.email),
            notes: Value(c.notes),
            isActive: Value(c.isActive),
            serverVersion: c.serverVersion,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
          ),
      ]);
    });
  }

  /// Yarıda kalan snapshot turunun devam edeceği son id (id sıralı).
  Future<String?> stagedMaxId(String generationId) async {
    final maxExpr = _db.customerSnapshotStaging.id.max();
    final query = _db.selectOnly(_db.customerSnapshotStaging)
      ..addColumns([maxExpr])
      ..where(_db.customerSnapshotStaging.generationId.equals(generationId));
    return query.map((row) => row.read(maxExpr)).getSingleOrNull();
  }

  /// Staging snapshot'ı kontrollü merge eder (Bölüm 15.1.1):
  /// - temiz yerel kopyaları upsert,
  /// - dirty (bekleyen) kayıtları KORUR,
  /// - snapshot'ta olmayan TEMİZ yerel kayıtları tombstone (dirty'yi değil),
  /// - staging'i temizler; hepsi tek transaction.
  Future<void> mergeStagedSnapshot({
    required String generationId,
    required String businessId,
    required int cursor,
    required DateTime now,
  }) {
    return _db.transaction(() async {
      final staged = await (_db.select(
        _db.customerSnapshotStaging,
      )..where((t) => t.generationId.equals(generationId))).get();

      await _local.upsertServerCustomers(
        staged.map(
          (s) => ServerCustomerSnapshot(
            id: s.id,
            businessId: s.businessId,
            name: s.name,
            phone: s.phone,
            email: s.email,
            notes: s.notes,
            isActive: s.isActive,
            serverVersion: s.serverVersion,
            createdAt: s.createdAt,
            updatedAt: s.updatedAt,
          ),
        ),
      );

      // Snapshot'ta bulunmayan TEMİZ (synced) yerel kayıtlar sunucuda silinmiş
      // sayılır → tombstone. Dirty kayıtlara dokunulmaz.
      final stagedIds = staged.map((s) => s.id).toSet();
      final locals =
          await (_db.select(_db.localCustomers)..where(
                (t) =>
                    t.businessId.equals(businessId) &
                    t.isDeleted.equals(false) &
                    t.syncStatus.equals(SyncStatus.synced.wireName),
              ))
              .get();
      for (final local in locals) {
        if (stagedIds.contains(local.id)) continue;
        await (_db.update(_db.localCustomers)
              ..where((t) => t.id.equals(local.id)))
            .write(const LocalCustomersCompanion(isDeleted: Value(true)));
      }

      await (_db.delete(
        _db.customerSnapshotStaging,
      )..where((t) => t.generationId.equals(generationId))).go();
      await _writeStateTx(_cursorKey(businessId), '$cursor', now);
      await _deleteStateTx(_generationKey(businessId));
      await _deleteStateTx(_snapshotCursorKey(businessId));
    });
  }

  ServerCustomerSnapshot _snapshotFromPayload(
    Map<String, dynamic> payload,
    int serverVersion,
  ) => ServerCustomerSnapshot(
    id: payload['id'] as String,
    businessId: payload['business_id'] as String,
    name: payload['name'] as String,
    phone: payload['phone'] as String?,
    email: payload['email'] as String?,
    notes: payload['notes'] as String?,
    isActive: payload['is_active'] as bool? ?? true,
    serverVersion: serverVersion,
    createdAt: _date(payload['created_at']),
    updatedAt: _date(payload['updated_at']),
  );

  // ---- sync_state yardımcıları ----

  Future<String?> _readState(String key) async {
    final row = await (_db.select(
      _db.syncState,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _writeState(String key, String value, DateTime now) => _db
      .into(_db.syncState)
      .insertOnConflictUpdate(
        SyncStateRow(key: key, value: value, updatedAt: now),
      );

  Future<void> _writeStateTx(String key, String value, DateTime now) => _db
      .into(_db.syncState)
      .insertOnConflictUpdate(
        SyncStateRow(key: key, value: value, updatedAt: now),
      );

  Future<void> _deleteState(String key) =>
      (_db.delete(_db.syncState)..where((t) => t.key.equals(key))).go();

  Future<void> _deleteStateTx(String key) =>
      (_db.delete(_db.syncState)..where((t) => t.key.equals(key))).go();

  DateTime _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    throw const FormatException('Geçersiz zaman damgası.');
  }
}
