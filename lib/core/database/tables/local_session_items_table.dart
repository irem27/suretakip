import 'package:drift/drift.dart';

/// Seans ürün kalemlerinin cihazdaki operasyonel kopyası. Offline eklenen
/// kalem outbox kabulüne kadar burada görünür; sunucu snapshot'ı geldiğinde
/// ilgili seansın kanonik kalemleriyle bütünüyle değiştirilir.
@DataClassName('LocalSessionItemRow')
class LocalSessionItems extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get sessionId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get productNameSnapshot => text()();
  TextColumn get skuSnapshot => text().nullable()();
  IntColumn get unitPriceMinorSnapshot => integer()();
  TextColumn get currencyCodeSnapshot => text()();
  IntColumn get quantity => integer()();
  IntColumn get discountMinor => integer()();
  IntColumn get taxMinor => integer()();
  IntColumn get lineTotalMinor => integer()();
  DateTimeColumn get createdAtServer => dateTime()();
  DateTimeColumn get updatedAtServer => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
