import 'package:drift/drift.dart';

/// Bootstrap/full-resync sırasında sunucu snapshot'ı önce buraya yazılır, sonra
/// kontrollü merge ile `local_customers`'a uygulanır (Bölüm 15.1.1). Böylece
/// "önce yerel tabloyu temizle, sonra yaz" gibi tehlikeli bir akış oluşmaz;
/// bekleyen/dirty yerel kayıtlar snapshot ile ezilmez.
@DataClassName('CustomerSnapshotStagingRow')
class CustomerSnapshotStaging extends Table {
  /// Aynı snapshot turunu işaretler; yarıda kesilen tur devam edebilir.
  TextColumn get generationId => text()();
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get serverVersion => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {generationId, id};
}
