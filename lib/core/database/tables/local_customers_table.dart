import 'package:drift/drift.dart';

/// Müşterilerin cihazdaki operasyonel kopyası. UI doğrudan Supabase yerine bu
/// tabloyu (Drift stream'i olarak) izler. `syncStatus` kaydın merkezle olan
/// durumunu taşır; `serverVersion` yalnız senkronizasyondan sonra dolar.
@DataClassName('LocalCustomerRow')
class LocalCustomers extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// local_only, pending, processing, retrying, synced, conflicted, rejected.
  TextColumn get syncStatus => text()();
  IntColumn get serverVersion => integer().nullable()();

  DateTimeColumn get createdAtLocal => dateTime()();
  DateTimeColumn get updatedAtLocal => dateTime()();
  DateTimeColumn get createdAtServer => dateTime().nullable()();
  DateTimeColumn get updatedAtServer => dateTime().nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Kullanıcıya güvenle gösterilebilecek son hata kodu.
  TextColumn get lastSyncError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
