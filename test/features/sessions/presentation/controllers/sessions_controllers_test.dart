import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/logging/app_logger.dart';
import 'package:suretakip/core/sync/customer_sync_rpc.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/sync/models/sync_push_result.dart';
import 'package:suretakip/core/sync/session_sync_rpc.dart';
import 'package:suretakip/core/auth/sync_session_guard.dart';
import 'package:suretakip/core/utils/monotonic_clock.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/businesses/domain/entities/business_member.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';

import '../../../../helpers/fake_monotonic_clock.dart';

void main() {
  test(
    'liste controller uzak sunucuyu beklemeden Drift seanslarını açar',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await SessionsLocalDataSource(db).startSession(
        StartSessionLocally(
          sessionId: 'local-session',
          timeEntryId: 'local-entry',
          businessId: 'business-1',
          serviceId: 'service-1',
          openedByMemberId: 'member-1',
          serviceName: 'Yerel Bilardo',
          pricePerMinuteMinor: 200,
          roundingIntervalMinutes: 5,
          minimumChargeMinutes: 10,
          currencyCode: 'TRY',
          startedAt: DateTime.utc(2026, 7, 17),
          startedOffline: true,
        ),
      );
      final repository = _FakeSessionsRepository();
      final container = _offlineContainer(db, sessionsRepository: repository);
      addTearDown(container.dispose);

      final sessions = await container.read(
        sessionsListControllerProvider(_scope).future,
      );

      expect(sessions, hasLength(1));
      expect(sessions.single.id, 'local-session');
      expect(repository.loadedBusinessId, isNull);
    },
  );

  test('başlat controller seansı offline yerel olarak oluşturur', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final container = _offlineContainer(db);
    addTearDown(container.dispose);

    final id = await container
        .read(startSessionControllerProvider.notifier)
        .start(
          service: _service(),
          customerId: 'customer-1',
          notes: 'Pencere yanı',
        );

    expect(id, isNotNull);
    final rows = await db.select(db.localSessions).get();
    expect(rows, hasLength(1));
    expect(rows.single.serviceId, 'service-2');
    expect(rows.single.customerId, 'customer-1');
    expect(rows.single.status, SessionStatus.active.name);
    expect(rows.single.startedOffline, isTrue);
    // Outbox'ta start operasyonu birikti.
    final ops = await db.select(db.syncOutbox).get();
    expect(ops.single.operationType, SyncOperationType.startSession.wireName);
  });

  test('aksiyon controller offline duraklatma uygular', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final container = _offlineContainer(db);
    addTearDown(container.dispose);

    final id = await container
        .read(startSessionControllerProvider.notifier)
        .start(service: _service());
    final success = await container
        .read(sessionActionsControllerProvider.notifier)
        .pause(id!);

    expect(success, isTrue);
    final row = (await db.select(db.localSessions).get()).single;
    expect(row.status, SessionStatus.paused.name);
  });

  test('offline başlatılan seansın detayı yerel veriden açılır', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final container = _offlineContainer(db);
    addTearDown(container.dispose);

    final id = await container
        .read(startSessionControllerProvider.notifier)
        .start(service: _service(), notes: 'Yerel not');
    await container
        .read(sessionsLocalDataSourceProvider)
        .reconcileServerItems(sessionId: id!, items: [_sessionItem(id)]);
    final detail = await container.read(sessionDetailProvider(id).future);

    expect(detail.session.id, id);
    expect(detail.session.notes, 'Yerel not');
    expect(detail.timeEntries, hasLength(1));
    expect(detail.items.single.lineTotalMinor, 600);
    expect(detail.session.status, SessionStatus.active);
  });

  test(
    'synced aktif işlem detayı sunucuyu beklemeden yerelden açılır',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await SessionsLocalDataSource(db).startSession(
        StartSessionLocally(
          sessionId: 'session-1',
          timeEntryId: 'local-entry',
          businessId: 'business-1',
          serviceId: 'service-1',
          openedByMemberId: 'member-1',
          serviceName: 'Yerel Bilardo',
          pricePerMinuteMinor: 200,
          roundingIntervalMinutes: 5,
          minimumChargeMinutes: 10,
          currencyCode: 'TRY',
          startedAt: DateTime.utc(2026, 7, 17),
          startedOffline: false,
        ),
      );
      await (db.update(db.localSessions)
            ..where((row) => row.id.equals('session-1')))
          .write(const LocalSessionsCompanion(syncStatus: Value('synced')));
      final repository = _FakeSessionsRepository();
      final container = _offlineContainer(db, sessionsRepository: repository);
      addTearDown(container.dispose);

      final detail = await container.read(
        sessionDetailProvider('session-1').future,
      );

      expect(detail.session.serviceNameSnapshot, 'Yerel Bilardo');
      expect(repository.getSessionCallCount, 0);
    },
  );

  test('ürün ekleme internetsiz yerel kalem ve outbox oluşturur', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final container = _offlineContainer(db);
    addTearDown(container.dispose);
    final sessionId = await container
        .read(startSessionControllerProvider.notifier)
        .start(service: _service());

    final success = await container
        .read(sessionActionsControllerProvider.notifier)
        .addProduct(sessionId: sessionId!, product: _product(), quantity: 2);

    expect(success, isTrue);
    expect((await db.select(db.localSessionItems).get()), hasLength(1));
    final ops = await db.select(db.syncOutbox).get()
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
    expect(
      ops.last.operationType,
      SyncOperationType.addSessionProduct.wireName,
    );
  });

  test(
    'uzak detay yerel ürün cache yazımı bozulsa da kullanıcıya açılır',
    () async {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final logger = _RecordingLogger();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          sessionsLocalDataSourceProvider.overrideWithValue(
            _FailingItemsCache(db),
          ),
          sessionsRepositoryProvider.overrideWithValue(
            _FakeSessionsRepository()
              ..sessionItems = [_sessionItem('session-1')],
          ),
          activeBusinessProvider.overrideWithValue(_business()),
          appLoggerProvider.overrideWithValue(logger),
        ],
      );
      addTearDown(container.dispose);

      final detail = await container.read(
        sessionDetailProvider('session-1').future,
      );

      expect(detail.items, hasLength(1));
      expect(logger.warningContexts, ['SessionDetailItemsCache']);
    },
  );

  test('uzak tamamlama yerel açık seansı da kapatır', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = _FakeSessionsRepository();
    final container = _offlineContainer(db, sessionsRepository: repository);
    addTearDown(container.dispose);

    final id = await container
        .read(startSessionControllerProvider.notifier)
        .start(service: _service());
    final success = await container
        .read(sessionActionsControllerProvider.notifier)
        .complete(sessionId: id!);

    expect(success, isTrue);
    expect(
      (await db.select(db.localSessions).get()).single.status,
      SessionStatus.completed.name,
    );
  });

  test('cihaz duvar saati ileri veya geri alınsa da canlı süre değişmez', () {
    final clock = FakeMonotonicClock();
    final state = _detailState(clock: clock);
    final initialDuration = state.quote.activeDuration;
    var deviceWallClock = DateTime.utc(2026, 7, 17, 12, 10);

    deviceWallClock = deviceWallClock.add(const Duration(days: 2));
    expect(deviceWallClock, DateTime.utc(2026, 7, 19, 12, 10));
    expect(clock.elapsed, Duration.zero);
    expect(state.quote.activeDuration, initialDuration);

    deviceWallClock = deviceWallClock.subtract(const Duration(days: 5));
    expect(deviceWallClock, DateTime.utc(2026, 7, 14, 12, 10));
    expect(clock.elapsed, Duration.zero);
    expect(state.quote.activeDuration, initialDuration);
  });

  test('monotonik süre arttıkça canlı sayaç doğru ilerler', () {
    final clock = FakeMonotonicClock();
    final state = _detailState(clock: clock);

    expect(state.effectiveServerNow, DateTime.utc(2026, 7, 17, 12, 10));
    expect(state.quote.activeDuration, const Duration(minutes: 10));

    clock.advance(const Duration(minutes: 2, seconds: 37));

    expect(state.effectiveServerNow, DateTime.utc(2026, 7, 17, 12, 12, 37));
    expect(
      state.quote.activeDuration,
      const Duration(minutes: 12, seconds: 37),
    );
  });

  test(
    'duraklatılmış seansta monotonik saat ilerlese de aktif süre artmaz',
    () {
      final clock = FakeMonotonicClock();
      final state = _detailState(
        clock: clock,
        status: SessionStatus.paused,
        activeEndedAt: DateTime.utc(2026, 7, 17, 12, 5),
      );

      expect(state.quote.activeDuration, const Duration(minutes: 5));

      clock.advance(const Duration(hours: 3));

      expect(state.quote.activeDuration, const Duration(minutes: 5));
    },
  );

  test(
    'sessionDetail refetch yeni sunucu çapası ile monotonik saat kullanır',
    () async {
      final repository = _FakeSessionsRepository()
        ..serverTimes = [
          DateTime.utc(2026, 7, 17, 12),
          DateTime.utc(2026, 7, 17, 14),
          DateTime.utc(2026, 7, 17, 16),
        ];
      final firstClock = FakeMonotonicClock();
      final secondClock = FakeMonotonicClock();
      final thirdClock = FakeMonotonicClock();
      final clocks = [firstClock, secondClock, thirdClock];
      final container = _container(
        repository,
        clockFactory: () => clocks.removeAt(0),
      );
      final subscription = container.listen(
        sessionDetailProvider('session-1'),
        (_, _) {},
      );

      final first = await container.read(
        sessionDetailProvider('session-1').future,
      );
      expect(first.effectiveServerNow, DateTime.utc(2026, 7, 17, 12));
      firstClock.advance(const Duration(minutes: 20));
      expect(first.effectiveServerNow, DateTime.utc(2026, 7, 17, 12, 20));

      container.invalidate(sessionDetailProvider('session-1'));
      final second = await container.read(
        sessionDetailProvider('session-1').future,
      );

      expect(firstClock.isStopped, isTrue);
      expect(second.serverAnchor, DateTime.utc(2026, 7, 17, 14));
      expect(second.effectiveServerNow, DateTime.utc(2026, 7, 17, 14));
      secondClock.advance(const Duration(minutes: 15));

      container.invalidate(sessionDetailProvider('session-1'));
      final third = await container.read(
        sessionDetailProvider('session-1').future,
      );

      expect(secondClock.isStopped, isTrue);
      expect(third.serverAnchor, DateTime.utc(2026, 7, 17, 16));
      expect(third.effectiveServerNow, DateTime.utc(2026, 7, 17, 16));
      expect(repository.serverNowCallCount, 3);

      subscription.close();
      container.dispose();
      expect(thirdClock.isStopped, isTrue);
    },
  );
}

const BusinessScope _scope = (businessId: 'business-1', generation: 0);

ProviderContainer _container(
  _FakeSessionsRepository repository, {
  MonotonicClock Function()? clockFactory,
}) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWith((ref) {
      final db = AppDatabase.forExecutor(NativeDatabase.memory());
      ref.onDispose(db.close);
      return db;
    }),
    sessionsRepositoryProvider.overrideWithValue(repository),
    activeBusinessProvider.overrideWithValue(_business()),
    if (clockFactory != null)
      monotonicClockFactoryProvider.overrideWithValue(clockFactory),
  ],
);

ProviderContainer _offlineContainer(
  AppDatabase db, {
  SessionsRepository? sessionsRepository,
}) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWithValue(db),
    if (sessionsRepository != null)
      sessionsRepositoryProvider.overrideWithValue(sessionsRepository),
    activeBusinessProvider.overrideWithValue(_business()),
    activeBusinessScopeProvider.overrideWithValue(_scope),
    currentMemberProvider(_scope).overrideWith((ref) async => _member()),
    customerSyncApiProvider.overrideWithValue(_NoopCustomerApi()),
    sessionSyncApiProvider.overrideWithValue(_NoopSessionApi()),
    syncSessionGuardProvider.overrideWithValue(_NoopGuard()),
  ],
);

Service _service() => Service(
  id: 'service-2',
  businessId: 'business-1',
  name: 'Bilardo',
  pricePerMinuteMinor: 200,
  roundingIntervalMinutes: 5,
  minimumChargeMinutes: 10,
  currencyCode: 'TRY',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Product _product() => Product(
  id: 'product-1',
  businessId: 'business-1',
  name: 'Maden Suyu',
  sku: 'MS-01',
  unitPriceMinor: 300,
  currencyCode: 'TRY',
  trackStock: true,
  stockQuantity: 10,
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

BusinessMember _member() => BusinessMember(
  id: 'member-1',
  businessId: 'business-1',
  userId: 'user-1',
  role: MemberRole.owner,
  isActive: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _NoopGuard implements SyncSessionGuard {
  @override
  Future<SyncResultType?> ensureValidSession() async =>
      SyncResultType.authRequired; // push denemesi kaydı bozmadan durur
}

final class _FailingItemsCache extends SessionsLocalDataSource {
  const _FailingItemsCache(super.db);

  @override
  Future<void> reconcileServerItems({
    required String sessionId,
    required List<SessionItem> items,
  }) async {
    throw StateError('cache write failed');
  }
}

final class _RecordingLogger implements AppLogger {
  final warningContexts = <String?>[];

  @override
  void error(Object error, {StackTrace? stackTrace, String? context}) {}

  @override
  void info(Object message, {String? context}) {}

  @override
  void warn(Object warning, {StackTrace? stackTrace, String? context}) {
    warningContexts.add(context);
  }
}

class _NoopSessionApi implements SessionSyncApi {
  @override
  Future<SyncPushResult> startSession({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> session,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> sessionEvent({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> event,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);
}

class _NoopCustomerApi implements CustomerSyncApi {
  @override
  Future<SyncPushResult> createCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> updateCustomer({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required Map<String, Object?> customer,
    required int expectedVersion,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);

  @override
  Future<SyncPushResult> setCustomerActive({
    required String operationId,
    required String idempotencyKey,
    required String businessId,
    required String customerId,
    required bool isActive,
    required int expectedVersion,
    required int payloadVersion,
  }) async => const SyncPushResult(type: SyncResultType.applied);
}

Business _business() => Business(
  id: 'business-1',
  name: 'Test İşletmesi',
  currencyCode: 'TRY',
  timezone: 'Europe/Istanbul',
  isActive: true,
  archivedAt: null,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Session _session() => Session(
  id: 'session-1',
  businessId: 'business-1',
  customerId: null,
  serviceId: 'service-1',
  openedByMemberId: 'member-1',
  closedByMemberId: null,
  status: SessionStatus.active,
  startedAt: DateTime.utc(2026, 7, 17),
  endedAt: null,
  chargedMinutes: null,
  serviceNameSnapshot: 'Bilardo',
  pricePerMinuteMinorSnapshot: 200,
  roundingIntervalMinutesSnapshot: 5,
  minimumChargeMinutesSnapshot: 10,
  currencyCodeSnapshot: 'TRY',
  serviceSubtotalMinor: null,
  productsSubtotalMinor: null,
  discountMinor: 0,
  taxMinor: 0,
  grandTotalMinor: null,
  notes: null,
  createdAt: DateTime.utc(2026, 7, 17),
  updatedAt: DateTime.utc(2026, 7, 17),
);

SessionItem _sessionItem(String sessionId) => SessionItem(
  id: 'item-1',
  businessId: 'business-1',
  sessionId: sessionId,
  productId: 'product-1',
  productNameSnapshot: 'Su',
  skuSnapshot: null,
  unitPriceMinorSnapshot: 300,
  currencyCodeSnapshot: 'TRY',
  quantity: 2,
  discountMinor: 0,
  taxMinor: 0,
  lineTotalMinor: 600,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

SessionDetailState _detailState({
  required FakeMonotonicClock clock,
  SessionStatus status = SessionStatus.active,
  DateTime? activeEndedAt,
}) => SessionDetailState(
  session: _session().copyWith(status: status),
  customerName: null,
  items: const [],
  timeEntries: [
    SessionTimeEntry(
      id: 'entry-1',
      businessId: 'business-1',
      sessionId: 'session-1',
      entryType: TimeEntryType.active,
      startedAt: DateTime.utc(2026, 7, 17, 12),
      endedAt: activeEndedAt,
      createdAt: DateTime.utc(2026, 7, 17, 12),
    ),
  ],
  serverAnchor: DateTime.utc(2026, 7, 17, 12, 10),
  clock: clock,
  clockAnchor: clock.elapsed,
);

class _FakeSessionsRepository implements SessionsRepository {
  String? loadedBusinessId;
  String? startedBusinessId;
  String? startedServiceId;
  String? startedCustomerId;
  String? startedNotes;
  String? pausedSessionId;
  List<DateTime> serverTimes = [DateTime.utc(2026, 7, 17, 12)];
  int serverNowCallCount = 0;
  List<SessionItem> sessionItems = const [];
  int getSessionCallCount = 0;

  @override
  Future<List<Session>> getSessions({
    required String businessId,
    String? customerId,
  }) async {
    loadedBusinessId = businessId;
    return [_session()];
  }

  @override
  Future<List<Session>> getOpenSessions({required String businessId}) async => [
    _session(),
  ];

  @override
  Future<List<Session>> getSessionsByIds({
    required String businessId,
    required List<String> sessionIds,
  }) async => sessionIds.contains('session-1') ? [_session()] : const [];

  @override
  Future<String> startSession({
    required String businessId,
    required String serviceId,
    String? customerId,
    String? notes,
  }) async {
    startedBusinessId = businessId;
    startedServiceId = serviceId;
    startedCustomerId = customerId;
    startedNotes = notes;
    return 'session-new';
  }

  @override
  Future<String> pauseSession({required String sessionId}) async {
    pausedSessionId = sessionId;
    return sessionId;
  }

  @override
  Future<String> resumeSession({required String sessionId}) async => sessionId;

  @override
  Future<String> addProductToSession({
    required String sessionId,
    required String productId,
    required int quantity,
    int discountMinor = 0,
    int taxMinor = 0,
  }) async => 'item-1';

  @override
  Future<String> completeSession({
    required String sessionId,
    int discountMinor = 0,
    int taxMinor = 0,
  }) async => sessionId;

  @override
  Future<String> cancelSession({required String sessionId}) async => sessionId;

  @override
  Future<Session> getSession(String sessionId) async {
    getSessionCallCount++;
    return _session();
  }

  @override
  Future<List<Session>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) async => const [];

  @override
  Future<List<SessionItem>> getSessionItems(String sessionId) async =>
      sessionItems;

  @override
  Future<List<SessionTimeEntry>> getSessionTimeEntries(
    String sessionId,
  ) async => const [];

  @override
  Future<Map<String, List<SessionTimeEntry>>> getTimeEntriesForSessions(
    List<String> sessionIds,
  ) async => const {};

  @override
  Future<Map<String, List<SessionItem>>> getItemsForSessions(
    List<String> sessionIds,
  ) async => const {};

  @override
  Future<DateTime> serverNow() async => serverTimes[serverNowCallCount++];
}
