import 'package:drift/drift.dart';

/// Ürünlerin cihazdaki read-through önbelleği. İşleme ürün ekleme ve ürün
/// listesi internetsizde de çalışsın diye son senkronlanan ürünler burada
/// tutulur. Stok, sunucu-otoriteli kalır; bu tablo yalnız okuma önbelleğidir.
@DataClassName('LocalProductRow')
class LocalProducts extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  IntColumn get unitPriceMinor => integer()();
  TextColumn get currencyCode => text()();
  BoolColumn get trackStock => boolean().withDefault(const Constant(false))();
  IntColumn get stockQuantity => integer().withDefault(const Constant(0))();
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
