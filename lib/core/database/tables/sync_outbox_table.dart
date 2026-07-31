import 'package:drift/drift.dart';

/// Sunucuya gönderilmeyi bekleyen değişmez mutation'lar. Domain kaydı ile bu
/// kayıt her zaman AYNI Drift transaction'ında oluşturulur (Bölüm 8.1).
@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  TextColumn get id => text()();

  /// Sunucuya gönderilen değişmez operasyon kimliği.
  TextColumn get operationId => text()();
  TextColumn get businessId => text()();

  /// İşlemi cihazda oluşturan değişmez kullanıcı.
  TextColumn get originalActorUserId => text()();

  /// Normalde null; gönderim anında doldurulur (Bölüm 6 alan sözleşmesi).
  TextColumn get submittedByUserId => text().nullable()();
  TextColumn get deviceId => text()();

  TextColumn get aggregateType => text()();
  TextColumn get aggregateId => text()();
  TextColumn get operationType => text()();

  /// Aynı aggregate içindeki yerel işlem sırası.
  IntColumn get sequenceNumber => integer()();
  TextColumn get dependsOnOperationId => text().nullable()();

  TextColumn get payloadJson => text()();
  IntColumn get payloadVersion => integer().withDefault(const Constant(1))();

  /// Sunucuda unique olan tekrar engelleme anahtarı.
  TextColumn get idempotencyKey => text()();
  IntColumn get expectedServerVersion => integer().nullable()();

  /// pending, processing, retrying, synced, conflicted, rejected.
  TextColumn get status => text()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// Aktif worker claim'inin fencing token'ı. Lease yenilenip başka worker
  /// sahiplendiğinde eski worker bu token olmadan sonucu yazamaz.
  TextColumn get processingToken => text().nullable()();
  TextColumn get lastErrorCode => text().nullable()();
  TextColumn get lastErrorMessage => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {operationId},
    {idempotencyKey},
    {aggregateType, aggregateId, sequenceNumber},
  ];
}
