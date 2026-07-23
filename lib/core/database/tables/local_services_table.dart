import 'package:drift/drift.dart';

/// Hizmetlerin cihazdaki read-through önbelleği. Seans başlatma ve hizmet
/// listesi internetsizde de çalışsın diye son senkronlanan hizmetler burada
/// tutulur. Yazma sunucuda (katalog RPC/insert) yapılır; bu tablo önbellektir.
@DataClassName('LocalServiceRow')
class LocalServices extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get name => text()();
  IntColumn get pricePerMinuteMinor => integer()();
  IntColumn get roundingIntervalMinutes => integer()();
  IntColumn get minimumChargeMinutes => integer()();
  TextColumn get currencyCode => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
