import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/presentation/widgets/app_back_button.dart';
import 'package:suretakip/core/presentation/widgets/app_bottom_nav_bar.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/features/customers/domain/entities/customer.dart';
import 'package:suretakip/features/customers/presentation/controllers/customers_controllers.dart';
import 'package:suretakip/features/sessions/presentation/controllers/sessions_controllers.dart';
import 'package:suretakip/features/sessions/presentation/widgets/open_session_card.dart';

/// İşlemler sekmesi: üstte yeni işlem başlatma, altında devam eden işlemler.
class SessionsOverviewPage extends ConsumerWidget {
  const SessionsOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(activeBusinessScopeProvider);
    final sessionsProvider = sessionsListControllerProvider(scope);
    final openSessions = ref.watch(openSessionsProvider);
    // Ad eşlemesi tek listeden kurulur; kart başına sorgu (N+1) yapılmaz.
    final customers =
        ref
            .watch(customersListControllerProvider(scope))
            .valueOrNull
            ?.customers ??
        const <Customer>[];
    final customerNamesById = {
      for (final customer in customers) customer.id: customer.name,
    };
    final businessTimezone =
        ref.watch(activeBusinessProvider)?.timezone ??
        AppConstants.defaultTimezone;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(
          fallbackRouteName: AppRouteNames.dashboard,
        ),
        title: const Text('İşlemler'),
        actions: [
          IconButton(
            onPressed: () => ref.read(sessionsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Aktif işlemleri yenile',
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(current: AppSection.sessions),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: () => context.pushNamed(AppRouteNames.sessionStart),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yeni İşlem Başlat'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Devam Eden İşlemler',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.timer_off_outlined, size: 40),
                            SizedBox(height: 12),
                            Text(
                              'Şu anda devam eden işlem yok.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
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
          ],
        ),
      ),
    );
  }
}
