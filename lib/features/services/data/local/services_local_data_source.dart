import 'package:drift/drift.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';

/// Hizmet önbelleğini yöneten Drift katmanı (read-through). Yalnız okuma
/// önbelleği; yazma sunucuda yapılır.
class ServicesLocalDataSource {
  const ServicesLocalDataSource(this._db);

  final AppDatabase _db;

  /// Bir işletmenin hizmetlerini önbelleğe yansıtır (eski kopya silinir).
  Future<void> replaceServices(String businessId, List<Service> services) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.localServices,
        )..where((t) => t.businessId.equals(businessId))).go();
        for (final service in services) {
          await _db
              .into(_db.localServices)
              .insertOnConflictUpdate(_toCompanion(service));
        }
      });

  Future<List<Service>> getServices({
    required String businessId,
    bool includeInactive = false,
  }) async {
    final query = _db.select(_db.localServices)
      ..where((t) => t.businessId.equals(businessId))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (!includeInactive) query.where((t) => t.isActive.equals(true));
    final rows = await query.get();
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<Service?> getService(String id) async {
    final row = await (_db.select(
      _db.localServices,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<void> upsertService(Service service) => _db
      .into(_db.localServices)
      .insertOnConflictUpdate(_toCompanion(service));

  LocalServicesCompanion _toCompanion(Service s) => LocalServicesCompanion.insert(
    id: s.id,
    businessId: s.businessId,
    name: s.name,
    pricePerMinuteMinor: s.pricePerMinuteMinor,
    roundingIntervalMinutes: s.roundingIntervalMinutes,
    minimumChargeMinutes: s.minimumChargeMinutes,
    currencyCode: s.currencyCode,
    isActive: Value(s.isActive),
    archivedAt: Value(s.archivedAt),
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
  );

  Service _fromRow(LocalServiceRow row) => Service(
    id: row.id,
    businessId: row.businessId,
    name: row.name,
    pricePerMinuteMinor: row.pricePerMinuteMinor,
    roundingIntervalMinutes: row.roundingIntervalMinutes,
    minimumChargeMinutes: row.minimumChargeMinutes,
    currencyCode: row.currencyCode,
    isActive: row.isActive,
    archivedAt: row.archivedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
