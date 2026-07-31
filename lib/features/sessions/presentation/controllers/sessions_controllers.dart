import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/database/app_database.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/sync/models/sync_enums.dart';
import 'package:suretakip/core/utils/monotonic_clock.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/sessions/data/local/local_session_mappers.dart';
import 'package:suretakip/features/sessions/data/local/sessions_local_data_source.dart';
import 'package:suretakip/features/sessions/data/repositories/offline_sessions_repository.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/domain/repositories/sessions_repository.dart';
import 'package:suretakip/features/sessions/domain/services/session_price_calculator.dart';
import 'package:suretakip/features/services/domain/entities/service.dart';
import 'package:suretakip/features/products/domain/entities/product.dart';
import 'package:suretakip/features/products/presentation/controllers/products_controllers.dart';
import 'package:suretakip/features/history/presentation/controllers/history_controller.dart';
import 'package:suretakip/features/reports/presentation/controllers/reports_controller.dart';
import 'package:suretakip/features/dashboard/presentation/controllers/dashboard_controller.dart';

final class SessionDetailState {
  const SessionDetailState({
    required this.session,
    required this.customerName,
    required this.items,
    required this.timeEntries,
    required this.serverAnchor,
    required MonotonicClock clock,
    required Duration clockAnchor,
  }) : _clock = clock,
       _clockAnchor = clockAnchor;

  final Session session;
  final String? customerName;
  final List<SessionItem> items;
  final List<SessionTimeEntry> timeEntries;

  /// Fetch anındaki sunucu zamanı (çapa). Açık aktif aralığın süresi buradan
  /// türetilir; cihaz saati kaymış olsa bile canlı sayaç doğru kalır.
  final DateTime serverAnchor;

  final MonotonicClock _clock;
  final Duration _clockAnchor;

  /// Cihaz duvar saatinden bağımsız "şu anki sunucu zamanı".
  DateTime get effectiveServerNow {
    final elapsedSinceAnchor = _clock.elapsed - _clockAnchor;
    return serverAnchor.add(
      elapsedSinceAnchor.isNegative ? Duration.zero : elapsedSinceAnchor,
    );
  }

  /// Açık (aktif/duraklatılmış) seansların CANLI önizlemesi. Kalıcı/final
  /// hesap daima server-side complete_session RPC'sindedir; tamamlanmış
  /// seanslar bu önizlemeyi değil DB'deki kesin tutarları gösterir.
  SessionPriceQuote get quote {
    final activeDuration = calculateSessionActiveDuration(
      entries: timeEntries,
      serverNow: effectiveServerNow,
    );
    return const SessionPriceCalculator().calculate(
      activeDuration: activeDuration,
      pricePerMinute: Money(
        minorUnits: session.pricePerMinuteMinorSnapshot,
        currencyCode: session.currencyCodeSnapshot,
      ),
      roundingIntervalMinutes: session.roundingIntervalMinutesSnapshot,
      minimumChargeMinutes: session.minimumChargeMinutesSnapshot,
      items: items,
      discount: Money(
        minorUnits: session.discountMinor,
        currencyCode: session.currencyCodeSnapshot,
      ),
      tax: Money(
        minorUnits: session.taxMinor,
        currencyCode: session.currencyCodeSnapshot,
      ),
    );
  }
}

class SessionsListController
    extends AutoDisposeFamilyAsyncNotifier<List<Session>, BusinessScope> {
  @override
  Future<List<Session>> build(BusinessScope scope) async {
    final businessId = scope.businessId;
    if (businessId == null) return const [];
    return ref.watch(localSessionsStreamProvider(businessId).future);
  }

  Future<void> refresh() async {
    final businessId = arg.businessId;
    if (businessId == null) return;
    try {
      await ref.read(sessionSnapshotSyncServiceProvider).sync(businessId);
    } catch (error, stack) {
      // Yerel liste kullanılmaya devam eder; yenileme ağ yüzünden ekranı
      // hata durumuna düşürmez.
      ref
          .read(appLoggerProvider)
          .warn(
            error,
            stackTrace: stack,
            context: 'SessionsListBackgroundRefresh',
          );
    }
  }
}

final localSessionsStreamProvider = StreamProvider.autoDispose
    .family<List<Session>, String>((ref, businessId) {
      return ref
          .watch(sessionsLocalDataSourceProvider)
          .watchSessions(businessId)
          .map(
            (rows) => rows.map(mapLocalSessionToDomain).toList(growable: false),
          );
    });

class StartSessionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Seansı offline-first başlatır: yerel yazım + outbox, sonra push denemesi.
  /// İnternet yoksa seans yerelde kalır ve süre işlemeye devam eder.
  Future<String?> start({
    required Service service,
    String? customerId,
    String? notes,
  }) async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return null;
    final scope = ref.read(activeBusinessScopeProvider);
    final member = await ref.read(currentMemberProvider(scope).future);
    if (member == null) return null;
    final userId = member.userId;

    String? sessionId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final row = await ref
          .read(offlineSessionsRepositoryProvider)
          .startSession(
            StartSessionInput(
              businessId: business.id,
              serviceId: service.id,
              openedByMemberId: member.id,
              serviceName: service.name,
              pricePerMinuteMinor: service.pricePerMinuteMinor,
              roundingIntervalMinutes: service.roundingIntervalMinutes,
              minimumChargeMinutes: service.minimumChargeMinutes,
              currencyCode: service.currencyCode,
              customerId: customerId,
              notes: notes,
            ),
            actorUserId: userId,
          );
      sessionId = row.id;
      // Açık seans akışı Drift stream'i olduğundan liste kendini günceller.
      ref.invalidate(dashboardControllerProvider(scope));
    });
    return state.hasError ? null : sessionId;
  }
}

class SessionActionsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> pause(String sessionId) => _runSession(
    sessionId,
    (repo, businessId, userId) => repo.pauseSession(
      sessionId: sessionId,
      businessId: businessId,
      actorUserId: userId,
    ),
  );

  Future<bool> resume(String sessionId) => _runSession(
    sessionId,
    (repo, businessId, userId) => repo.resumeSession(
      sessionId: sessionId,
      businessId: businessId,
      actorUserId: userId,
    ),
  );

  /// Offline seans event'lerini (pause/resume) çalıştırır. Yerel durum Drift
  /// stream'i olduğundan ekran kendini günceller.
  Future<bool> _runSession(
    String sessionId,
    Future<void> Function(
      OfflineSessionsRepository repo,
      String businessId,
      String userId,
    )
    operation,
  ) async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return false;
    final scope = ref.read(activeBusinessScopeProvider);
    final member = await ref.read(currentMemberProvider(scope).future);
    if (member == null) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await operation(
        ref.read(offlineSessionsRepositoryProvider),
        business.id,
        member.userId,
      );
      ref.invalidate(sessionDetailProvider(sessionId));
    });
    return !state.hasError;
  }

  Future<bool> addProduct({
    required String sessionId,
    required Product product,
    required int quantity,
    int discountMinor = 0,
    int taxMinor = 0,
  }) async {
    final success = await _runSession(
      sessionId,
      (repo, businessId, userId) => repo.addProduct(
        sessionId: sessionId,
        businessId: businessId,
        actorUserId: userId,
        product: product,
        quantity: quantity,
        discountMinor: discountMinor,
        taxMinor: taxMinor,
      ),
    );
    if (success) {
      ref.invalidate(
        productsListControllerProvider(ref.read(activeBusinessScopeProvider)),
      );
    }
    return success;
  }

  Future<bool> complete({
    required String sessionId,
    int discountMinor = 0,
    int taxMinor = 0,
  }) async {
    final success = await _runTerminal(
      sessionId,
      (repo, businessId, userId) => repo.completeSession(
        sessionId: sessionId,
        businessId: businessId,
        actorUserId: userId,
        discountMinor: discountMinor,
        taxMinor: taxMinor,
      ),
    );
    // Seans tamamlanınca geçmiş ve raporlar değişir.
    if (success) {
      final scope = ref.read(activeBusinessScopeProvider);
      ref.invalidate(dashboardControllerProvider(scope));
      ref.invalidate(historyControllerProvider(scope));
      ref.invalidate(reportsControllerProvider(scope));
    }
    return success;
  }

  Future<bool> cancel(String sessionId) async {
    final success = await _runTerminal(
      sessionId,
      (repo, businessId, userId) => repo.cancelSession(
        sessionId: sessionId,
        businessId: businessId,
        actorUserId: userId,
      ),
    );
    // İptalde stok iade edilir; seans geçmişe/raporlara yansır.
    if (success) {
      final scope = ref.read(activeBusinessScopeProvider);
      ref.invalidate(dashboardControllerProvider(scope));
      ref.invalidate(productsListControllerProvider(scope));
      ref.invalidate(historyControllerProvider(scope));
      ref.invalidate(reportsControllerProvider(scope));
    }
    return success;
  }

  Future<bool> _runTerminal(
    String sessionId,
    Future<void> Function(
      OfflineSessionsRepository repo,
      String businessId,
      String userId,
    )
    operation,
  ) async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return false;
    final scope = ref.read(activeBusinessScopeProvider);
    final member = await ref.read(currentMemberProvider(scope).future);
    if (member == null) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await operation(
        ref.read(offlineSessionsRepositoryProvider),
        business.id,
        member.userId,
      );
      ref.invalidate(sessionDetailProvider(sessionId));
      ref.invalidate(sessionsListControllerProvider(scope));
    });
    return !state.hasError;
  }
}

final sessionsListControllerProvider = AsyncNotifierProvider.autoDispose
    .family<SessionsListController, List<Session>, BusinessScope>(
      SessionsListController.new,
    );

final startSessionControllerProvider =
    AsyncNotifierProvider<StartSessionController, void>(
      StartSessionController.new,
    );

final sessionActionsControllerProvider =
    AsyncNotifierProvider<SessionActionsController, void>(
      SessionActionsController.new,
    );

final monotonicClockFactoryProvider = Provider<MonotonicClock Function()>(
  (ref) => StopwatchMonotonicClock.new,
);

final sessionDetailProvider = FutureProvider.autoDispose
    .family<SessionDetailState, String>((ref, sessionId) async {
      final clock = ref.watch(monotonicClockFactoryProvider)();
      ref.onDispose(clock.stop);
      final local = ref.watch(sessionsLocalDataSourceProvider);
      final localSession = await local.findSession(sessionId);
      final isLocalOpen =
          localSession?.status == SessionStatus.active.name ||
          localSession?.status == SessionStatus.paused.name;
      if (localSession != null &&
          (isLocalOpen ||
              localSession.syncStatus != SyncStatus.synced.wireName)) {
        return _localSessionDetail(
          ref,
          localSession,
          clock: clock,
          local: local,
        );
      }

      final repository = ref.watch(sessionsRepositoryProvider);
      try {
        return await _remoteSessionDetail(
          ref,
          sessionId,
          repository: repository,
          clock: clock,
          local: local,
        );
      } catch (error, stack) {
        if (localSession == null) rethrow;
        ref
            .read(appLoggerProvider)
            .warn(
              error,
              stackTrace: stack,
              context: 'SessionDetailLocalFallback',
            );
        return _localSessionDetail(
          ref,
          localSession,
          clock: clock,
          local: local,
        );
      }
    });

Future<SessionDetailState> _remoteSessionDetail(
  Ref ref,
  String sessionId, {
  required SessionsRepository repository,
  required MonotonicClock clock,
  required SessionsLocalDataSource local,
}) async {
  final session = await repository.getSession(sessionId);
  final customerFuture = session.customerId == null
      ? Future<String?>.value(null)
      : ref
            .watch(customersRepositoryProvider)
            .getCustomer(session.customerId!)
            .then<String?>((customer) => customer.name);
  final (items, entries, customerName) = await (
    repository.getSessionItems(sessionId),
    repository.getSessionTimeEntries(sessionId),
    customerFuture,
  ).wait;
  try {
    await local.reconcileServerItems(sessionId: sessionId, items: items);
  } catch (error, stack) {
    // Önbellek ikincil kopyadır; yazma sorunu, başarıyla alınmış kanonik
    // sunucu detayının kullanıcıya gösterilmesini engellememelidir.
    ref
        .read(appLoggerProvider)
        .warn(error, stackTrace: stack, context: 'SessionDetailItemsCache');
  }
  final serverNow = await repository.serverNow();
  return SessionDetailState(
    session: session,
    customerName: customerName,
    items: items,
    timeEntries: entries,
    serverAnchor: serverNow,
    clock: clock,
    clockAnchor: clock.elapsed,
  );
}

Future<SessionDetailState> _localSessionDetail(
  Ref ref,
  LocalSessionRow row, {
  required MonotonicClock clock,
  required SessionsLocalDataSource local,
}) async {
  final customer = row.customerId == null
      ? null
      : await ref
            .read(customersLocalDataSourceProvider)
            .findCustomer(row.customerId!);
  final (entries, itemsBySession) = await (
    local.timeEntries(row.id),
    local.itemsForSessions([row.id]),
  ).wait;
  return SessionDetailState(
    session: mapLocalSessionToDomain(row),
    customerName: customer?.name,
    items: (itemsBySession[row.id] ?? const [])
        .map(mapLocalSessionItemToDomain)
        .toList(growable: false),
    timeEntries: entries.map(mapLocalTimeEntryToDomain).toList(growable: false),
    serverAnchor: DateTime.now().toUtc(),
    clock: clock,
    clockAnchor: clock.elapsed,
  );
}

/// Açık (aktif/duraklatılmış) seanslar artık Drift stream'inden gelir; böylece
/// internet olmadan başlatılan seanslar da anında görünür ve süre işler.
final openSessionsProvider = StreamProvider.autoDispose<List<Session>>((ref) {
  final businessId = ref.watch(activeBusinessProvider)?.id;
  if (businessId == null) return Stream.value(const <Session>[]);
  return ref
      .watch(sessionsLocalDataSourceProvider)
      .watchActiveSessions(businessId)
      .map((rows) => rows.map(mapLocalSessionToDomain).toList(growable: false));
});
