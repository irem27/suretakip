import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/sync_providers.dart';
import 'package:suretakip/core/utils/monotonic_clock.dart';
import 'package:suretakip/features/sessions/data/local/local_session_mappers.dart';
import 'package:suretakip/core/value_objects/money.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/domain/entities/session_item.dart';
import 'package:suretakip/features/sessions/domain/entities/session_time_entry.dart';
import 'package:suretakip/features/sessions/domain/services/session_price_calculator.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';

/// Açık bir seansın canlı özeti: kim, hangi hizmet, ne kadar süredir, ne tutar.
///
/// Süre ve tutar SABİT DEĞİLDİR — [SessionDetailState] ile aynı mantıkla,
/// sunucu zamanı çapasından türetilir. Bu yüzden [activeDuration] bir alan
/// değil, her okumada yeniden hesaplanan bir getter'dır.
final class ActiveSessionSummary {
  const ActiveSessionSummary({
    required this.session,
    required this.customerName,
    required this.timeEntries,
    required this.items,
    required DateTime serverAnchor,
    required MonotonicClock clock,
    required Duration clockAnchor,
  }) : _serverAnchor = serverAnchor,
       _clock = clock,
       _clockAnchor = clockAnchor;

  final Session session;

  /// Kayıtlı müşteri yoksa null; arayüzde misafir olarak gösterilir.
  final String? customerName;

  final List<SessionTimeEntry> timeEntries;
  final List<SessionItem> items;

  final DateTime _serverAnchor;
  final MonotonicClock _clock;
  final Duration _clockAnchor;

  /// Cihaz duvar saatinden bağımsız "şu anki sunucu zamanı".
  DateTime get effectiveServerNow {
    final elapsedSinceAnchor = _clock.elapsed - _clockAnchor;
    return _serverAnchor.add(
      elapsedSinceAnchor.isNegative ? Duration.zero : elapsedSinceAnchor,
    );
  }

  /// Duraklatılan aralıklar düşülmüş, fiilen çalışılan süre.
  Duration get activeDuration => calculateSessionActiveDuration(
    entries: timeEntries,
    serverNow: effectiveServerNow,
  );

  /// Anlık tutar önizlemesi. Kesin tutar daima server-side tamamlama
  /// RPC'sinde hesaplanır; bu yalnızca ekranda gösterilen tahmindir.
  SessionPriceQuote get quote => const SessionPriceCalculator().calculate(
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

/// Açık işlemlerin canlı özetleri — offline-first (Faz C).
///
/// Seanslar ve zaman kayıtları Drift'ten okunur; "şimdi" çapası olarak CİHAZ
/// saati kullanılır (offline'da `server_now()` yoktur). Süre monotonic saat +
/// kayıtlı damgalardan türetildiği için uygulama kapansa da donmaz.
final activeSessionSummariesProvider =
    FutureProvider.autoDispose<List<ActiveSessionSummary>>((ref) async {
      final openSessions = ref.watch(openSessionsProvider).valueOrNull;
      if (openSessions == null || openSessions.isEmpty) {
        return const <ActiveSessionSummary>[];
      }

      final local = ref.watch(sessionsLocalDataSourceProvider);
      final clock = ref.watch(monotonicClockFactoryProvider)();
      ref.onDispose(clock.stop);

      final scope = ref.watch(activeBusinessScopeProvider);
      final customers =
          ref
              .watch(customersListControllerProvider(scope))
              .valueOrNull
              ?.customers ??
          const <Customer>[];
      final customerNamesById = {
        for (final customer in customers) customer.id: customer.name,
      };

      final entriesBySession = <String, List<SessionTimeEntry>>{};
      for (final session in openSessions) {
        final rows = await local.timeEntries(session.id);
        entriesBySession[session.id] = rows
            .map(mapLocalTimeEntryToDomain)
            .toList(growable: false);
      }

      // Çapa, ilişkili veriler geldikten SONRA alınır.
      final deviceAnchor = DateTime.now().toUtc();
      final clockAnchor = clock.elapsed;

      return [
        for (final session in openSessions)
          ActiveSessionSummary(
            session: session,
            customerName: session.customerId == null
                ? null
                : customerNamesById[session.customerId],
            timeEntries:
                entriesBySession[session.id] ?? const <SessionTimeEntry>[],
            items: const <SessionItem>[],
            serverAnchor: deviceAnchor,
            clock: clock,
            clockAnchor: clockAnchor,
          ),
      ];
    });
