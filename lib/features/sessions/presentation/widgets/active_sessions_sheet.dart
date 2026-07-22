import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/sessions/presentation/controllers/active_sessions_controller.dart';
import 'package:suretakip/features/sessions/presentation/utils/session_presentation_utils.dart';
import 'package:suretakip/features/sessions/presentation/widgets/open_session_card.dart';
import 'package:suretakip/features/sessions/presentation/widgets/session_status_chip.dart';

/// Sayaç, kullanıcı bunu okuyacak kadar sık ama pil yakmayacak kadar seyrek
/// tazelenir.
const _tickInterval = Duration(seconds: 1);

/// "Aktif İşlem" metriğine dokununca açılan canlı döküm.
///
/// Sayı tek başına bir şey söylemez; burada kimin işlemi olduğu, ne kadar
/// süredir devam ettiği ve o ana kadar ne tuttuğu görünür.
Future<void> showActiveSessionsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ActiveSessionsSheet(),
    );

class ActiveSessionsSheet extends ConsumerStatefulWidget {
  const ActiveSessionsSheet({super.key});

  @override
  ConsumerState<ActiveSessionsSheet> createState() =>
      _ActiveSessionsSheetState();
}

class _ActiveSessionsSheetState extends ConsumerState<ActiveSessionsSheet> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Süre ve tutar sunucu çapasından türetilir; timer yalnızca yeniden
    // çizimi tetikler, hesabın kaynağı değildir.
    _ticker = Timer.periodic(_tickInterval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(activeSessionSummariesProvider);
    final businessTimezone =
        ref.watch(activeBusinessProvider)?.timezone ??
        AppConstants.defaultTimezone;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktif İşlemler',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Süre ve tutarlar canlı ilerler. Kesin tutar işlem tamamlanınca oluşur.',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: summaries.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (error, _) => AppErrorState(
                  error: error,
                  fallbackMessage: 'Aktif işlemler yüklenemedi.',
                  onRetry: () => ref.invalidate(activeSessionSummariesProvider),
                  padding: const EdgeInsets.all(20),
                  iconSize: 40,
                ),
                data: (sessions) => sessions.isEmpty
                    ? const _EmptyActiveSessions()
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: sessions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _ActiveSessionTile(
                          summary: sessions[index],
                          businessTimezone: businessTimezone,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyActiveSessions extends StatelessWidget {
  const _EmptyActiveSessions();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_off_outlined, size: 44),
        const SizedBox(height: 12),
        const Text(
          'Şu anda devam eden işlem yok.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            context.pushNamed(AppRouteNames.sessionStart);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Yeni İşlem Başlat'),
        ),
      ],
    ),
  );
}

class _ActiveSessionTile extends StatelessWidget {
  const _ActiveSessionTile({
    required this.summary,
    required this.businessTimezone,
  });

  final ActiveSessionSummary summary;
  final String businessTimezone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = summary.session;
    final quote = summary.quote;
    final customerName = summary.customerName ?? 'Misafir müşteri';
    final duration = formatSessionDuration(summary.activeDuration);
    final total = formatSessionMoney(
      quote.grandTotal.minorUnits,
      quote.grandTotal.currencyCode,
    );

    return Semantics(
      button: true,
      label:
          '$customerName, ${session.serviceNameSnapshot}. '
          'Süre $duration. Tutar $total. '
          'Durum ${sessionStatusLabel(session.status)}.',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            context.pushNamed(
              AppRouteNames.sessionDetail,
              pathParameters: {'sessionId': session.id},
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customerName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SessionStatusChip(status: session.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  session.serviceNameSnapshot,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Dar ekranda ve büyük yazı ölçeğinde taşmaması için Wrap.
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    _SessionFact(
                      icon: Icons.timer_outlined,
                      label: 'Süre',
                      value: duration,
                      emphasized: true,
                    ),
                    _SessionFact(
                      icon: Icons.payments_outlined,
                      label: 'Tutar',
                      value: total,
                      emphasized: true,
                    ),
                    _SessionFact(
                      icon: Icons.play_arrow_rounded,
                      label: 'Başlangıç',
                      value: formatBusinessDateTime(
                        session.startedAt,
                        businessTimezone,
                      ),
                    ),
                  ],
                ),
                if (summary.items.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${summary.items.length} ürün eklendi · '
                    '${formatSessionMoney(quote.productsTotal.minorUnits, quote.productsTotal.currencyCode)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionFact extends StatelessWidget {
  const _SessionFact({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: emphasized
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )
              : theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
