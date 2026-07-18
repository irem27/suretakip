import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/features/businesses/domain/entities/business.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_history_filter.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';

void main() {
  test('liste controller aktif işletmenin seanslarını yükler', () async {
    final repository = _FakeSessionsRepository();
    final container = _container(repository);
    addTearDown(container.dispose);

    final sessions = await container.read(
      sessionsListControllerProvider.future,
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
}

ProviderContainer _container(_FakeSessionsRepository repository) =>
    ProviderContainer(
      overrides: [
        sessionsRepositoryProvider.overrideWithValue(repository),
        activeBusinessProvider.overrideWithValue(_business()),
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

class _FakeSessionsRepository implements SessionsRepository {
  String? loadedBusinessId;
  String? startedBusinessId;
  String? startedServiceId;
  String? startedCustomerId;
  String? startedNotes;
  String? pausedSessionId;

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
  Future<DateTime> serverNow() async => DateTime.utc(2026, 7, 17, 12);
}
