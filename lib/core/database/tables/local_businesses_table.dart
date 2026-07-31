import 'package:drift/drift.dart';

/// İşletmelerin cihazdaki salt-okunur önbelleği. İşletme kayıtları sunucuda
/// (onboarding + üyelik RPC'leri) yönetilir; bu tablo yalnızca uygulamanın
/// internetsiz açılıp son senkronlanmış işletme listesini okuyabilmesi için
/// bir read-through önbellektir (yazma yok, outbox yok).
@DataClassName('LocalBusinessRow')
class LocalBusinesses extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get currencyCode => text()();
  TextColumn get timezone => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
