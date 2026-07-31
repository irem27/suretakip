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

  /// Offline-first yazma yolu (Bölüm 8, müşteri deseniyle birebir aynı):
  /// local_only, pending, processing, retrying, synced, conflicted, rejected.
  /// Sunucudan gelen read-through kayıtlar `synced` ile yazılır.
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  IntColumn get serverVersion => integer().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Kullanıcıya güvenle gösterilebilecek son hata kodu.
  TextColumn get lastSyncError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
