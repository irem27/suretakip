import 'package:drift/drift.dart';

/// Kullanıcı veya yönetici müdahalesi gereken çatışmalar (Bölüm 13). Sunucu
/// bir mutation'ı `conflict` ile reddettiğinde buraya kayıt düşülür; kayıt asla
/// sessizce silinmez, yerel değişiklik korunur.
@DataClassName('SyncConflictRow')
class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get aggregateType => text()();
  TextColumn get aggregateId => text()();
  TextColumn get operationId => text()();

  /// Sunucudan gelen makinece işlenebilir çatışma kodu (ör. VERSION_CONFLICT).
  TextColumn get conflictCode => text()();
  TextColumn get localPayload => text()();
  TextColumn get serverSnapshot => text().nullable()();
  TextColumn get recommendedAction => text().nullable()();

  /// open, awaitingManager, resolvedWithLocal, resolvedWithServer, merged,
  /// cancelled (Bölüm 25 ConflictStatus).
  TextColumn get status => text().withDefault(const Constant('open'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get resolvedBy => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
