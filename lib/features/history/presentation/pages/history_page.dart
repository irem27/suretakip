import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:suretakip/app/providers/app_providers.dart';
import 'package:suretakip/app/router/app_routes.dart';
import 'package:suretakip/core/constants/app_constants.dart';
import 'package:suretakip/core/presentation/widgets/app_back_button.dart';
import 'package:suretakip/core/presentation/widgets/app_error_state.dart';
import 'package:suretakip/core/utils/business_date_ranges.dart';
import 'package:suretakip/features/history/presentation/controllers/history_controller.dart';
import 'package:suretakip/features/payments/domain/entities/payment.dart';
import 'package:suretakip/features/payments/presentation/widgets/payment_status_badge.dart';
import 'package:suretakip/features/sessions/domain/entities/session.dart';
import 'package:suretakip/features/sessions/presentation/utils/session_presentation_utils.dart';
import 'package:suretakip/features/sessions/presentation/widgets/session_status_chip.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(activeBusinessScopeProvider);
    final historyProvider = historyControllerProvider(scope);
    final history = ref.watch(historyProvider);
    final timezone =
        ref.watch(activeBusinessProvider)?.timezone ??
        AppConstants.defaultTimezone;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(
          fallbackRouteName: AppRouteNames.dashboard,
        ),
        title: const Text('İşlem Geçmişi'),
        actions: [
          IconButton(
            onPressed: () => ref.read(historyProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Geçmişi yenile',
          ),
        ],
      ),
      body: SafeArea(
        child: history.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => AppErrorState(
            error: error,
            fallbackMessage: 'İşlem geçmişi yüklenemedi.',
            onRetry: () => ref.read(historyProvider.notifier).refresh(),
          ),
          data: (data) => RefreshIndicator.adaptive(
            onRefresh: () => ref.read(historyProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HistoryFilters(data: data),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'İşlemler',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('${data.sessions.length} kayıt'),
                  ],
                ),
                const SizedBox(height: 8),
                // Sessiz kesme olmasın: limit dolduysa kullanıcı eksik veri
                // gördüğünü bilsin ve aralığı daraltsın.
                if (data.sessions.length >= AppConstants.historyQueryLimit) ...[
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'En yeni ${AppConstants.historyQueryLimit} kayıt '
                              'gösteriliyor. Tümünü görmek için tarih aralığını '
                              'daraltın veya filtre ekleyin.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (data.sessions.isEmpty)
                  const _EmptyHistory()
                else
                  for (final session in data.sessions)
                    _HistorySessionCard(
                      session: session,
                      customerName: data.customerName(session.customerId),
                      timezone: timezone,
                      paymentStatus: data.paymentStatuses[session.id],
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryFilters extends ConsumerWidget {
  const _HistoryFilters({required this.data});

  final HistoryState data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(activeBusinessScopeProvider);
    final controller = ref.read(historyControllerProvider(scope).notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtreler',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _selectDates(context, ref),
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                '${DateFormat('dd.MM.yyyy').format(data.firstDate)} – '
                '${DateFormat('dd.MM.yyyy').format(data.lastDate)}',
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 680
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String?>(
                        // Uzun etiketler dar ekranda / büyük yazıda satırı
                        // taşırmasın: doğal genişlik yerine kutuya sığdır.
                        isExpanded: true,
                        initialValue: data.customerId,
                        decoration: const InputDecoration(
                          labelText: 'Müşteri',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        items: [
                          const DropdownMenuItem(child: Text('Tüm müşteriler')),
                          for (final customer in data.customers)
                            DropdownMenuItem(
                              value: customer.id,
                              child: Text(customer.name),
                            ),
                        ],
                        onChanged: controller.setCustomer,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
                        initialValue: data.serviceId,
                        decoration: const InputDecoration(
                          labelText: 'Hizmet',
                          prefixIcon: Icon(Icons.design_services_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(child: Text('Tüm hizmetler')),
                          for (final service in data.services)
                            DropdownMenuItem(
                              value: service.id,
                              child: Text(service.name),
                            ),
                        ],
                        onChanged: controller.setService,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<HistoryStatusFilter>(
                        isExpanded: true,
                        initialValue: data.status,
                        decoration: const InputDecoration(
                          labelText: 'Durum',
                          prefixIcon: Icon(Icons.filter_alt_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: HistoryStatusFilter.all,
                            child: Text('Tamamlanan ve iptal edilen'),
                          ),
                          DropdownMenuItem(
                            value: HistoryStatusFilter.completed,
                            child: Text('Tamamlanan'),
                          ),
                          DropdownMenuItem(
                            value: HistoryStatusFilter.cancelled,
                            child: Text('İptal edilen'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) controller.setStatus(value);
                        },
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

  Future<void> _selectDates(BuildContext context, WidgetRef ref) async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(AppConstants.historyEarliestYear),
      lastDate: data.serverLocalDate,
      initialDateRange: DateTimeRange(
        start: data.firstDate,
        end: data.lastDate,
      ),
      helpText: 'İşlem tarih aralığı',
      saveText: 'Uygula',
    );
    if (selected == null) return;
    final scope = ref.read(activeBusinessScopeProvider);
    await ref
        .read(historyControllerProvider(scope).notifier)
        .setDates(selected.start, selected.end);
  }
}

class _HistorySessionCard extends StatelessWidget {
  const _HistorySessionCard({
    required this.session,
    required this.customerName,
    required this.timezone,
    required this.paymentStatus,
  });

  final Session session;
  final String customerName;
  final String timezone;
  final SessionPaymentStatus? paymentStatus;

  @override
  Widget build(BuildContext context) {
    final instant = session.endedAt ?? session.startedAt;
    final local = BusinessDateRanges.localDateTime(
      instant: instant,
      timezone: timezone,
    );
    final date = DateFormat('dd.MM.yyyy HH:mm').format(local);
    final amount = session.grandTotalMinor == null
        ? null
        : formatSessionMoney(
            session.grandTotalMinor!,
            session.currencyCodeSnapshot,
          );
    return Semantics(
      button: true,
      label:
          '$customerName, ${session.serviceNameSnapshot}, $date${amount == null ? '' : ', $amount'}',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.pushNamed(
            AppRouteNames.sessionDetail,
            pathParameters: {'sessionId': session.id},
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('${session.serviceNameSnapshot}\n$date'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SessionStatusChip(status: session.status),
                    if (paymentStatus != null)
                      PaymentStatusBadge(status: paymentStatus!),
                    if (amount != null)
                      Text(
                        amount,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 48),
          SizedBox(height: 12),
          Text(
            'Seçili filtrelerde henüz işlem yok. Tarih aralığını veya filtreleri değiştirerek tekrar arayın.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
