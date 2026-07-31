import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
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

  test('uzak tamamlama sonrası yerel açık seans kapanır', () async {
    final source = SessionsLocalDataSource(db);
    await source.startSession(command());
    final endedAt = t0.add(const Duration(minutes: 40));

    await source.reconcileTerminalState(
      sessionId: 'sess-1',
      status: SessionStatus.completed,
      endedAt: endedAt,
    );

    final session = await source.findSession('sess-1');
    expect(session!.status, SessionStatus.completed.name);
    expect(session.endedAt!.toUtc(), endedAt);
    expect(
      (await source.timeEntries('sess-1')).single.endedAt!.toUtc(),
      endedAt,
    );
    expect(await source.watchActiveSessions('biz-1').first, isEmpty);
  });

  test('uzak iptal sonrası yerel açık seans kapanır', () async {
    final source = SessionsLocalDataSource(db);
    await source.startSession(command());
    final endedAt = t0.add(const Duration(minutes: 5));

    await source.reconcileTerminalState(
      sessionId: 'sess-1',
      status: SessionStatus.cancelled,
      endedAt: endedAt,
    );

    expect(
      (await source.findSession('sess-1'))!.status,
      SessionStatus.cancelled.name,
    );
    expect(await source.watchActiveSessions('biz-1').first, isEmpty);
  });

  test(
    'sunucu snapshotı diğer cihazdaki açık seansı yerelde oluşturur',
    () async {
      final source = SessionsLocalDataSource(db);
      final session = _serverSession();
      final entry = SessionTimeEntry(
        id: 'server-entry-1',
        businessId: 'biz-1',
        sessionId: session.id,
        entryType: TimeEntryType.active,
        startedAt: t0,
        endedAt: null,
        createdAt: t0,
      );

      await source.reconcileServerSessions(
        sessions: [session],
        timeEntriesBySession: {
          session.id: [entry],
        },
      );

      final localSession = await source.findSession(session.id);
      expect(localSession, isNotNull);
      expect(localSession!.syncStatus, 'synced');
      expect(await source.timeEntries(session.id), hasLength(1));
      expect(await source.watchActiveSessions('biz-1').first, hasLength(1));
    },
  );

  test('sunucu snapshotı bekleyen yerel seansı ezmez', () async {
    final source = SessionsLocalDataSource(db);
    await source.startSession(command());

    await source.reconcileServerSessions(
      sessions: [_serverSession(id: 'sess-1', serviceName: 'Sunucu adı')],
      timeEntriesBySession: const {},
    );

    expect((await source.findSession('sess-1'))!.serviceNameSnapshot, 'Koltuk');
  });

  test(
    'sunucu terminal snapshotı yerel açık zaman aralığını kapatır',
    () async {
      final source = SessionsLocalDataSource(db);
      final active = _serverSession();
      final entry = SessionTimeEntry(
        id: 'server-entry-1',
        businessId: 'biz-1',
        sessionId: active.id,
        entryType: TimeEntryType.active,
        startedAt: t0,
        endedAt: null,
        createdAt: t0,
      );
      await source.reconcileServerSessions(
        sessions: [active],
        timeEntriesBySession: {
          active.id: [entry],
        },
      );

      final endedAt = t0.add(const Duration(minutes: 45));
      await source.reconcileServerSessions(
        sessions: [
          _serverSession(status: SessionStatus.completed, endedAt: endedAt),
        ],
        timeEntriesBySession: const {},
      );

      expect(
        (await source.timeEntries(active.id)).single.endedAt!.toUtc(),
        endedAt,
      );
    },
  );

  test(
    'sunucu ürün kalemleri yerelde saklanır ve eski snapshotı değiştirir',
    () async {
      final source = SessionsLocalDataSource(db);
      final session = _serverSession();
      await source.reconcileServerSessions(
        sessions: [session],
        timeEntriesBySession: const {},
      );

      await source.reconcileServerItems(
        sessionId: session.id,
        items: [_serverItem(id: 'item-old', total: 600)],
      );
      expect(
        (await source.itemsForSessions([session.id]))[session.id],
        hasLength(1),
      );

      await source.reconcileServerItems(
        sessionId: session.id,
        items: [_serverItem(id: 'item-new', total: 900)],
      );
      final cached = (await source.itemsForSessions([session.id]))[session.id]!;
      expect(cached, hasLength(1));
      expect(cached.single.id, 'item-new');
      expect(cached.single.lineTotalMinor, 900);
    },
  );

  test('ürün kalemi cache değişikliği izleyen ekrana yayınlanır', () async {
    final source = SessionsLocalDataSource(db);
    final emissions = source
        .watchItemsForSessions(const ['server-session-1'])
        .take(2)
        .toList();
    await Future<void>.delayed(Duration.zero);

    await source.reconcileServerItems(
      sessionId: 'server-session-1',
      items: [_serverItem(id: 'item-live', total: 600)],
    );

    final values = await emissions;
    expect(values.first, isEmpty);
    expect(values.last['server-session-1']!.single.id, 'item-live');
  });
}

Session _serverSession({
  String id = 'server-session-1',
  String serviceName = 'Sunucu hizmeti',
  SessionStatus status = SessionStatus.active,
  DateTime? endedAt,
}) => Session(
  id: id,
  businessId: 'biz-1',
  customerId: null,
  serviceId: 'svc-1',
  openedByMemberId: 'member-1',
  closedByMemberId: null,
  status: status,
  startedAt: DateTime.utc(2026, 3, 1, 9),
  endedAt: endedAt,
  chargedMinutes: null,
  serviceNameSnapshot: serviceName,
  pricePerMinuteMinorSnapshot: 250,
  roundingIntervalMinutesSnapshot: 1,
  minimumChargeMinutesSnapshot: 0,
  currencyCodeSnapshot: 'TRY',
  serviceSubtotalMinor: null,
  productsSubtotalMinor: null,
  discountMinor: 0,
  taxMinor: 0,
  grandTotalMinor: null,
  notes: null,
  createdAt: DateTime.utc(2026, 3, 1, 9),
  updatedAt: DateTime.utc(2026, 3, 1, 9),
);

SessionItem _serverItem({required String id, required int total}) =>
    SessionItem(
      id: id,
      businessId: 'biz-1',
      sessionId: 'server-session-1',
      productId: 'product-1',
      productNameSnapshot: 'Su',
      skuSnapshot: 'SU-1',
      unitPriceMinorSnapshot: 300,
      currencyCodeSnapshot: 'TRY',
      quantity: total ~/ 300,
      discountMinor: 0,
      taxMinor: 0,
      lineTotalMinor: total,
      createdAt: DateTime.utc(2026, 3, 1, 9),
      updatedAt: DateTime.utc(2026, 3, 1, 9),
    );
