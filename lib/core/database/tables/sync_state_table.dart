import 'package:drift/drift.dart';

/// Delta cursor, son başarılı sync zamanı ve cihaz bilgisi gibi tekil sync
/// meta verilerini tutan basit anahtar-değer tablosu.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
