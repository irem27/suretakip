import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/utils/monotonic_clock.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/domain/services/session_price_calculator.dart';
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
  Future<List<Session>> build(BusinessScope scope) => _load(scope.businessId);

  Future<void> refresh() async {
    state = const AsyncLoading<List<Session>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _load(arg.businessId));
  }

  Future<List<Session>> _load(String? businessId) async {
    if (businessId == null) return const [];
    return ref
        .watch(sessionsRepositoryProvider)
        .getSessions(businessId: businessId);
  }
}

class StartSessionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> start({
    required String serviceId,
    String? customerId,
    String? notes,
  }) async {
    final business = ref.read(activeBusinessProvider);
    if (business == null) return null;
    String? sessionId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      sessionId = await ref
          .read(sessionsRepositoryProvider)
          .startSession(
            businessId: business.id,
            serviceId: serviceId,
            customerId: customerId,
            notes: notes,
          );
      final scope = ref.read(activeBusinessScopeProvider);
      ref.invalidate(sessionsListControllerProvider(scope));
      ref.invalidate(dashboardControllerProvider(scope));
    });
    return state.hasError ? null : sessionId;
  }
}

class SessionActionsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> pause(String sessionId) => _run(
    sessionId,
    () =>
        ref.read(sessionsRepositoryProvider).pauseSession(sessionId: sessionId),
  );

  Future<bool> resume(String sessionId) => _run(
    sessionId,
    () => ref
        .read(sessionsRepositoryProvider)
        .resumeSession(sessionId: sessionId),
  );

  Future<bool> addProduct({
    required String sessionId,
    required String productId,
    required int quantity,
    int discountMinor = 0,
    int taxMinor = 0,
  }) async {
    final success = await _run(
      sessionId,
      () => ref
          .read(sessionsRepositoryProvider)
          .addProductToSession(
            sessionId: sessionId,
            productId: productId,
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
    final success = await _run(
      sessionId,
      () => ref
          .read(sessionsRepositoryProvider)
          .completeSession(
            sessionId: sessionId,
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
    final success = await _run(
      sessionId,
      () => ref
          .read(sessionsRepositoryProvider)
          .cancelSession(sessionId: sessionId),
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

  Future<bool> _run(
    String sessionId,
    Future<String> Function() operation,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await operation();
      ref.invalidate(sessionDetailProvider(sessionId));
      ref.invalidate(
        sessionsListControllerProvider(ref.read(activeBusinessScopeProvider)),
      );
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
      final repository = ref.watch(sessionsRepositoryProvider);
      final clock = ref.watch(monotonicClockFactoryProvider)();
      ref.onDispose(clock.stop);
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
    });

final openSessionsProvider = Provider<AsyncValue<List<Session>>>((ref) {
  final scope = ref.watch(activeBusinessScopeProvider);
  return ref
      .watch(sessionsListControllerProvider(scope))
      .whenData(
        (sessions) => sessions
            .where(
              (session) =>
                  session.status == SessionStatus.active ||
                  session.status == SessionStatus.paused,
            )
            .toList(growable: false),
      );
});
