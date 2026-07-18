import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/core/utils/business_date_ranges.dart';
import 'package:suretakip/features/auth/presentation/controllers/auth_controllers.dart';
import 'package:suretakip/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/utils/session_presentation_utils.dart';
import 'package:suretakip/features/sessions/presentation/widgets/session_status_chip.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final signOutState = ref.watch(signOutControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final openSessions = ref.watch(openSessionsProvider);
    final dashboardMetrics = ref.watch(dashboardControllerProvider);
    final allSessions = ref.watch(sessionsListControllerProvider);
    final businessTimezone =
        ref.watch(activeBusinessProvider)?.timezone ??
        AppConstants.defaultTimezone;
    ref.listen(signOutControllerProvider, (_, next) {
      if (!next.hasError) return;
      final error = next.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is DomainException
                ? error.message
                : 'Çıkış yapılamadı. Lütfen tekrar deneyin.',
          ),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        actions: [
          IconButton(
            onPressed: signOutState.isLoading
                ? null
                : () => ref.read(signOutControllerProvider.notifier).signOut(),
            icon: signOutState.isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            tooltip: 'Çıkış yap',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Hoş geldin${currentUser?.email == null ? '' : ', ${currentUser!.email}'}',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Aktif işlemleri, gün sonu gelirini ve hızlı aksiyonları buradan yöneteceksin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700
                    ? 3
                    : constraints.maxWidth >= 420
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: width,
                      child: _MetricCard(
                        title: 'Aktif İşlem',
                        value: dashboardMetrics.maybeWhen(
                          data: (metrics) => metrics == null
                              ? '—'
                              : '${metrics.activeSessionCount}',
                          orElse: () => '—',
                        ),
                        icon: Icons.timelapse_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _MetricCard(
                        title: 'Bugünkü Gelir',
                        value: dashboardMetrics.maybeWhen(
                          data: (metrics) => metrics == null
                              ? '—'
                              : formatSessionMoney(
                                  metrics.todayRevenue.minorUnits,
                                  metrics.todayRevenue.currencyCode,
                                ),
                          orElse: () => '—',
                        ),
                        icon: Icons.payments_rounded,
                        color: colorScheme.secondary,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _MetricCard(
                        title: 'Tamamlanan',
                        value: dashboardMetrics.maybeWhen(
                          data: (metrics) => metrics == null
                              ? '—'
                              : '${metrics.todayCompletedCount}',
                          orElse: () => '—',
                        ),
                        icon: Icons.check_circle_rounded,
                        color: colorScheme.tertiary,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (dashboardMetrics.isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                semanticsLabel: 'Ana sayfa metrikleri yükleniyor',
              ),
            ],
            if (dashboardMetrics.hasError) ...[
              const SizedBox(height: 12),
              Card(
                child: AppErrorState(
                  error: dashboardMetrics.error!,
                  fallbackMessage: 'Ana sayfa metrikleri yüklenemedi.',
                  onRetry: () =>
                      ref.read(dashboardControllerProvider.notifier).refresh(),
                  padding: const EdgeInsets.all(20),
                  iconSize: 40,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.pushNamed(AppRouteNames.sessionStart),
              icon: const Icon(Icons.add_circle_outline),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Yeni İşlem Başlat'),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Aktif İşlemler',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => ref
                      .read(sessionsListControllerProvider.notifier)
                      .refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Aktif işlemleri yenile',
                ),
              ],
            ),
            const SizedBox(height: 12),
            openSessions.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              ),
              error: (error, _) => Card(
                child: AppErrorState(
                  error: error,
                  fallbackMessage: 'Aktif işlemler yüklenemedi.',
                  onRetry: () => ref
                      .read(sessionsListControllerProvider.notifier)
                      .refresh(),
                  padding: const EdgeInsets.all(20),
                  iconSize: 40,
                ),
              ),
              data: (sessions) => sessions.isEmpty
                  ? _DashboardStateCard(
                      icon: Icons.timer_off_outlined,
                      message:
                          'Şu anda açık işlem yok. İlk işleminizi başlatabilirsiniz.',
                      actionLabel: 'Yeni İşlem Başlat',
                      onAction: () =>
                          context.pushNamed(AppRouteNames.sessionStart),
                    )
                  : Column(
                      children: [
                        for (final session in sessions)
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              minTileHeight: 76,
                              leading: const Icon(Icons.timer_outlined),
                              title: Text(session.serviceNameSnapshot),
                              subtitle: Text(
                                'Başlangıç: ${_formatBusinessDate(session.startedAt, businessTimezone)}',
                              ),
                              trailing: SessionStatusChip(
                                status: session.status,
                              ),
                              onTap: () => context.pushNamed(
                                AppRouteNames.sessionDetail,
                                pathParameters: {'sessionId': session.id},
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              'Geçmiş ve Raporlar',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 620
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _NavigationCard(
                        icon: Icons.history_rounded,
                        title: 'İşlem Geçmişi',
                        subtitle:
                            'Tamamlanan ve iptal edilen işlemleri filtrele.',
                        onTap: () => context.pushNamed(AppRouteNames.history),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _NavigationCard(
                        icon: Icons.bar_chart_rounded,
                        title: 'Raporlar',
                        subtitle: 'Gelir dağılımını ve öne çıkanları incele.',
                        onTap: () => context.pushNamed(AppRouteNames.reports),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Tanımlar',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                minTileHeight: 72,
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.design_services_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                title: const Text('Tanımlar'),
                subtitle: const Text(
                  'Hizmet, ürün ve müşteri kayıtlarını yönetin.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.pushNamed(AppRouteNames.definitions),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Son Tamamlanan İşlemler',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            allSessions.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              ),
              error: (error, _) => Card(
                child: AppErrorState(
                  error: error,
                  fallbackMessage: 'Son tamamlanan işlemler yüklenemedi.',
                  onRetry: () => ref
                      .read(sessionsListControllerProvider.notifier)
                      .refresh(),
                  padding: const EdgeInsets.all(20),
                  iconSize: 40,
                ),
              ),
              data: (sessions) {
                final completed = sessions
                    .where(
                      (session) => session.status == SessionStatus.completed,
                    )
                    .take(3)
                    .toList(growable: false);
                if (completed.isEmpty) {
                  return _DashboardStateCard(
                    icon: Icons.history_toggle_off_rounded,
                    message:
                        'Henüz tamamlanan işlem yok. Tamamladığınız işlemler burada görünecek.',
                    actionLabel: 'Yeni İşlem Başlat',
                    onAction: () =>
                        context.pushNamed(AppRouteNames.sessionStart),
                  );
                }
                return Column(
                  children: [
                    for (final session in completed)
                      Card(
                        child: ListTile(
                          title: Text(session.serviceNameSnapshot),
                          subtitle: Text(
                            _formatBusinessDate(
                              session.endedAt ?? session.startedAt,
                              businessTimezone,
                            ),
                          ),
                          trailing: Text(
                            formatSessionMoney(
                              session.grandTotalMinor ?? 0,
                              session.currencyCodeSnapshot,
                            ),
                          ),
                          onTap: () => context.pushNamed(
                            AppRouteNames.sessionDetail,
                            pathParameters: {'sessionId': session.id},
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBusinessDate(DateTime instant, String timezone) {
  final date = BusinessDateRanges.localDateTime(
    instant: instant,
    timezone: timezone,
  );
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day.$month.${date.year} $hour:$minute';
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title. $subtitle',
    excludeSemantics: true,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: 84,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title: $value',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardStateCard extends StatelessWidget {
  const _DashboardStateCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
