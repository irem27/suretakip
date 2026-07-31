import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/providers/business_selection_controller.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/domain/domain_enums.dart';
import 'package:suretakip/core/errors/domain_exception.dart';
import 'package:suretakip/core/presentation/widgets/app_bottom_nav_bar.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/core/utils/business_date_ranges.dart';
import 'package:suretakip/features/auth/presentation/controllers/auth_controllers.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/utils/session_presentation_utils.dart';
import 'package:suretakip/features/sessions/presentation/widgets/active_sessions_sheet.dart';
import 'package:suretakip/features/sessions/presentation/widgets/open_session_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signOutState = ref.watch(signOutControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final scope = ref.watch(activeBusinessScopeProvider);
    final dashboardProvider = dashboardControllerProvider(scope);
    final sessionsProvider = sessionsListControllerProvider(scope);
    final openSessions = ref.watch(openSessionsProvider);
    // Müşteri adları tek listeden eşlenir; kart başına sorgu (N+1) yapılmaz.
    final customers =
        ref
            .watch(customersListControllerProvider(scope))
            .valueOrNull
            ?.customers ??
        const <Customer>[];
    final customerNamesById = {
      for (final customer in customers) customer.id: customer.name,
    };
    final dashboardMetrics = ref.watch(dashboardProvider);
    // Metrik henüz gelmediyse açık seans listesine düşülür; böylece kart
    // veri gelene kadar da doğru davranır.
    final activeSessionCount =
        dashboardMetrics.valueOrNull?.activeSessionCount ??
        openSessions.valueOrNull?.length ??
        0;
    final allSessions = ref.watch(sessionsProvider);
    final businesses =
        ref
            .watch(userBusinessesProvider)
            .valueOrNull
            ?.where((business) => business.isActive)
            .toList(growable: false) ??
        const [];
    final activeBusiness = ref.watch(activeBusinessProvider);
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
      bottomNavigationBar: const AppBottomNavBar(current: AppSection.dashboard),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (businesses.length > 1 && activeBusiness != null) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('business-switcher-${activeBusiness.id}'),
                initialValue: activeBusiness.id,
                decoration: const InputDecoration(
                  labelText: 'Aktif işletme',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                items: [
                  for (final business in businesses)
                    DropdownMenuItem(
                      value: business.id,
                      child: Text(business.name),
                    ),
                ],
                onChanged: (businessId) {
                  if (businessId == null) return;
                  ref
                      .read(businessSelectionControllerProvider.notifier)
                      .selectBusiness(businessId);
                },
              ),
            ],
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
                        // Sayı sıfırken açılacak bir döküm yok; kart o durumda
                        // salt okunur kalır ve yanıltıcı bir aksiyon sunmaz.
                        onTap: activeSessionCount == 0
                            ? null
                            : () => showActiveSessionsSheet(context),
                        hint: 'Detayları gör',
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
                  onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
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
                  onPressed: () =>
                      ref.read(sessionsProvider.notifier).refresh(),
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
                  onRetry: () => ref.read(sessionsProvider.notifier).refresh(),
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
                          OpenSessionCard(
                            session: session,
                            customerName: customerNamesById[session.customerId],
                            businessTimezone: businessTimezone,
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
                  onRetry: () => ref.read(sessionsProvider.notifier).refresh(),
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
    this.onTap,
    this.hint,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  /// Dokunulabilir metrikler için; null ise kart salt okunurdur.
  final VoidCallback? onTap;

  /// Dokunmanın ne yapacağını anlatan kısa ipucu (yalnızca [onTap] varken).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (onTap != null && hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: onTap == null ? '$title: $value' : '$title: $value. ${hint ?? ''}',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
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
