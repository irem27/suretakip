import 'package:drift/drift.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';

/// İşletme ve üyelik önbelleğini yöneten Drift katmanı. Yalnızca read-through
/// önbellek: sunucudan gelen kayıtlar yazılır, internetsizde okunur.
class BusinessesLocalDataSource {
  const BusinessesLocalDataSource(this._db);

  final AppDatabase _db;

  /// Aktif işletme listesini (sunucudaki `is_active=true` kümesi) önbelleğe
  /// tam olarak yansıtır: eski kopya silinir, yenisi tek transaction'da yazılır.
  Future<void> replaceBusinesses(List<Business> businesses) =>
      _db.transaction(() async {
        await _db.delete(_db.localBusinesses).go();
        for (final business in businesses) {
          await _db
              .into(_db.localBusinesses)
              .insertOnConflictUpdate(_businessToCompanion(business));
        }
      });

  Future<List<Business>> getBusinesses() async {
    final rows =
        await (_db.select(_db.localBusinesses)
              ..where((t) => t.isActive.equals(true))
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
            .get();
    return rows.map(_businessFromRow).toList(growable: false);
  }

  Future<Business?> getBusiness(String id) async {
    final row = await (_db.select(
      _db.localBusinesses,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _businessFromRow(row);
  }

  Future<void> upsertBusiness(Business business) => _db
      .into(_db.localBusinesses)
      .insertOnConflictUpdate(_businessToCompanion(business));

  /// Bir işletmenin üyelerini önbelleğe yansıtır (o işletmenin eski üye
  /// kopyaları silinir, yeni liste yazılır).
  Future<void> replaceMembers(
    String businessId,
    List<BusinessMember> members,
  ) => _db.transaction(() async {
    await (_db.delete(
      _db.localBusinessMembers,
    )..where((t) => t.businessId.equals(businessId))).go();
    for (final member in members) {
      await _db
          .into(_db.localBusinessMembers)
          .insertOnConflictUpdate(_memberToCompanion(member));
    }
  });

  Future<List<BusinessMember>> getMembers(String businessId) async {
    final rows =
        await (_db.select(_db.localBusinessMembers)
              ..where((t) => t.businessId.equals(businessId))
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
            .get();
    return rows.map(_memberFromRow).toList(growable: false);
  }

  LocalBusinessesCompanion _businessToCompanion(Business b) =>
      LocalBusinessesCompanion.insert(
        id: b.id,
        name: b.name,
        currencyCode: b.currencyCode,
        timezone: b.timezone,
        isActive: Value(b.isActive),
        archivedAt: Value(b.archivedAt),
        createdAt: b.createdAt,
        updatedAt: b.updatedAt,
      );

  Business _businessFromRow(LocalBusinessRow row) => Business(
    id: row.id,
    name: row.name,
    currencyCode: row.currencyCode,
    timezone: row.timezone,
    isActive: row.isActive,
    archivedAt: row.archivedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  LocalBusinessMembersCompanion _memberToCompanion(BusinessMember m) =>
      LocalBusinessMembersCompanion.insert(
        id: m.id,
        businessId: m.businessId,
        userId: m.userId,
        role: m.role.name,
        isActive: Value(m.isActive),
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
      );

  BusinessMember _memberFromRow(LocalBusinessMemberRow row) => BusinessMember(
    id: row.id,
    businessId: row.businessId,
    userId: row.userId,
    role: MemberRole.values.byName(row.role),
    isActive: row.isActive,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
