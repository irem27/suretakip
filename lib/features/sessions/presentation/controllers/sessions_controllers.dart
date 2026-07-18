import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
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
    required this.clientAnchor,
  });

  final Session session;
  final String? customerName;
  final List<SessionItem> items;
  final List<SessionTimeEntry> timeEntries;

  /// Fetch anındaki sunucu zamanı (çapa). Açık aktif aralığın süresi buradan
  /// türetilir; cihaz saati kaymış olsa bile canlı sayaç doğru kalır.
  final DateTime serverAnchor;

  /// Fetch anındaki cihaz zamanı; canlı tik ile geçen süreyi ölçmek için.
  final DateTime clientAnchor;

  /// Cihaz saatinden bağımsız "şu anki sunucu zamanı":
  /// serverAnchor + (cihazNow − clientAnchor).
  DateTime effectiveServerNow(DateTime clientNow) =>
      serverAnchor.add(clientNow.difference(clientAnchor));

  /// Açık (aktif/duraklatılmış) seansların CANLI önizlemesi. Kalıcı/final
  /// hesap daima server-side complete_session RPC'sindedir; tamamlanmış
  /// seanslar bu önizlemeyi değil DB'deki kesin tutarları gösterir.
  SessionPriceQuote quoteAt(DateTime clientNow) {
    final activeDuration = calculateSessionActiveDuration(
      entries: timeEntries,
      serverNow: effectiveServerNow(clientNow),
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

class SessionsListController extends AsyncNotifier<List<Session>> {
  @override
  Future<List<Session>> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading<List<Session>>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  Future<List<Session>> _load() async {
    final business = ref.watch(activeBusinessProvider);
    if (business == null) return const [];
    return ref
        .watch(sessionsRepositoryProvider)
        .getSessions(businessId: business.id);
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
      ref.invalidate(sessionsListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
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
    if (success) ref.invalidate(productsListControllerProvider);
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
      ref.invalidate(dashboardControllerProvider);
      ref.invalidate(historyControllerProvider);
      ref.invalidate(reportsControllerProvider);
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
      ref.invalidate(dashboardControllerProvider);
      ref.invalidate(productsListControllerProvider);
      ref.invalidate(historyControllerProvider);
      ref.invalidate(reportsControllerProvider);
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
      ref.invalidate(sessionsListControllerProvider);
    });
    return !state.hasError;
  }
}

final sessionsListControllerProvider =
    AsyncNotifierProvider<SessionsListController, List<Session>>(
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

final sessionDetailProvider = FutureProvider.autoDispose
    .family<SessionDetailState, String>((ref, sessionId) async {
      final repository = ref.watch(sessionsRepositoryProvider);
      final session = await repository.getSession(sessionId);
      final customerFuture = session.customerId == null
          ? Future<String?>.value(null)
          : ref
                .watch(customersRepositoryProvider)
                .getCustomer(session.customerId!)
                .then<String?>((customer) => customer.name);
      final (items, entries, customerName, serverNow) = await (
        repository.getSessionItems(sessionId),
        repository.getSessionTimeEntries(sessionId),
        customerFuture,
        repository.serverNow(),
      ).wait;
      return SessionDetailState(
        session: session,
        customerName: customerName,
        items: items,
        timeEntries: entries,
        serverAnchor: serverNow,
        clientAnchor: DateTime.now().toUtc(),
      );
    });

final openSessionsProvider = Provider<AsyncValue<List<Session>>>((ref) {
  return ref
      .watch(sessionsListControllerProvider)
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
