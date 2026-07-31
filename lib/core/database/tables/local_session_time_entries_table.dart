import 'package:drift/drift.dart';

/// Seansın çalışma/duraklama aralıkları. Aktif süre bu aralıkların
/// `startedAt`/`endedAt` damgalarından türetilir (append-only; Bölüm 13.2).
@DataClassName('LocalSessionTimeEntryRow')
class LocalSessionTimeEntries extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get sessionId => text()();

  /// active, paused.
  TextColumn get entryType => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  DateTimeColumn get createdAtLocal => dateTime()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
