import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/domain/services/session_price_calculator.dart';

/// Drift satırını mevcut süre hesaplayıcısının anladığı domain modeline çevirir.
SessionTimeEntry _toDomain(LocalSessionTimeEntryRow row) => SessionTimeEntry(
  id: row.id,
  businessId: row.businessId,
  sessionId: row.sessionId,
  entryType: TimeEntryType.values.byName(row.entryType),
  startedAt: row.startedAt,
  endedAt: row.endedAt,
  createdAt: row.createdAtLocal,
);

void main() {
  late AppDatabase db;

  final t0 = DateTime.utc(2026, 3, 1, 9); // seans başlangıcı

  StartSessionLocally command() => StartSessionLocally(
    sessionId: 'sess-1',
    timeEntryId: 'entry-1',
    businessId: 'biz-1',
    serviceId: 'svc-1',
    openedByMemberId: 'member-1',
    serviceName: 'Koltuk',
    pricePerMinuteMinor: 250,
    roundingIntervalMinutes: 1,
    minimumChargeMinutes: 0,
    currencyCode: 'TRY',
    startedAt: t0,
    startedOffline: true,
  );

  setUp(() => db = AppDatabase.forExecutor(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('offline seans ve ilk aktif aralık kalıcı yazılır', () async {
    final source = SessionsLocalDataSource(db);
    final row = await source.startSession(command());

    expect(row.status, SessionStatus.active.name);
    expect(row.startedOffline, isTrue);
    final entries = await source.timeEntries('sess-1');
    expect(entries, hasLength(1));
    expect(entries.single.entryType, TimeEntryType.active.name);
    expect(entries.single.endedAt, isNull);
  });

  test('uygulama yeniden açılınca süre damgadan doğru devam eder', () async {
    // Seansı başlat (offline).
    await SessionsLocalDataSource(db).startSession(command());

    // "Uygulama kapandı ve yeniden açıldı": aynı kalıcı DB üzerinde YENİ bir
    // veri kaynağı. Süre bellekte tutulan bir sayaçtan değil, kayıtlı
    // damgalardan hesaplandığı için donmaz.
    final afterRestart = SessionsLocalDataSource(db);
    final session = await afterRestart.findSession('sess-1');
    expect(session, isNotNull, reason: 'seans restart sonrası kaybolmamalı');

    final entries = (await afterRestart.timeEntries('sess-1')).map(_toDomain);

    // 30 dakika sonra bakıldığında geçen süre ~30 dk (offline "şimdi" = cihaz
    // saati; kayıtlı başlangıç damgasından türetilir).
    final elapsed = calculateSessionActiveDuration(
      entries: entries,
      serverNow: t0.add(const Duration(minutes: 30)),
    );
    expect(elapsed, const Duration(minutes: 30));
  });

  test('offline duraklat/devam duraklatılan süreyi düşer', () async {
    final source = SessionsLocalDataSource(db);
    await source.startSession(command());

    // 30. dk duraklat, 35. dk devam et.
    await source.pauseSession(
      sessionId: 'sess-1',
      newEntryId: 'entry-2',
      now: t0.add(const Duration(minutes: 30)),
    );
    await source.resumeSession(
      sessionId: 'sess-1',
      newEntryId: 'entry-3',
      now: t0.add(const Duration(minutes: 35)),
    );

    final session = await source.findSession('sess-1');
    expect(session!.status, SessionStatus.active.name);

    final entries = (await source.timeEntries('sess-1')).map(_toDomain);
    // 40. dk: aktif = (0→30) + (35→40) = 35 dk; duraklatılan 5 dk hariç.
    final elapsed = calculateSessionActiveDuration(
      entries: entries,
      serverNow: t0.add(const Duration(minutes: 40)),
    );
    expect(elapsed, const Duration(minutes: 35));
  });

  test('yanlış durumda geçiş reddedilir (çift duraklatma yok)', () async {
    final source = SessionsLocalDataSource(db);
    await source.startSession(command());
    await source.pauseSession(
      sessionId: 'sess-1',
      newEntryId: 'entry-2',
      now: t0.add(const Duration(minutes: 10)),
    );

    // Zaten paused; ikinci pause reddedilmeli.
    expect(
      () => source.pauseSession(
        sessionId: 'sess-1',
        newEntryId: 'entry-x',
        now: t0.add(const Duration(minutes: 12)),
      ),
      throwsStateError,
    );
  });
}
