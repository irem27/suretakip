import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/utils/monotonic_clock.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';

import '../../../../helpers/fake_monotonic_clock.dart';

void main() {
  test('liste controller aktif işletmenin seanslarını yükler', () async {
    final repository = _FakeSessionsRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final sessions = await container.read(
      sessionsListControllerProvider(_scope).future,
    );

    expect(sessions, hasLength(1));
    expect(repository.loadedBusinessId, 'business-1');
  });

  test('başlat controller RPC parametrelerini repositoryye iletir', () async {
    final repository = _FakeSessionsRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final id = await container
        .read(startSessionControllerProvider.notifier)
        .start(
          serviceId: 'service-2',
          customerId: 'customer-1',
          notes: 'Pencere yanı',
        );

    expect(id, 'session-new');
    expect(repository.startedBusinessId, 'business-1');
    expect(repository.startedServiceId, 'service-2');
    expect(repository.startedCustomerId, 'customer-1');
    expect(repository.startedNotes, 'Pencere yanı');
  });

  test('aksiyon controller duraklatma RPCsini çağırır', () async {
    final repository = _FakeSessionsRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final success = await container
        .read(sessionActionsControllerProvider.notifier)
        .pause('session-1');

    expect(success, isTrue);
    expect(repository.pausedSessionId, 'session-1');
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
    'pause, resume ve refetch yeni sunucu çapası ile monotonik saat kullanır',
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

      await container
          .read(sessionActionsControllerProvider.notifier)
          .pause('session-1');
      final second = await container.read(
        sessionDetailProvider('session-1').future,
      );

      expect(firstClock.isStopped, isTrue);
      expect(second.serverAnchor, DateTime.utc(2026, 7, 17, 14));
      expect(second.effectiveServerNow, DateTime.utc(2026, 7, 17, 14));
      secondClock.advance(const Duration(minutes: 15));

      await container
          .read(sessionActionsControllerProvider.notifier)
          .resume('session-1');
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
    sessionsRepositoryProvider.overrideWithValue(repository),
    activeBusinessProvider.overrideWithValue(_business()),
    if (clockFactory != null)
      monotonicClockFactoryProvider.overrideWithValue(clockFactory),
  ],
);

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

  @override
  Future<List<Session>> getSessions({
    required String businessId,
    String? customerId,
  }) async {
    loadedBusinessId = businessId;
    return [_session()];
  }

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
  Future<Session> getSession(String sessionId) async => _session();

  @override
  Future<List<Session>> getSessionHistory({
    required String businessId,
    required SessionHistoryFilter filter,
  }) async => const [];

  @override
  Future<List<SessionItem>> getSessionItems(String sessionId) async => const [];

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
