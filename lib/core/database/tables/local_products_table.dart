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

  @override
  Set<Column<Object>> get primaryKey => {id};
}
