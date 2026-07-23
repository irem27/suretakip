import 'package:drift/drift.dart';

/// İşletme üyeliklerinin (rol dahil) cihazdaki read-through önbelleği. Rol
/// bilgisi internetsizde de yetki hesaplaması (owner/admin/staff) için
/// gereklidir. Üyelik mutasyonları sunucudaki `security definer` RPC'lerle
/// yapılır; bu tablo yalnızca önbellektir.
@DataClassName('LocalBusinessMemberRow')
class LocalBusinessMembers extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get userId => text()();
  TextColumn get role => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
