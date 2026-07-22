import 'package:drift/drift.dart';

/// Seansların cihazdaki operasyonel kopyası (Faz C). Süre, canlı sayaçtan
/// değil `local_session_time_entries` zaman damgalarından hesaplanır; bu yüzden
/// uygulama kapanıp açılsa da süre donmaz (Bölüm 13.2).
@DataClassName('LocalSessionRow')
class LocalSessions extends Table {
  TextColumn get id => text()();
  TextColumn get businessId => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get serviceId => text()();
  TextColumn get openedByMemberId => text()();
  TextColumn get closedByMemberId => text().nullable()();

  /// draft, active, paused, completed, cancelled.
  TextColumn get status => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  // Fiyat/hizmet snapshot'ı: seans başlarken dondurulur (offline'da da sabit).
  TextColumn get serviceNameSnapshot => text()();
  IntColumn get pricePerMinuteMinorSnapshot => integer()();
  IntColumn get roundingIntervalMinutesSnapshot => integer()();
  IntColumn get minimumChargeMinutesSnapshot => integer()();
  TextColumn get currencyCodeSnapshot => text()();

  TextColumn get notes => text().nullable()();

  /// local_only, pending, processing, retrying, synced, conflicted, rejected.
  TextColumn get syncStatus => text()();
  IntColumn get serverVersion => integer().nullable()();

  /// Seans offline mi başladı? Sunucu uzlaştırmasında ve saat sapması
  /// değerlendirmesinde kullanılır (Bölüm 21.5, risk: cihaz saati).
  BoolColumn get startedOffline =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAtLocal => dateTime()();
  DateTimeColumn get updatedAtLocal => dateTime()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
