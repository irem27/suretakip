import 'package:uuid/uuid.dart';
import 'package:suretakip/core/database/app_database.dart';

/// Cihaz/kurulum kimliğini üretir ve `sync_state` içinde kalıcı saklar. Aynı
/// kurulum idempotency anahtarında değişmez bir `device_id` kullanır (Bölüm 7).
class DeviceIdentity {
  DeviceIdentity(this._db, {Uuid? uuid, DateTime Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _clock = clock ?? (() => DateTime.now().toUtc());

  static const _key = 'device_id';

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Future<String> getOrCreate() async {
    final existing = await (_db.select(
      _db.syncState,
    )..where((t) => t.key.equals(_key))).getSingleOrNull();
    if (existing?.value != null) return existing!.value!;

    final id = _uuid.v4();
    await _db
        .into(_db.syncState)
        .insertOnConflictUpdate(
          SyncStateRow(key: _key, value: id, updatedAt: _clock()),
        );
    return id;
  }
}
